class_name AgentCompactionManager
extends Object

## Coordinates manual context compaction for one session.
##
## A compaction has two deliberately isolated model requests:
## 1. [CompactionAgent] reviews the original conversation and may update `.memory/` with tools.
## 2. A tool-free request summarizes the same original conversation.
##
## Both requests start from [member AgentSession.messages]. The memory agent's prompt, tool calls,
## tool results, and final confirmation never enter the summary request or persisted chat history.

const SUMMARY_PREFIX := "# Compacted conversation context"
const ERROR_RUNNING := "running"
const ERROR_EMPTY := "empty"
const ERROR_REQUEST := "request"
## Internal task for durable memory maintenance. Its final text is discarded; only tool side
## effects under `.memory/` are retained.
const MEMORY_PROMPT := """Update the workspace memory when the conversation contains information worth retaining.

- Read `.memory/README.md` first and follow its operating rules.
- Read only the memory files relevant to this conversation.
- Use the available file tools to update the appropriate files under `.memory/`.
- Update existing entries instead of creating duplicates.
- Keep `focus.md` short and current.
- Store durable, reusable information only; do not store a conversation transcript.
- Never store passwords, access tokens, private keys, or other secrets.
- Do not edit files outside `.memory/` during this task.

After all useful memory updates are complete, return a brief confirmation."""

## Tool-free request whose response becomes the new compacted continuation context.
const COMPACTION_PROMPT := """Create a compact continuation summary of the conversation above.

Preserve every detail needed to continue the work correctly, especially:
- the user's goals, constraints, and explicit preferences;
- decisions already made and their reasons;
- files changed and important implementation details;
- commands and tests run, including failures;
- unfinished work, blockers, and concrete next steps.

Do not address the user. Do not call tools. Return only the continuation summary."""

static var compacting_sessions: Dictionary[int, bool] = {}


static func is_compacting(session_id: int) -> bool:
	return compacting_sessions.has(session_id)


static func request_compaction(session_id: int) -> void:
	compact_session(session_id)
	pass


## Runs memory maintenance first, then creates and persists a continuation summary.
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

	compacting_sessions[session_id] = true
	AgentEvents.events.compaction_start.emit(session_id)
	# Memory tools may edit workspace files. Capture a dedicated baseline so their changes can
	# reuse the normal immutable Git Diff bubble without including an earlier agent run again.
	var checkpoint := await GitManager.async_snapshot(session_id)
	var original_messages: Array[ChatMessage] = []
	original_messages.assign(session.messages)
	var client := ApiSetting.get_client()
	client.cancel_scope = CancelScope.new()

	# This copy belongs exclusively to the event-free tool agent. CompactionAgent appends its
	# assistant tool-call messages and tool results to this array while it works.
	var memory_messages: Array[ChatMessage] = []
	memory_messages.assign(original_messages)
	memory_messages.append(ChatMessage.user(MEMORY_PROMPT))
	var memory_completion := await CompactionAgent.run(client, memory_messages)
	if memory_completion.has_error():
		finish(session_id, false, ERROR_REQUEST)
		return
	MemoryPrompt.reload_memory_context()

	# Build the summary request again from the original conversation. The memory prompt,
	# its tool calls, and its confirmation must never become part of the compacted context.
	var compaction_messages: Array[ChatMessage] = []
	compaction_messages.assign(original_messages)
	compaction_messages.append(ChatMessage.user(COMPACTION_PROMPT))
	var summary := await client.async_chat_messages(compaction_messages, ApiSetting.get_proxy_address())
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
	await GitDiff.async_append_git_diff(session_id, checkpoint)
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
