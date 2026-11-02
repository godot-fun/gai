static func memory_context_message_matches_system_text_test() -> void:
	var body := "memory snapshot"
	MemoryPrompt.memory_context = body
	assert(MemoryPrompt.is_memory_context_message(ChatMessage.system(body)))
	assert(not MemoryPrompt.is_memory_context_message(ChatMessage.system("other")))
	assert(not MemoryPrompt.is_memory_context_message(ChatMessage.user(body)))
	pass


static func agent_context_message_matches_system_text_test() -> void:
	var body := "agents.md body"
	AgentPrompt.agent_context = body
	assert(AgentPrompt.is_agent_context_message(ChatMessage.system(body)))
	assert(not AgentPrompt.is_agent_context_message(ChatMessage.system("other")))
	pass


static func skill_context_message_matches_system_text_test() -> void:
	var body := "skills index"
	SkillPrompt.skill_context = body
	assert(SkillPrompt.is_skill_context_message(ChatMessage.system(body)))
	assert(not SkillPrompt.is_skill_context_message(ChatMessage.user(body)))
	pass
