extends RefCounted

## Sidebar names — the first turn names the chat, later turns and renames leave it alone.


## A fresh chat holds only the injected contexts, so its first message is the naming one.
func context_entries_are_not_chat_history_test() -> void:
	var session := AgentSession.new(41)
	session.chat_entries.append(ChatEntry.new(ChatEntry.KIND_SYSTEM, ChatEntry.TITLE_SYSTEM, "system"))
	session.chat_entries.append(ChatEntry.new(ChatEntry.KIND_AGENT_PROMPT, ChatEntry.TITLE_AGENT_PROMPT, "map"))
	session.chat_entries.append(ChatEntry.new(ChatEntry.KIND_SKILL, ChatEntry.TITLE_SKILL, "skills"))
	session.chat_entries.append(ChatEntry.new(ChatEntry.KIND_MEMORY, ChatEntry.TITLE_MEMORY, "memory"))
	AgentSessionStore.sessions.put(session.id, session)
	assert(not AgentSessionManager.has_chat_history(session.id))

	session.chat_entries.append(ChatEntry.new(ChatEntry.KIND_USER, ChatEntry.TITLE_USER, "first message"))
	assert(AgentSessionManager.has_chat_history(session.id))

	AgentSessionStore.sessions.remove(session.id)
	pass


## The title comes from the message, whatever name the chat was created with.
func title_comes_from_the_message_not_the_previous_name_test() -> void:
	var saved_indexes := AgentSessionManager.session_indexes
	var saved_dir := AgentSessionScope.resolved_dir
	DirAccess.make_dir_recursive_absolute("user://title_test_sessions")
	AgentSessionScope.resolved_dir = "user://title_test_sessions"
	AgentSessionManager.session_indexes = AgentSessionIndexes.new()
	var session_index := AgentSessionIndexes.SessionIndex.new()
	session_index.id = 42
	session_index.title = "新对话"
	AgentSessionManager.session_indexes.indexes.append(session_index)

	AgentSessionManager.set_title(session_index.id, "![shot.png](<C:/cache/shot.png>)  这个胶效果上面有一条白线")
	assert(session_index.title == "这个胶效果上面有一条白线")

	AgentSessionManager.session_indexes = saved_indexes
	AgentSessionScope.resolved_dir = saved_dir
	pass
