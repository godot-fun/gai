class_name RuntimeManager
extends Object

## Owns transient per-session state. Runtime data must never be persisted with session indexes.

static var runtimes: Dictionary[int, RuntimeState] = {}


# ---------------------------------------------------------------------------
# Event wiring
# ---------------------------------------------------------------------------

static func _static_init() -> void:
	# Pending message queue and agent run lifecycle
	AgentEvents.events.session_queue_changed.connect(on_session_queue_changed)
	AgentEvents.events.agent_end.connect(on_agent_end)
	# Turn streaming and tool entries
	AgentEvents.events.turn_start.connect(on_turn_start)
	AgentEvents.events.message_update.connect(on_message_update)
	AgentEvents.events.tool_execution_start.connect(on_tool_execution_start)
	AgentEvents.events.tool_execution_end.connect(on_tool_execution_end)
	# Session invalidation
	AgentEvents.events.session_removed.connect(on_session_removed)
	AgentEvents.events.chat_entry_delete.connect(on_chat_entry_delete)
	pass


# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

static func get_runtime(session_id: int) -> RuntimeState:
	return runtimes.get(session_id)


static func get_or_create_runtime(session_id: int) -> RuntimeState:
	var runtime := get_runtime(session_id)
	if runtime == null:
		runtime = RuntimeState.new()
		runtimes[session_id] = runtime
	return runtime


static func is_running(session_id: int) -> bool:
	return runtimes.has(session_id)


static func request_stop(session_id: int) -> void:
	var runtime := get_runtime(session_id)
	if runtime == null or runtime.stop_requested:
		return
	runtime.stop_requested = true
	runtime.cancel_scope.cancel()
	pass


static func should_stop(session_id: int) -> bool:
	var runtime := get_runtime(session_id)
	return runtime == null or runtime.stop_requested


static func remove_runtime(session_id: int) -> void:
	runtimes.erase(session_id)
	pass


static func clear() -> void:
	for runtime: RuntimeState in runtimes.values():
		runtime.cancel_scope.cancel()
	runtimes.clear()
	pass


# ---------------------------------------------------------------------------
# Pending message queue
# ---------------------------------------------------------------------------

## Starts the FIFO head when the session is idle. Errors and manual stops leave later items queued.
static func try_run_next_message(session_id: int) -> void:
	if not AgentSessionManager.has_index(session_id) or is_running(session_id) or CompactionManager.is_compacting(session_id):
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null or session.pending_messages.is_empty():
		return
	get_or_create_runtime(session_id)
	AgentEvents.events.session_queue_changed.emit(session_id)
	var queued: String = session.pending_messages[0]
	var checkpoint := await GitCheckpointManager.async_snapshot(session_id)
	session = AgentSessionStore.load_session(session_id)
	if not AgentSessionManager.has_index(session_id) or session == null or session.pending_messages.is_empty():
		remove_runtime(session_id)
		if AgentSessionManager.has_index(session_id):
			AgentEvents.events.session_stop.emit(session_id, "")
		return
	if session.pending_messages[0] != queued:
		remove_runtime(session_id)
		AgentEvents.events.session_stop.emit(session_id, "")
		try_run_next_message.call_deferred(session_id)
		return
	session.pending_messages.pop_front()
	AgentEvents.events.session_queue_changed.emit(session_id)
	ChatInputDependencyGuard.append_python_install_message(session)
	if AgentSessionManager.has_default_title(session_id):
		AgentSessionManager.set_title(session_id, queued)
	session.messages.append(ChatMessage.user(queued))
	var details: Dictionary[String, String] = {}
	if StringUtils.is_not_blank(checkpoint):
		details[ChatEntry.DETAIL_CHECKPOINT] = checkpoint
	AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_USER, ChatEntry.TITLE_USER, queued, details)
	AgentSessionManager.persist_session(session_id)
	await run_agent(session)
	pass


static func on_session_queue_changed(session_id: int) -> void:
	try_run_next_message.call_deferred(session_id)
	pass


# ---------------------------------------------------------------------------
# Agent run lifecycle
# ---------------------------------------------------------------------------

static func run_agent(session: AgentSession) -> void:
	if not AgentSessionManager.has_index(session.id):
		return
	var runtime := get_or_create_runtime(session.id)
	var ai_client := ApiSetting.get_client()
	ai_client.cancel_scope = runtime.cancel_scope
	await AgentLoop.run(ai_client, session)
	pass


## Resumes agent execution after the UI has prepared an idle session's chat history.
static func resume_agent(session_id: int) -> void:
	if not AgentSessionManager.has_index(session_id):
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	await run_agent(session)
	pass


static func on_agent_end(session_id: int, error_message: String) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		remove_runtime(session_id)
		return
	var has_session_index := AgentSessionManager.has_index(session_id)
	# Capture before removing the runtime; a missing runtime is treated as stopped.
	var should_continue_queue := has_session_index and not should_stop(session_id) and StringUtils.is_blank(error_message)
	if StringUtils.is_not_blank(error_message):
		AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_ERROR, ChatEntry.TITLE_ERROR, error_message)
	await GitDiffManager.async_append_git_diff(session_id, get_latest_user_checkpoint(session))
	AgentSessionManager.persist_session(session_id)

	remove_runtime(session_id)
	AgentEvents.events.session_stop.emit(session_id, error_message)
	if should_continue_queue:
		try_run_next_message.call_deferred(session_id)
	pass


## Returns the baseline captured immediately before the latest user turn started.
static func get_latest_user_checkpoint(session: AgentSession) -> String:
	for i in range(session.chat_entries.size() - 1, -1, -1):
		var entry: ChatEntry = session.chat_entries[i]
		if entry.kind == ChatEntry.KIND_USER:
			return entry.details.get(ChatEntry.DETAIL_CHECKPOINT, "")
	return StringUtils.EMPTY


# ---------------------------------------------------------------------------
# Turn streaming
# ---------------------------------------------------------------------------

static func on_turn_start(session_id: int) -> void:
	var runtime := get_runtime(session_id)
	if runtime == null:
		return
	runtime.step_entry = null
	pass


static func on_message_update(session_id: int, chunk: String, stream_kind: String) -> void:
	if not AgentSessionManager.has_index(session_id):
		return
	var runtime := get_runtime(session_id)
	if runtime == null:
		return
	var is_reasoning := stream_kind == OpenAiClient.STREAM_KIND_REASONING
	var entry_kind := ChatEntry.KIND_THINKING if is_reasoning else ChatEntry.KIND_AGENT
	var entry_title := ChatEntry.TITLE_THINKING if is_reasoning else ChatEntry.TITLE_AGENT
	if runtime.step_entry == null or runtime.step_entry.kind != entry_kind:
		runtime.step_entry = AgentSessionManager.add_chat_entry(session_id, entry_kind, entry_title, chunk)
	else:
		runtime.step_entry.body += chunk
	AgentEvents.events.chat_entry_update.emit(session_id, runtime.step_entry, stream_kind)
	pass


# ---------------------------------------------------------------------------
# Tool execution entries
# ---------------------------------------------------------------------------

static func on_tool_execution_start(session_id: int, _tool_call_id: String, tool_name: String, args: Dictionary[String, Variant]) -> void:
	if ToolHelper.is_file_tool(tool_name):
		return
	if ToolHelper.is_web_tool(tool_name):
		AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_WEB_TOOL, tool_name, ToolHelper.get_tool_call_summary(tool_name, args))
		return
	AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_TOOL, tool_name, ToolHelper.get_tool_call_summary(tool_name, args))
	pass


static func on_tool_execution_end(session_id: int, _tool_call_id: String, tool_name: String, agent_tool_result: AgentToolResult) -> void:
	if ToolHelper.is_file_tool(tool_name):
		var path: String = agent_tool_result.details.get(AgentToolResult.DETAIL_FILE_PATH, "")
		AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_FILE_TOOL, tool_name, path, agent_tool_result.details)
		return
	var title: String = agent_tool_result.details.get(AgentToolResult.DETAIL_TITLE, "")
	var body: String = agent_tool_result.details.get(AgentToolResult.DETAIL_BODY, "")
	var kind := ChatEntry.KIND_WEB if ToolHelper.is_web_tool(tool_name) else ChatEntry.KIND_RESULT
	AgentSessionManager.add_chat_entry(session_id, kind, title, body, agent_tool_result.details)
	pass


# ---------------------------------------------------------------------------
# Session invalidation
# ---------------------------------------------------------------------------

static func on_session_removed(session_id: int) -> void:
	request_stop(session_id)
	pass


static func on_chat_entry_delete(session_id: int) -> void:
	request_stop(session_id)
	pass
