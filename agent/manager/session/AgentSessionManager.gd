class_name AgentSessionManager
extends Object

## Manages multiple agent sessions and the active selection.

## Sidebar titles are trimmed to this many characters before they land in the session index.
const MAX_TITLE_LENGTH := 64

static var session_indexes := AgentSessionIndexes.new()
## Selected session. 0 only before [method load_from_disk]; from then on this is always a live session id.
static var active_session_id: int = 0


# ---------------------------------------------------------------------------
# Init — event wiring
# ---------------------------------------------------------------------------

static func _static_init() -> void:
	# Session persistence — auto-save when title changes
	AgentEvents.events.session_title_changed.connect(on_persist_session)
	# Turn & streaming
	AgentEvents.events.message_complete.connect(on_message_complete)
	pass


# ---------------------------------------------------------------------------
# Persistence
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
# Session lifecycle
# ---------------------------------------------------------------------------

## New session is prepended to the index; it is not selected here — [method select_default_session]
## covers the boot case and the sidebar selects its own new session explicitly.
## Seeds the system prompt and optional contexts before notifying observers.
static func create_session() -> AgentSession:
	var session := AgentSessionStore.create_session()
	add_session_index(session)

	# LLM history + matching System bubble in chat UI.
	var system_text := SystemPrompt.build()
	session.messages.append(ChatMessage.system(system_text))
	add_chat_entry(session.id, ChatEntry.KIND_SYSTEM, ChatEntry.TITLE_SYSTEM, system_text)

	PromptContextManager.initialize(session.id)
	AgentEvents.events.session_added.emit(session.id, get_title(session.id))

	# Save empty chat.
	persist_session(session.id)
	return session


## Deleting the active session selects the next displayed session, then falls back to the default.
static func delete_session(session_id: int) -> void:
	if not has_index(session_id):
		return
	var next_session_id := get_next_session_id(session_id) if active_session_id == session_id else 0

	AgentSessionStore.delete_session(session_id)
	remove_session_index(session_id)
	AgentSessionIndexes.save_index(session_indexes)
	AgentEvents.events.session_removed.emit(session_id)

	if active_session_id == session_id:
		if next_session_id != 0:
			select_session(next_session_id)
		else:
			select_default_session()
	pass


# ---------------------------------------------------------------------------
# Session selection
# ---------------------------------------------------------------------------

## Selects the first pinned or normal entry, creating a session when the index is empty.
static func select_default_session() -> void:
	var session_index_id := 0
	if not session_indexes.pinned_indexes.is_empty():
		session_index_id = session_indexes.pinned_indexes[0].id
	elif not session_indexes.indexes.is_empty():
		session_index_id = session_indexes.indexes[0].id
	else:
		session_index_id = create_session().id
	select_session(session_index_id)
	pass


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
	pass


static func is_active(session_id: int) -> bool:
	return active_session_id == session_id


# ---------------------------------------------------------------------------
# Session index management
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


## Returns the session displayed immediately after [param session_id] across pinned and normal lists.
static func get_next_session_id(session_id: int) -> int:
	var found := false
	for list: Array[AgentSessionIndexes.SessionIndex] in [session_indexes.pinned_indexes, session_indexes.indexes]:
		for session_index: AgentSessionIndexes.SessionIndex in list:
			if found:
				return session_index.id
			if session_index.id == session_id:
				found = true
	return 0


static func add_session_index(session: AgentSession) -> void:
	var session_index := AgentSessionIndexes.SessionIndex.new()
	session_index.id = session.id
	session_index.title = get_default_title()
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


# ---------------------------------------------------------------------------
# Session title
# ---------------------------------------------------------------------------

static func get_default_title() -> String:
	return I18n.t("agent.sidebar.default_title")


static func has_default_title(session_id: int) -> bool:
	return get_title(session_id) == get_default_title()


static func get_title(session_id: int) -> String:
	var session_index := get_session_index(session_id)
	if session_index == null:
		return ""
	return session_index.title


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
# Pending message queue
# ---------------------------------------------------------------------------

static func enqueue_message(session_id: int, user_text: String) -> bool:
	var session_index := get_session_index(session_id)
	if session_index == null:
		return false
	if StringUtils.is_blank(user_text):
		return false
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return false
	var trimmed := user_text.strip_edges()
	session.pending_messages.append(trimmed)
	session.draft_text = ""
	persist_session(session_id)
	AgentEvents.events.session_queue_changed.emit(session_id)
	return true


static func delete_pending_message(session_id: int, message: String) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var index := session.pending_messages.find(message)
	if index < 0:
		return
	session.pending_messages.remove_at(index)
	persist_session(session_id)
	AgentEvents.events.session_queue_changed.emit(session_id)
	pass


# ---------------------------------------------------------------------------
# Chat history
# ---------------------------------------------------------------------------

static func has_chat_history(session_id: int) -> bool:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return false
	for entry in session.chat_entries:
		if not ChatEntry.is_context_kind(entry.kind):
			return true
	return false


static func add_chat_entry(session_id: int, kind: String, entry_title: String, body: String, details: Dictionary[String, String] = {}) -> ChatEntry:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return null
	var entry := ChatEntry.new(kind, entry_title, body, details)
	session.chat_entries.append(entry)
	AgentEvents.events.chat_entry_add.emit(session_id, entry)
	return entry


## Deletes the selected entry while keeping its chat-entry and LLM-message representations in sync.
## Entries backed by an LLM message truncate everything from that point; entries without one,
## such as errors, only remove themselves.
## Chat only — workspace files are left untouched.
static func delete_chat_from_entry(session_id: int, entry: ChatEntry) -> void:
	if entry == null:
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var entry_idx := session.chat_entries.find(entry)
	if entry_idx < 0:
		return
	var message_idx := message_index_for_chat_entry(session, entry_idx)
	if entry.kind == ChatEntry.KIND_USER:
		session.chat_entries = session.chat_entries.slice(0, entry_idx)
		session.messages = session.messages.slice(0, message_idx)
	else:
		session.chat_entries.remove_at(entry_idx)
		if message_idx >= 0:
			session.messages.remove_at(message_idx)
	persist_session(session_id)
	AgentEvents.events.chat_entry_delete.emit(session_id)
	pass


## Resolves a deletable UI entry to its backing LLM message. Returns -1 when the entry has no
## message representation, such as an error entry.
static func message_index_for_chat_entry(session: AgentSession, entry_idx: int) -> int:
	if entry_idx < 0 or entry_idx >= session.chat_entries.size():
		return -1
	var entry: ChatEntry = session.chat_entries[entry_idx]
	if ChatEntry.is_context_kind(entry.kind):
		for message_idx in range(session.messages.size()):
			var message: ChatMessage = session.messages[message_idx]
			var matches := false
			if entry.kind == ChatEntry.KIND_SYSTEM:
				matches = message.role == ChatMessage.ROLE_SYSTEM and message.content == entry.body
			elif entry.kind == ChatEntry.KIND_SKILL:
				matches = SkillPrompt.is_skill_context_message(message)
			elif entry.kind == ChatEntry.KIND_MEMORY:
				matches = MemoryPrompt.is_memory_context_message(message)
			elif entry.kind == ChatEntry.KIND_AGENT_PROMPT:
				matches = AgentPrompt.is_agent_context_message(message)
			elif entry.kind == ChatEntry.KIND_COMPACTION:
				matches = CompactionPrompt.is_compaction_message(message)
			if matches:
				return message_idx
		return -1
	if entry.kind != ChatEntry.KIND_USER:
		return -1
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
# Event handlers
# ---------------------------------------------------------------------------

static func on_message_complete(session_id: int, usage: OpenAiUsage) -> void:
	if not usage.has_data():
		return
	var session := AgentSessionStore.load_session(session_id)
	if session != null:
		session.usage.copy_from(usage)
	pass
