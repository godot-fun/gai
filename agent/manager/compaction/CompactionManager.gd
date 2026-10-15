class_name CompactionManager
extends Object

## Coordinates manual context compaction for one session.
##
## A compaction has two deliberately isolated model requests:
## 1. [MemoryManager] reviews the original conversation and may update `.memory/` with tools.
## 2. A tool-free request summarizes the same original conversation.
##
## Both requests start from [member AgentSession.messages]. The memory agent's prompt, tool calls,
## tool results, and final confirmation never enter the summary request or persisted chat history.

const SUMMARY_PREFIX := "# Compacted conversation context"
const ERROR_RUNNING := "running"
const ERROR_EMPTY := "empty"
const ERROR_REQUEST := "request"
## Tool-free request whose response becomes the new compacted continuation context.
const COMPACTION_PROMPT := """Create a compact continuation summary of the conversation above.

Preserve every detail needed to continue the work correctly, especially:
- the user's goals, constraints, and explicit preferences;
- decisions already made and their reasons;
- files changed and important implementation details;
- commands and tests run, including failures;
- unfinished work, blockers, and concrete next steps.

Do not address the user. Do not call tools. Return only the continuation summary."""

class CompactionState:
	var summary := StringUtils.EMPTY
	var summary_finished := false
pass


## The value keeps per-session work shared by the concurrently running memory and summary tasks.
static var compacting_sessions: Dictionary[int, CompactionState] = {}


static func is_compacting(session_id: int) -> bool:
	return compacting_sessions.has(session_id)


## Runs memory maintenance and continuation summarization concurrently, then persists the summary.
## The session is reloaded after both network requests because it may be deleted while awaiting.
static func compact_session(session_id: int) -> void:
	if is_compacting(session_id):
		return
	if RuntimeManager.is_running(session_id):
		AgentEvents.events.compaction_end.emit(session_id, false, ERROR_RUNNING)
		return
	var session := AgentSessionStore.load_session(session_id)
	if (session == null
		or not AgentSessionManager.has_chat_history(session_id)
		or not has_compactable_history(session)):
		AgentEvents.events.compaction_end.emit(session_id, false, ERROR_EMPTY)
		return

	var state := CompactionState.new()
	compacting_sessions[session_id] = state
	AgentEvents.events.compaction_start.emit(session_id)
	# Memory tools may edit workspace files. Capture a dedicated baseline so their changes can
	# reuse the normal immutable Git Diff bubble without including an earlier agent run again.
	var checkpoint := await GitManager.async_snapshot(session_id)
	var original_messages: Array[ChatMessage] = []
	original_messages.assign(session.messages)
	var client := ApiSetting.get_client()
	client.cancel_scope = CancelScope.new()

	# Build the summary request again from the original conversation. The memory prompt,
	# its tool calls, and its confirmation must never become part of the compacted context.
	var memory_messages := MemoryManager.collect_memory_messages(original_messages)
	memory_messages.append(ChatMessage.user(COMPACTION_PROMPT))
	var summary_deadline := Time.get_ticks_msec() + OpenAiClient.REQUEST_TIMEOUT_MILLIS + TimeUtils.MILLIS_PER_SECOND

	async_generate_summary(client, memory_messages, state)
	await MemoryManager.update_memory(session_id)

	while not state.summary_finished and Time.get_ticks_msec() < summary_deadline:
		await Engine.get_main_loop().process_frame
	if not state.summary_finished:
		finish(session_id, false, ERROR_REQUEST)
		return
	var summary := state.summary
	if StringUtils.is_blank(summary):
		finish(session_id, false, ERROR_REQUEST)
		return

	# The session may have been removed while the request was in flight.
	session = AgentSessionStore.load_session(session_id)
	if session == null or not AgentSessionManager.has_index(session_id):
		finish(session_id, false, ERROR_REQUEST)
		return
	var compacted_messages := collect_context_messages(session.messages)
	summary = summary.strip_edges()
	compacted_messages.append(ChatMessage.system(SUMMARY_PREFIX + FileUtils.NEWLINE_LF + summary))
	session.messages = compacted_messages
	session.chat_entries = collect_context_entries(session.chat_entries)
	session.chat_entries.append(ChatEntry.new(
		ChatEntry.KIND_COMPACTION,
		ChatEntry.TITLE_COMPACTION,
		summary
	))
	update_estimated_usage(session)
	AgentSessionManager.persist_session(session_id)
	finish(session_id, true, StringUtils.EMPTY)
	await GitDiffManager.async_append_git_diff(session_id, checkpoint)
	pass


## Starts before memory maintenance is awaited and publishes its result through [param state].
static func async_generate_summary(client: OpenAiClient, messages: Array[ChatMessage], state: CompactionState) -> void:
	state.summary = await client.async_chat_messages(messages, ApiSetting.get_proxy_address())
	state.summary_finished = true
	pass


static func has_compactable_history(session: AgentSession) -> bool:
	for entry: ChatEntry in session.chat_entries:
		if not ChatEntry.is_context_kind(entry.kind) and entry.kind != ChatEntry.KIND_COMPACTION:
			return true
	return false


## Keeps system-level context while dropping user, assistant, tool, and previous summary turns.
static func collect_context_messages(messages: Array[ChatMessage]) -> Array[ChatMessage]:
	var context: Array[ChatMessage] = []
	for message: ChatMessage in messages:
		if message.role != ChatMessage.ROLE_SYSTEM:
			continue
		if message.content.begins_with(SUMMARY_PREFIX):
			continue
		context.append(message)
	return context


## Visible transcript counterpart of [method collect_context_messages].
static func collect_context_entries(entries: Array[ChatEntry]) -> Array[ChatEntry]:
	var context: Array[ChatEntry] = []
	for entry: ChatEntry in entries:
		if ChatEntry.is_context_kind(entry.kind):
			context.append(entry)
	return context


static func update_estimated_usage(session: AgentSession) -> void:
	var character_count := 0
	for message: ChatMessage in session.messages:
		character_count += message.content.length()
	# A stable UI estimate until the next API response supplies authoritative usage.
	session.usage.prompt_tokens = maxi(1, int(ceil(float(character_count) / 4.0)))
	session.usage.completion_tokens = 0
	session.usage.total_tokens = session.usage.prompt_tokens
	pass


static func finish(session_id: int, success: bool, error_code: String) -> void:
	# Clearing the guard before emitting lets listeners observe the final idle state. Pending
	# user input is resumed only after every compaction-end listener has had a chance to refresh.
	compacting_sessions.erase(session_id)
	AgentEvents.events.compaction_end.emit(session_id, success, error_code)
	RuntimeManager.try_run_next_message.call_deferred(session_id)
	pass
