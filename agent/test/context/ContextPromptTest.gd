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


static func system_prompt_prefers_workspace_system_md_test() -> void:
	var prior_workspace := AgentWorkspace.get_root()
	var root := FileUtils.normalize_path("user://system_prompt_test")
	DirAccess.make_dir_recursive_absolute(root)
	var file := FileAccess.open(root.path_join(SystemPrompt.SYSTEM_PATH), FileAccess.WRITE)
	file.store_string("custom system prompt")
	file.close()
	assert(AgentWorkspace.set_root(root))
	assert(SystemPrompt.load_system_prompt() == "custom system prompt")
	assert(SystemPrompt.build() == "custom system prompt")
	AgentWorkspace.set_root(prior_workspace)
	pass


static func system_prompt_falls_back_to_generated_prompt_test() -> void:
	if StringUtils.is_not_blank(SystemPrompt.load_system_prompt()):
		# The workspace itself may provide SYSTEM.md; only the fallback branch is asserted here.
		return
	var prompt := SystemPrompt.build()
	assert(prompt.begins_with("You are a coding agent in a Godot project workspace."))
	assert(prompt.contains("Project root: " + AgentWorkspace.get_root()))
	assert(prompt.contains("Godot version: "))
	pass


static func skill_context_message_matches_system_text_test() -> void:
	var body := "skills index"
	SkillPrompt.skill_context = body
	assert(SkillPrompt.is_skill_context_message(ChatMessage.system(body)))
	assert(not SkillPrompt.is_skill_context_message(ChatMessage.user(body)))
	pass
