extends RefCounted


static func custom_editor_path_round_trip_test() -> void:
	var original_path := AgentSetting.get_custom_editor_path()
	var original_editor := AgentSetting.get_workspace_editor()
	var sample_path := FileUtils.normalize_path(OS.get_executable_path())
	AgentSetting.set_custom_editor_path(sample_path)
	AgentSetting.set_workspace_editor("custom")
	assert(AgentSetting.get_custom_editor_path() == sample_path)
	assert(AgentSetting.get_workspace_editor() == "custom")
	AgentSetting.set_custom_editor_path(original_path)
	AgentSetting.set_workspace_editor(original_editor)
	pass


static func editor_discovery_cache_test() -> void:
	EditorDiscovery.invalidate_cache()
	var first_result: Variant = await ExecutorHelper.async_execute_pooled(EditorDiscovery.discover)
	var second_result: Variant = await ExecutorHelper.async_execute_pooled(EditorDiscovery.discover)
	var first := first_result as Array[EditorApplication]
	var second := second_result as Array[EditorApplication]
	assert(not first.is_empty())
	assert(first.size() == second.size())
	assert(first[0] == second[0])
	assert(first[0].id == EditorDiscovery.BUILTIN_ID)
	pass


static func editor_discovery_file_arguments_test() -> void:
	var path := "C:/workspace/docs/readme.md"
	var vscode := EditorApplication.new("vscode", "Visual Studio Code", "code.exe", "")
	var git_bash := EditorApplication.new("git_bash", "Git Bash", "git-bash.exe", "")
	assert(EditorDiscovery.file_arguments(vscode, path) == PackedStringArray([path]))
	assert(EditorDiscovery.file_arguments(git_bash, path) == PackedStringArray(["--cd=C:/workspace/docs"]))
	assert(EditorDiscovery.find_editor([vscode, git_bash], "git_bash") == git_bash)
	assert(EditorDiscovery.find_editor([vscode, git_bash], "missing") == null)
	pass
