extends RefCounted


func session_cursor_cache_isolated_test() -> void:
	ChatEntryCursor.remove_session(91)
	ChatEntryCursor.remove_session(92)
	var first := ChatEntryCursor.get_or_create_cursor(91)
	first.chat_entry_index = 4
	var same_session := ChatEntryCursor.get_or_create_cursor(91)
	var other_session := ChatEntryCursor.get_or_create_cursor(92)
	assert(same_session == first)
	assert(same_session.chat_entry_index == 4)
	assert(other_session != first)
	ChatEntryCursor.remove_session(91)
	ChatEntryCursor.remove_session(92)
	pass


func latest_entry_text_reads_without_advancing_cursor_test() -> void:
	var session := AgentSessionStore.create_session()
	session.chat_entries.append(ChatEntry.new(ChatEntry.KIND_USER, ChatEntry.TITLE_USER, "Earlier prompt"))
	var run_start := session.chat_entries.size()
	session.chat_entries.append(ChatEntry.new(ChatEntry.KIND_THINKING, ChatEntry.TITLE_THINKING, "First thought"))
	session.chat_entries.append(ChatEntry.new(ChatEntry.KIND_AGENT, ChatEntry.TITLE_AGENT, "First answer"))
	session.chat_entries.append(ChatEntry.new(ChatEntry.KIND_AGENT, ChatEntry.TITLE_AGENT, "Final answer"))
	var cursor := ChatEntryCursor.get_or_create_cursor(session.id)
	cursor.chat_entry_index = 3
	assert(ChatEntryCursor.latest_entry_text(session.id, run_start, ChatEntry.KIND_AGENT) == "Final answer")
	assert(ChatEntryCursor.latest_entry_text(session.id, run_start, ChatEntry.KIND_THINKING) == "First thought")
	assert(cursor.chat_entry_index == 3)
	AgentSessionStore.sessions.remove(session.id)
	ChatEntryCursor.remove_session(session.id)
	pass
