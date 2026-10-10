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
	AgentEvents.events.agent_end.connect(on_agent_end)
	AgentEvents.events.message_update.connect(on_message_update)
	AgentEvents.events.tool_execution_start.connect(on_tool_execution_start)
	AgentEvents.events.tool_execution_end.connect(on_tool_execution_end)
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


static func on_agent_end(session_id: int, error_message: String) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		stop(session_id)
		return
	var has_session_index := AgentSessionManager.has_index(session_id)
	# Capture before removing the runtime; a missing runtime is treated as stopped.
	var should_continue_queue := has_session_index and not is_stop_requested(session_id) and StringUtils.is_blank(error_message)
	if StringUtils.is_not_blank(error_message):
		AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_ERROR, ChatEntry.TITLE_ERROR, error_message)
	await GitDiff.async_append_git_diff(session_id)
	AgentSessionManager.persist_session(session_id)

	stop(session_id)
	AgentEvents.events.session_stop.emit(session_id)
	if should_continue_queue:
		try_run_next.call_deferred(session_id)
	pass


static func on_message_update(session_id: int, chunk: String, stream_kind: String) -> void:
	var entry := append_chat_entry_stream(session_id, stream_kind, chunk)
	if entry == null:
		return
	AgentEvents.events.chat_entry_update.emit(session_id, entry, stream_kind)
	pass


static func append_chat_entry_stream(session_id: int, stream_kind: String, chunk: String) -> ChatEntry:
	if not AgentSessionManager.has_index(session_id):
		return null
	var runtime := get_runtime(session_id)
	if runtime == null:
		return null
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		if runtime.step_thinking_entry == null:
			runtime.step_thinking_entry = AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_THINKING, ChatEntry.TITLE_THINKING, chunk)
		else:
			runtime.step_thinking_entry.body += chunk
		return runtime.step_thinking_entry
	if runtime.step_agent_entry == null:
		runtime.step_agent_entry = AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_AGENT, ChatEntry.TITLE_AGENT, chunk)
	else:
		runtime.step_agent_entry.body += chunk
	return runtime.step_agent_entry


static func on_tool_execution_start(session_id: int, _tool_call_id: String, tool_name: String, args: Dictionary[String, Variant]) -> void:
	if ToolHelper.is_file_tool(tool_name):
		return
	var body := ""
	match tool_name:
		GrepTool.NAME:
			body = str(args.get(GrepTool.ARG_PATTERN, ""))
		GlobTool.NAME:
			body = str(args.get(GlobTool.ARG_PATTERN, ""))
		ListDirTool.NAME:
			body = str(args.get(ListDirTool.ARG_PATH, ""))
		BashTool.NAME:
			body = str(args.get(BashTool.ARG_COMMAND, ""))
		ImageToTextTool.NAME:
			body = str(args.get(ImageToTextTool.ARG_PATH, "")) + FileUtils.NEWLINE_LF + str(args.get(ImageToTextTool.ARG_PROMPT, ""))
		AudioToTextTool.NAME:
			body = str(args.get(AudioToTextTool.ARG_PATH, ""))
		WebSearchToolProxy.NAME, WebSearchToolBing.NAME:
			body = str(args.get(WebSearchToolProxy.ARG_QUERY, ""))
		WebFetchTool.NAME:
			body = str(args.get(WebFetchTool.ARG_URL, ""))
		_:
			for key: Variant in args.keys():
				var value := str(args[key])
				if StringUtils.is_not_blank(value):
					body = value
					break
	AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_TOOL, tool_name, body)
	pass


static func on_tool_execution_end(session_id: int, _tool_call_id: String, tool_name: String, agent_tool_result: AgentToolResult) -> void:
	if ToolHelper.is_file_tool(tool_name):
		var path: String = agent_tool_result.details.get(AgentToolResult.DETAIL_FILE_PATH, "")
		AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_FILE_TOOL, tool_name, path, agent_tool_result.details)
		return
	var title: String = agent_tool_result.details.get(AgentToolResult.DETAIL_TITLE, "")
	var body: String = agent_tool_result.details.get(AgentToolResult.DETAIL_BODY, "")
	AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_RESULT, title, body, agent_tool_result.details)
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
