extends RefCounted


static func setting_button_roles_test() -> void:
	var action := Button.new()
	ButtonStyle.apply_action_button(action)
	var action_normal := action.get_theme_stylebox("normal") as StyleBoxFlat
	assert(action_normal.bg_color == Colors.surface_container_high)
	assert(action_normal.border_width_left == 0)
	assert(action_normal.corner_radius_top_left == ControlSize.radius_lg)
	action.free()
	pass


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


static func editor_discovery_find_editor_test() -> void:
	var vscode := EditorApplication.new("vscode", "Visual Studio Code", "code.exe", "")
	var zed := EditorApplication.new("zed", "Zed", "zed.exe", "")
	assert(EditorDiscovery.find_editor([vscode, zed], "zed") == zed)
	assert(EditorDiscovery.find_editor([vscode, zed], "missing") == null)
	pass


static func editor_discovery_system_entries_test() -> void:
	EditorDiscovery.invalidate_cache()
	var discovered: Variant = await ExecutorHelper.async_execute_pooled(EditorDiscovery.discover)
	var editors := discovered as Array[EditorApplication]
	assert(EditorDiscovery.find_editor(editors, EditorDiscovery.FILE_EXPLORER_ID) != null)
	# Git Bash rides along with the detected Git install, so it only appears when Git is installed.
	var git_bash := EditorDiscovery.find_editor(editors, EditorDiscovery.GIT_BASH_ID)
	if OSUtils.is_windows() and FileAccess.file_exists(GitHelper.find_windows_git_bash()):
		assert(git_bash != null)
		assert(FileAccess.file_exists(git_bash.executable))
	# Missing paths report failure instead of launching anything.
	assert(not EditorDiscovery.open_in_file_explorer("res://editor-discovery-missing-path"))
	assert(not EditorDiscovery.open_in_git_bash("res://editor-discovery-missing-path"))
	pass


static func notification_sound_volume_round_trip_test() -> void:
	var original := AgentSetting.get_notification_sound_volume()
	AgentSetting.set_notification_sound_volume(35)
	assert(AgentSetting.get_notification_sound_volume() == 35)
	assert(is_equal_approx(AgentSetting.get_notification_sound_volume_linear(), 0.35))
	AgentSetting.set_notification_sound_volume(AgentSetting.MAX_SOUND_VOLUME + 20)
	assert(AgentSetting.get_notification_sound_volume() == AgentSetting.MAX_SOUND_VOLUME)
	AgentSetting.set_notification_sound_volume(original)
	pass
