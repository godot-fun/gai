class_name RuntimeManager
extends Object

## Owns transient per-session state. Runtime data must never be persisted with session indexes.

static var runtimes: Dictionary[int, RuntimeState] = {}


static func _static_init() -> void:
	AgentEvents.events.session_resume.connect(on_session_resume)
	AgentEvents.events.session_removed.connect(on_session_removed)
	AgentEvents.events.session_queue_changed.connect(on_session_queue_changed)
	AgentEvents.events.chat_entry_delete.connect(on_chat_entry_delete)
	AgentEvents.events.turn_start.connect(on_turn_start)
	pass


static func start(session_id: int) -> RuntimeState:
	var runtime := RuntimeState.new()
	runtimes[session_id] = runtime
	return runtime


static func get_runtime(session_id: int) -> RuntimeState:
	return runtimes.get(session_id)


static func get_or_start(session_id: int) -> RuntimeState:
	var runtime := get_runtime(session_id)
	if runtime == null:
		runtime = start(session_id)
	return runtime


static func is_running(session_id: int) -> bool:
	return runtimes.has(session_id)


## Starts the FIFO head when the session is idle. Errors and manual stops leave later items queued.
static func try_run_next(session_id: int) -> void:
	if not AgentSessionManager.has_index(session_id) or is_running(session_id):
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null or session.pending_messages.is_empty():
		return
	start(session_id)
	AgentEvents.events.session_queue_changed.emit(session_id)
	var queued: String = session.pending_messages[0]
	var checkpoint := await GitManager.async_snapshot(session_id)
	session = AgentSessionStore.load_session(session_id)
	if not AgentSessionManager.has_index(session_id) or session == null or session.pending_messages.is_empty():
		stop(session_id)
		if AgentSessionManager.has_index(session_id):
			AgentEvents.events.session_stop.emit(session_id)
		return
	if session.pending_messages[0] != queued:
		stop(session_id)
		AgentEvents.events.session_stop.emit(session_id)
		try_run_next.call_deferred(session_id)
		return
	session.pending_messages.pop_front()
	AgentEvents.events.session_queue_changed.emit(session_id)
	AgentChatInputDependencyGuard.append_python_install_message(session)
	if AgentSessionManager.get_title(session_id) == AgentSessionManager.DEFAULT_TITLE:
		AgentSessionManager.set_title(session_id, queued)
	session.messages.append(ChatMessage.user(queued))
	var details: Dictionary[String, String] = {}
	if StringUtils.is_not_blank(checkpoint):
		details[ChatEntry.DETAIL_CHECKPOINT] = checkpoint
	AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_USER, ChatEntry.TITLE_USER, queued, details)
	AgentSessionManager.persist_session(session_id)
	await run_agent(session)
	pass


static func on_session_resume(session_id: int) -> void:
	if not AgentSessionManager.has_index(session_id):
		return
	if is_running(session_id):
		Alert.alert("session is busy", ColorBase.error)
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	await run_agent(session)
	pass


static func on_session_removed(session_id: int) -> void:
	request_stop(session_id)
	pass


static func on_session_queue_changed(session_id: int) -> void:
	try_run_next.call_deferred(session_id)
	pass


static func on_chat_entry_delete(session_id: int) -> void:
	request_stop(session_id)
	pass


static func on_turn_start(session_id: int) -> void:
	clear_step_entries(session_id)
	pass


static func run_agent(session: AgentSession) -> void:
	if not AgentSessionManager.has_index(session.id):
		return
	var runtime := get_or_start(session.id)
	var ai_client := ApiSetting.get_client()
	ai_client.cancel_scope = runtime.cancel_scope
	await AgentLoop.run(ai_client, session)
	pass


static func request_stop(session_id: int) -> void:
	var runtime := get_runtime(session_id)
	if runtime == null or runtime.stop_requested:
		return
	runtime.stop_requested = true
	runtime.cancel_scope.cancel()
	pass


static func is_stop_requested(session_id: int) -> bool:
	var runtime := get_runtime(session_id)
	return runtime == null or runtime.stop_requested


static func clear_step_entries(session_id: int) -> void:
	var runtime := get_runtime(session_id)
	if runtime == null:
		return
	runtime.step_thinking_entry = null
	runtime.step_agent_entry = null
	pass


static func stop(session_id: int) -> void:
	runtimes.erase(session_id)
	pass


static func clear() -> void:
	for runtime: RuntimeState in runtimes.values():
		runtime.cancel_scope.cancel()
	runtimes.clear()
	pass
