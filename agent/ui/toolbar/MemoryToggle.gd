class_name MemoryToggle
extends RefCounted

## Toolbar toggle for the project memory index (session append/remove).

var button: Button


func setup(p_button: Button) -> void:
	button = p_button
	button.toggled.connect(on_toggled)
	gdf.events.theme_changed.connect(refresh_toggle_button)
	gdf.events.theme_color_changed.connect(refresh_toggle_button)
	gdf.events.locale_changed.connect(refresh_toggle_button)
	AgentEvents.events.session_added.connect(on_session_added)
	refresh_toggle_button()
	pass


static func on_session_added(session_id: int, _title: String) -> void:
	if not AgentSetting.get_memory_in_prompt_enabled():
		return
	append_memory_context(session_id)
	pass


static func has_memory_context_in(session: AgentSession) -> bool:
	if session == null:
		return false
	for entry: ChatEntry in session.chat_entries:
		if entry.kind == ChatEntry.KIND_MEMORY:
			return true
	return false


static func append_memory_context(session_id: int) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null or has_memory_context_in(session):
		return
	if not MemoryPrompt.has_memory_context():
		return
	session.messages.append(ChatMessage.system(MemoryPrompt.get_memory_context()))
	AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_MEMORY, ChatEntry.TITLE_MEMORY, MemoryPrompt.get_memory_context())
	pass


static func remove_memory_context(session_id: int) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return

	var kept_messages: Array[ChatMessage] = []
	for msg in session.messages:
		if not MemoryPrompt.is_memory_context_message(msg):
			kept_messages.append(msg)
	session.messages = kept_messages

	var kept_entries: Array[ChatEntry] = []
	for entry: ChatEntry in session.chat_entries:
		if entry.kind != ChatEntry.KIND_MEMORY:
			kept_entries.append(entry)
	session.chat_entries = kept_entries
	pass


func refresh_toggle_button() -> void:
	var enabled := AgentSetting.get_memory_in_prompt_enabled()
	var tooltip := I18n.t("agent.toolbar.add_memory") if not enabled else I18n.t("agent.toolbar.remove_memory")
	AgentToolbarButton.style(button, tooltip)
	button.set_block_signals(true)
	button.button_pressed = enabled
	button.set_block_signals(false)
	pass


func on_toggled(enabled: bool) -> void:
	AgentSetting.set_memory_in_prompt_enabled(enabled)
	refresh_toggle_button()

	var session_id := AgentSessionManager.active_session_id
	if AgentSessionManager.has_chat_history(session_id):
		return

	if enabled:
		append_memory_context(session_id)
	else:
		remove_memory_context(session_id)
	AgentSessionManager.persist_session(session_id)
	AgentEvents.events.memory_context_changed.emit(session_id)
	pass
