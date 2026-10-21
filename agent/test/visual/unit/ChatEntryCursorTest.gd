extends RefCounted


static func take_next_waits_for_complete_tail_test() -> void:
	var agent_entry := ChatEntry.new(ChatEntry.KIND_AGENT, ChatEntry.TITLE_AGENT, "First. Second")
	var entries: Array[ChatEntry] = [agent_entry]
	var cursor := ChatEntryCursor.new()
	var first := cursor.take_next(entries)
	assert(first.text == "First.")
	assert(first.entry == agent_entry)
	assert(cursor.take_next(entries).is_empty())
	entries[0].body += " complete!"
	var second := cursor.take_next(entries)
	assert(second.text == "Second complete!")
	assert(second.entry == agent_entry)
	pass


static func parse_sentence_test() -> void:
	var parse := ChatEntryCursor.parse_sentence("Alpha. Beta.", 0)
	assert(parse.text == "Alpha.")
	assert(parse.next_index == 6)
	assert(ChatEntryCursor.parse_sentence("still typing", 0).text.is_empty())
	pass


static func session_cursor_cache_isolated_test() -> void:
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


static func latest_entry_text_reads_without_advancing_cursor_test() -> void:
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
