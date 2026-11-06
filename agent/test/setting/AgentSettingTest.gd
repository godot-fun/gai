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
