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
