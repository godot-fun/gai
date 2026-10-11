class_name AgentCompactionManager
extends Object

## Manually summarizes model history while keeping the visible transcript intact.

const SUMMARY_PREFIX := "# Compacted conversation context"
const ERROR_RUNNING := "running"
const ERROR_EMPTY := "empty"
const ERROR_REQUEST := "request"
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
	var request_messages: Array[ChatMessage] = []
	request_messages.assign(session.messages)
	request_messages.append(ChatMessage.user(COMPACTION_PROMPT))
	var client := ApiSetting.get_client()
	client.cancel_scope = CancelScope.new()
	var summary := await client.async_chat_messages(request_messages, ApiSetting.get_proxy_address())

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
	pass


static func has_compactable_history(session: AgentSession) -> bool:
	for entry: ChatEntry in session.chat_entries:
		if not ChatEntry.is_context_kind(entry.kind) and entry.kind != ChatEntry.KIND_COMPACTION:
			return true
	return false


static func collect_context_messages(messages: Array[ChatMessage]) -> Array[ChatMessage]:
	var context: Array[ChatMessage] = []
	for message: ChatMessage in messages:
		if message.role != ChatMessage.ROLE_SYSTEM:
			continue
		if message.content.begins_with(SUMMARY_PREFIX):
			continue
		context.append(message)
	return context


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
	compacting_sessions.erase(session_id)
	AgentEvents.events.compaction_end.emit(session_id, success, error_code)
	RuntimeManager.try_run_next_message.call_deferred(session_id)
	pass
