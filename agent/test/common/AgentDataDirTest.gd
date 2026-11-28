extends RefCounted


static func dir_name_test() -> void:
	# No --data-dir on the command line during tests, so the plain folder name is kept.
	assert(AgentDataDir.get_dir_name() == AgentDataDir.DEFAULT_DIR_NAME)
	assert(AgentDataDir.get_dir_path("").get_file() == ".gai_temp")
	pass


static func get_dir_path_test() -> void:
	var data_dir := AgentDataDir.get_dir_path("")
	assert(data_dir == Workspace.get_root().path_join(AgentDataDir.DEFAULT_DIR_NAME))
	assert(AgentDataDir.get_dir_path("sessions") == data_dir.path_join("sessions"))
	assert(AgentDataDir.get_dir_path("cache/diff") == data_dir.path_join("cache/diff"))
	pass


static func get_app_dir_path_test() -> void:
	# App scope resolves against the agent application, never against the workspace, so caches are
	# shared by every project instead of being duplicated per workspace.
	var app_dir := AgentDataDir.get_dir_path("", AgentDataDir.Scope.APP)
	assert(app_dir == FileUtils.get_project_root_path().path_join(AgentDataDir.DEFAULT_DIR_NAME))
	assert(AgentDataDir.get_dir_path("cache/diff", AgentDataDir.Scope.APP) == app_dir.path_join("cache/diff"))
	pass


static func cache_dir_is_app_scoped_test() -> void:
	var app_root := AgentDataDir.get_dir_path("", AgentDataDir.Scope.APP)
	assert(CacheManager.get_diff_cache_dir().begins_with(app_root))
	assert(CacheManager.get_web_screenshot_cache_dir().begins_with(app_root))
	assert(CacheManager.get_clipboard_cache_dir().begins_with(app_root))
	assert(CacheManager.get_markdown_image_cache_dir().begins_with(app_root))
	pass


static func cloud_dir_is_synced_and_app_scoped_test() -> void:
	var app_root := AgentDataDir.get_dir_path("", AgentDataDir.Scope.APP)
	var cloud_dir := AgentDataDir.get_dir_path("", AgentDataDir.Scope.CLOUD)
	assert(cloud_dir == app_root.path_join(AgentDataDir.CLOUD_SUBDIR))
	assert(AgentDataDir.get_dir_path("sessions", AgentDataDir.Scope.CLOUD) == cloud_dir.path_join("sessions"))
	pass
