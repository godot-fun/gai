class_name AgentSessionManager
extends RefCounted

## Manages multiple agent sessions and the active selection.

## Sidebar titles are trimmed to this many characters before they land in the session index.
const MAX_TITLE_LENGTH := 64
## Untouched chat title; the first prompt replaces it (see [method async_send]).
const DEFAULT_TITLE := "New Chat"

static var session_indexes := AgentSessionIndexes.new()
## Selected session. 0 only before [method load_from_disk]; from then on this is always a live session id.
static var active_session_id: int = 0
## In-flight run cancel scopes keyed by session id (see [method request_stop]).
## Deliberately kept off [AgentSessionIndexes.RunState] so persisted index JSON never sees them.
static var session_cancel_scopes: Dictionary[int, CancelScope] = {}


# ---------------------------------------------------------------------------
# Init — event wiring
# ---------------------------------------------------------------------------

static func _static_init() -> void:
	# Session persistence — auto-save when title changes
	AgentEvents.events.session_title_changed.connect(on_persist_session)

	# Agent run lifecycle
	AgentEvents.events.agent_end.connect(on_agent_end)
	AgentEvents.events.session_resume.connect(on_session_resume)

	# Turn & streaming
	AgentEvents.events.turn_start.connect(on_turn_start)
	AgentEvents.events.message_update.connect(on_message_update)
	AgentEvents.events.message_complete.connect(on_message_complete)

	# Tool execution
	AgentEvents.events.tool_execution_start.connect(on_tool_execution_start)
	AgentEvents.events.tool_execution_end.connect(on_tool_execution_end)
	pass


# ---------------------------------------------------------------------------
# Persistence — load / save
# ---------------------------------------------------------------------------

## Boot: reload the index of the current workspace, then select the first session (create one if the list is empty).
static func load_from_disk() -> void:
	AgentSessionStore.sessions.clear()
	session_indexes = AgentSessionIndexes.load_index()
	select_default_session()
	AgentSessionStore.async_load_sessions(18)
	pass


static func persist_session(session_id: int) -> void:
	if not has_index(session_id):
		return
	AgentSessionStore.save_session(session_id)
	AgentSessionIndexes.save_index(session_indexes)
	pass

static func on_persist_session(session_id: int, _arg: Variant = null) -> void:
	persist_session(session_id)
	pass


# ---------------------------------------------------------------------------
# Session registry — create, delete
# ---------------------------------------------------------------------------

## New session is prepended to the index; it is not selected here — [method select_default_session]
## covers the boot case and the sidebar selects its own new session explicitly.
## Seeds the system prompt, then session_added so listeners (e.g. SkillToggle, AgentPromptToggle) can append context.
static func create_session() -> AgentSession:
	var session := AgentSessionStore.create_session()
	add_session_index(session)

	# LLM history + matching System bubble in chat UI.
	var system_text := SystemPrompt.build()
	session.messages.append(ChatMessage.system(system_text))
	add_chat_entry(session.id, ChatEntry.KIND_SYSTEM, ChatEntry.TITLE_SYSTEM, system_text)

	# After system prompt is in place — listeners (e.g. SkillToggle) may append more context.
	AgentEvents.events.session_added.emit(session.id, get_title(session.id))

	# Save empty chat.
	persist_session(session.id)
	return session


## Deleting the active session falls back to the first remaining one (or a fresh session).
static func delete_session(session_id: int) -> void:
	if not has_index(session_id):
		return
	var session_index := get_session_index(session_id)
	if session_index != null and session_index.is_running():
		request_stop(session_id)

	AgentSessionStore.delete_session(session_id)
	remove_session_index(session_id)
	AgentSessionIndexes.save_index(session_indexes)
	AgentEvents.events.session_removed.emit(session_id)

	if active_session_id == session_id:
		select_default_session()
	pass


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

## Selects the first pinned or normal entry, creating a session when the index is empty.
static func select_default_session() -> void:
	var session_index_id: = 0
	if not session_indexes.pinned_indexes.is_empty():
		session_index_id = session_indexes.pinned_indexes[0].id
	elif not session_indexes.indexes.is_empty():
		session_index_id = session_indexes.indexes[0].id
	else:
		session_index_id = create_session().id
	select_session(session_index_id)


## Selects [param session_id]; ids missing from the index are ignored.
static func select_session(session_id: int) -> void:
	if not has_index(session_id):
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		session = AgentSession.new(session_id)
		AgentSessionStore.sessions.put(session_id, session)
	var previous_session_id := active_session_id
	active_session_id = session_id
	AgentEvents.events.session_selected.emit(session_id, previous_session_id)


# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

static func get_session_index(session_id: int) -> AgentSessionIndexes.SessionIndex:
	for session_index: AgentSessionIndexes.SessionIndex in session_indexes.pinned_indexes:
		if session_index.id == session_id:
			return session_index
	for session_index: AgentSessionIndexes.SessionIndex in session_indexes.indexes:
		if session_index.id == session_id:
			return session_index
	return null


static func is_pinned(session_id: int) -> bool:
	for session_index: AgentSessionIndexes.SessionIndex in session_indexes.pinned_indexes:
		if session_index.id == session_id:
			return true
	return false


static func has_index(session_id: int) -> bool:
	return get_session_index(session_id) != null


static func get_title(session_id: int) -> String:
	var session_index := get_session_index(session_id)
	if session_index == null:
		return ""
	return session_index.title


static func add_session_index(session: AgentSession) -> void:
	var session_index := AgentSessionIndexes.SessionIndex.new()
	session_index.id = session.id
	session_index.title = DEFAULT_TITLE
	session_indexes.indexes.insert(0, session_index)
	pass


static func remove_session_index(session_id: int) -> void:
	for list: Array[AgentSessionIndexes.SessionIndex] in [session_indexes.pinned_indexes, session_indexes.indexes]:
		for i in list.size():
			if list[i].id == session_id:
				list.remove_at(i)
				return
	pass


static func move_index_in_list(session_id: int, to_index: int, pinned: bool) -> void:
	var list := session_indexes.pinned_indexes if pinned else session_indexes.indexes
	for i in list.size():
		if list[i].id != session_id:
			continue
		var session_index := list[i]
		list.remove_at(i)
		list.insert(clampi(to_index, 0, list.size()), session_index)
		AgentSessionIndexes.save_index(session_indexes)
		return
	pass


static func transfer_session_index(session_id: int, to_pinned: bool, to_index: int) -> void:
	var session_index := get_session_index(session_id)
	if session_index == null:
		return
	remove_session_index(session_id)
	var list := session_indexes.pinned_indexes if to_pinned else session_indexes.indexes
	list.insert(clampi(to_index, 0, list.size()), session_index)
	AgentSessionIndexes.save_index(session_indexes)
	pass


static func is_active(session_id: int) -> bool:
	return active_session_id == session_id


static func is_running(session_id: int) -> bool:
	var session_index := get_session_index(session_id)
	return session_index != null and session_index.is_running()


static func has_chat_history(session_id: int) -> bool:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return false
	for entry in session.chat_entries:
		if not ChatEntry.is_context_kind(entry.kind):
			return true
	return false


# ---------------------------------------------------------------------------
# Title
# ---------------------------------------------------------------------------

## Writes the sidebar title and persists it via [signal AgentEvents.events.session_title_changed].
## Trimmed to one line and capped to [constant MAX_TITLE_LENGTH] (no ellipsis suffix) so a long
## title does not bloat the session index; the sidebar shows as much as fits the row width.
## Blank titles and unknown sessions are ignored, so a row keeps its previous name.
static func set_title(session_id: int, title: String) -> void:
	var session_index := get_session_index(session_id)
	if session_index == null or StringUtils.is_blank(title):
		return
	var one_line := title.strip_edges().replace(FileUtils.NEWLINE_LF, " ").replace(FileUtils.NEWLINE_CR, "")
	session_index.title = one_line.left(MAX_TITLE_LENGTH)
	AgentEvents.events.session_title_changed.emit(session_id, session_index.title)
	pass


# ---------------------------------------------------------------------------
# User actions — send, stop
# ---------------------------------------------------------------------------

static func async_send(session_id: int, user_text: String) -> void:
	var session_index := get_session_index(session_id)
	if session_index == null:
		return
	if session_index.is_running():
		Alert.alert("session is busy", ColorBase.error)
		return
	if StringUtils.is_blank(user_text):
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var trimmed := user_text.strip_edges()
	# The first prompt names the chat; later turns find a title that is no longer the default —
	# and a name picked in the sidebar survives for the same reason.
	if get_title(session_id) == DEFAULT_TITLE:
		set_title(session_id, trimmed)
	session.messages.append(ChatMessage.user(trimmed))
	# Snapshot before the agent can touch the workspace. The bubble decides at build time whether to
	# offer Revert, so the commit id must be known before the entry is created.
	var checkpoint := await AgentCheckpoint.async_snapshot(session_id)
	var details: Dictionary[String, String] = {}
	if StringUtils.is_not_blank(checkpoint):
		details[ChatEntry.DETAIL_CHECKPOINT] = checkpoint
	add_chat_entry(session_id, ChatEntry.KIND_USER, ChatEntry.TITLE_USER, trimmed, details)
	await run_agent(session)
	pass


static func async_resume(session_id: int) -> void:
	var session_index := get_session_index(session_id)
	if session_index == null:
		return
	if session_index.is_running():
		Alert.alert("session is busy", ColorBase.error)
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	await run_agent(session)
	pass


static func run_agent(session: AgentSession) -> void:
	var session_index := get_session_index(session.id)
	if session_index == null:
		return
	session_index.run = AgentSessionIndexes.RunState.new()
	# One scope per run: the loop's HTTP request and any tool subprocess register into it, so
	# request_stop only stops this session's work.
	var cancel_scope := CancelScope.new()
	session_cancel_scopes[session.id] = cancel_scope
	var ai_client := ApiSetting.get_client()
	ai_client.cancel_scope = cancel_scope
	await AgentLoop.run(ai_client, session)
	session_cancel_scopes.erase(session.id)
	pass


static func on_session_resume(session_id: int) -> void:
	await async_resume(session_id)
	pass

static func request_stop(session_id: int) -> void:
	var session_index := get_session_index(session_id)
	if session_index == null:
		return
	if not session_index.is_running() or session_index.is_stop_requested():
		return
	session_index.run.stop_requested = true
	var cancel_scope: CancelScope = session_cancel_scopes.get(session_id)
	if cancel_scope != null:
		cancel_scope.cancel()
	pass

static func is_stop_requested(session_id: int) -> bool:
	var session_index := get_session_index(session_id)
	if session_index == null:
		return true
	if not session_index.is_running():
		return true
	return session_index.is_stop_requested()

# ---------------------------------------------------------------------------
# Chat Entry
# ---------------------------------------------------------------------------

static func append_chat_entry_stream(session_id: int, stream_kind: String, chunk: String) -> ChatEntry:
	var session_index := get_session_index(session_id)
	if session_index == null or session_index.run == null:
		return null
	var run := session_index.run
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		if run.step_thinking_entry == null:
			run.step_thinking_entry = add_chat_entry(session_id, ChatEntry.KIND_THINKING, ChatEntry.TITLE_THINKING, chunk)
		else:
			run.step_thinking_entry.body += chunk
		return run.step_thinking_entry
	if run.step_agent_entry == null:
		run.step_agent_entry = add_chat_entry(session_id, ChatEntry.KIND_AGENT, ChatEntry.TITLE_AGENT, chunk)
	else:
		run.step_agent_entry.body += chunk
	return run.step_agent_entry


static func add_chat_entry(session_id: int, kind: String, entry_title: String, body: String, details: Dictionary[String, String] = {}) -> ChatEntry:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return null
	var entry := ChatEntry.new(kind, entry_title, body, details)
	session.chat_entries.append(entry)
	AgentEvents.events.chat_entry_add.emit(session_id, entry)
	return entry


## Deletes chat from the selected entry. User entries truncate the following chat and matching
## LLM history; error entries only remove themselves because they are not model messages.
## Chat only — workspace files are left untouched.
static func delete_chat_from_entry(session_id: int, entry: ChatEntry) -> void:
	if entry == null or entry.kind not in [ChatEntry.KIND_USER, ChatEntry.KIND_ERROR]:
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var entry_idx := session.chat_entries.find(entry)
	if entry_idx < 0:
		return
	if entry.kind == ChatEntry.KIND_ERROR:
		session.chat_entries.remove_at(entry_idx)
		persist_session(session_id)
		AgentEvents.events.chat_entry_delete.emit(session_id)
		return
	if is_running(session_id):
		request_stop(session_id)
	var msg_idx := message_index_for_user_chat_entry(session, entry_idx)
	session.chat_entries = session.chat_entries.slice(0, entry_idx)
	session.messages = session.messages.slice(0, msg_idx)
	persist_session(session_id)
	AgentEvents.events.chat_entry_delete.emit(session_id)
	pass


## Truncates the chat from [param entry] and reverts the workspace to the snapshot taken before that turn.
## Entries without a snapshot (older chats, checkpoints unavailable) just truncate.
static func revert_to_entry(session_id: int, entry: ChatEntry) -> void:
	if entry == null:
		return
	var sha: String = entry.details.get(ChatEntry.DETAIL_CHECKPOINT, "")
	if not await AgentCheckpoint.async_restore(session_id, sha):
		Alert.alert("Workspace restore failed; chat history was kept", ColorBase.error)
		return
	delete_chat_from_entry(session_id, entry)
	Alert.alert("Workspace restored", ColorBase.success)
	pass


static func message_index_for_user_chat_entry(session: AgentSession, entry_idx: int) -> int:
	if entry_idx < 0 or entry_idx >= session.chat_entries.size():
		return session.messages.size()
	if session.chat_entries[entry_idx].kind != ChatEntry.KIND_USER:
		return session.messages.size()
	var user_slot := 0
	for i in range(entry_idx):
		if session.chat_entries[i].kind == ChatEntry.KIND_USER:
			user_slot += 1
	var seen_users := 0
	for i in range(session.messages.size()):
		var msg: ChatMessage = session.messages[i]
		if msg.role != ChatMessage.ROLE_USER:
			continue
		if seen_users == user_slot:
			return i
		seen_users += 1
	return session.messages.size()

# ---------------------------------------------------------------------------
# Event handlers — agent run
# ---------------------------------------------------------------------------

static func on_agent_end(session_id: int, error_message: String) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	if StringUtils.is_not_blank(error_message):
		add_chat_entry(session_id, ChatEntry.KIND_ERROR, ChatEntry.TITLE_ERROR, error_message)
	await AgentCheckpoint.async_append_git_diff(session_id)
	persist_session(session_id)

	var session_index := get_session_index(session_id)
	if session_index != null:
		session_index.stop_running()
	AgentEvents.events.session_stop.emit(session_id)
	pass


# ---------------------------------------------------------------------------
# Event handlers — turn & streaming
# ---------------------------------------------------------------------------

static func on_turn_start(session_id: int) -> void:
	var session_index := get_session_index(session_id)
	if session_index == null:
		return
	session_index.clear_run_state()
	pass


static func on_message_update(session_id: int, chunk: String, stream_kind: String) -> void:
	var entry := append_chat_entry_stream(session_id, stream_kind, chunk)
	if entry == null:
		return
	AgentEvents.events.chat_entry_update.emit(session_id, entry, stream_kind)
	pass


static func on_message_complete(session_id: int, usage: OpenAiUsage) -> void:
	if not usage.has_data():
		return
	var session := AgentSessionStore.load_session(session_id)
	if session != null:
		session.usage.copy_from(usage)
	pass


# ---------------------------------------------------------------------------
# Event handlers — tool execution
# ---------------------------------------------------------------------------

static func on_tool_execution_start(session_id: int, _tool_call_id: String, tool_name: String, args: Dictionary[String, Variant]) -> void:
	if AgentHelper.is_file_tool(tool_name):
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
	add_chat_entry(session_id, ChatEntry.KIND_TOOL, tool_name, body)
	pass


static func on_tool_execution_end(session_id: int, _tool_call_id: String, tool_name: String, agent_tool_result: AgentToolResult) -> void:
	if AgentHelper.is_file_tool(tool_name):
		var path: String = agent_tool_result.details.get(AgentToolResult.DETAIL_FILE_PATH, "")
		add_chat_entry(session_id, ChatEntry.KIND_FILE_TOOL, tool_name, path, agent_tool_result.details)
		return
	var title: String = agent_tool_result.details.get(AgentToolResult.DETAIL_TITLE, "")
	var body: String = agent_tool_result.details.get(AgentToolResult.DETAIL_BODY, "")
	add_chat_entry(session_id, ChatEntry.KIND_RESULT, title, body, agent_tool_result.details)
	pass
