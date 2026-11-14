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


static func system_prompt_uses_workspace_system_md_test() -> void:
	var previous_context := SystemPrompt.system_context
	var body := "custom system prompt"
	SystemPrompt.system_context = body
	assert(SystemPrompt.has_system_context())
	assert(SystemPrompt.build() == body)
	SystemPrompt.system_context = previous_context
	pass


static func system_prompt_falls_back_to_generated_prompt_test() -> void:
	var previous_context := SystemPrompt.system_context
	SystemPrompt.system_context = ""
	assert(not SystemPrompt.has_system_context())
	var prompt := SystemPrompt.build()
	assert(prompt.begins_with("You are a coding agent in a Godot project workspace."))
	assert(prompt.contains("Project root: " + AgentWorkspace.get_root()))
	SystemPrompt.system_context = previous_context
	pass


static func system_prompt_toggle_controls_system_message_test() -> void:
	var previous_enabled := AgentSetting.get_system_prompt_in_prompt_enabled()

	var enabled_session := AgentSessionStore.create_session()
	ContextInjectionManager.initialize(enabled_session.id)
	assert(ContextInjectionManager.has_context_kind(enabled_session, ChatEntry.KIND_SYSTEM))
	assert(enabled_session.messages[0] is SystemChatMessage)

	AgentSetting.set_system_prompt_in_prompt_enabled(false)
	var disabled_session := AgentSessionStore.create_session()
	ContextInjectionManager.initialize(disabled_session.id)
	assert(not ContextInjectionManager.has_context_kind(disabled_session, ChatEntry.KIND_SYSTEM))

	AgentSetting.set_system_prompt_in_prompt_enabled(previous_enabled)
	pass


static func skill_context_message_matches_system_text_test() -> void:
	var body := "skills index"
	SkillPrompt.skill_context = body
	assert(SkillPrompt.is_skill_context_message(ChatMessage.system(body)))
	assert(not SkillPrompt.is_skill_context_message(ChatMessage.user(body)))
	pass
