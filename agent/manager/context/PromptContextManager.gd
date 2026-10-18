class_name PromptContextManager
extends Object

## Owns the optional system contexts attached to a session.


## Initializes contexts in a stable order before the new-session notification is emitted.
static func initialize(session_id: int) -> void:
	if AgentSetting.get_memory_in_prompt_enabled():
		MemoryPrompt.reload_memory_context()
		append_memory(session_id)
	if AgentSetting.get_skill_in_prompt_enabled():
		append_skill(session_id)
	if AgentSetting.get_agent_prompt_in_prompt_enabled():
		append_agent_prompt(session_id)
	pass


static func has_context_kind(session: AgentSession, kind: String) -> bool:
	if session == null:
		return false
	for entry: ChatEntry in session.chat_entries:
		if entry.kind == kind:
			return true
	return false


static func append_memory(session_id: int) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null or has_context_kind(session, ChatEntry.KIND_MEMORY):
		return
	if not MemoryPrompt.has_memory_context():
		return
	var context := MemoryPrompt.get_memory_context()
	session.messages.append(ChatMessage.system(context))
	AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_MEMORY, ChatEntry.TITLE_MEMORY, context)
	pass


static func remove_memory(session_id: int) -> void:
	remove_context(session_id, ChatEntry.KIND_MEMORY, MemoryPrompt.is_memory_context_message)
	pass


static func append_skill(session_id: int) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null or has_context_kind(session, ChatEntry.KIND_SKILL):
		return
	if not SkillPrompt.has_skill_context():
		return
	var context := SkillPrompt.get_skill_context()
	session.messages.append(ChatMessage.system(context))
	AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_SKILL, ChatEntry.TITLE_SKILL, context)
	pass


static func remove_skill(session_id: int) -> void:
	remove_context(session_id, ChatEntry.KIND_SKILL, SkillPrompt.is_skill_context_message)
	pass


static func append_agent_prompt(session_id: int) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null or has_context_kind(session, ChatEntry.KIND_AGENT_PROMPT):
		return
	if not AgentPrompt.has_agent_context():
		return
	var context := AgentPrompt.get_agent_context()
	session.messages.append(ChatMessage.system(context))
	AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_AGENT_PROMPT, ChatEntry.TITLE_AGENT_PROMPT, context)
	pass


static func remove_agent_prompt(session_id: int) -> void:
	remove_context(session_id, ChatEntry.KIND_AGENT_PROMPT, AgentPrompt.is_agent_context_message)
	pass


static func remove_context(session_id: int, kind: String, matches_message: Callable) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var kept_messages: Array[ChatMessage] = []
	for message: ChatMessage in session.messages:
		if not matches_message.call(message):
			kept_messages.append(message)
	session.messages = kept_messages
	var kept_entries: Array[ChatEntry] = []
	for entry: ChatEntry in session.chat_entries:
		if entry.kind != kind:
			kept_entries.append(entry)
	session.chat_entries = kept_entries
	pass


## Refreshes the memory snapshot after compaction and before observers rebuild the transcript.
static func refresh_memory_after_compaction(session: AgentSession) -> void:
	if session == null:
		return
	var context := MemoryPrompt.reload_memory_context()
	if StringUtils.is_blank(context):
		return
	var found := false
	for entry: ChatEntry in session.chat_entries:
		if entry.kind != ChatEntry.KIND_MEMORY:
			continue
		found = true
		var previous_context := entry.body
		for message: ChatMessage in session.messages:
			if message.role == ChatMessage.ROLE_SYSTEM and message.content == previous_context:
				message.content = context
				break
		entry.body = context
	if not found and AgentSetting.get_memory_in_prompt_enabled():
		session.messages.append(ChatMessage.system(context))
		session.chat_entries.append(ChatEntry.new(ChatEntry.KIND_MEMORY, ChatEntry.TITLE_MEMORY, context))
	pass
