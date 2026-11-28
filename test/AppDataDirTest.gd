extends RefCounted

## AppDataDir — the folder name and the three scopes it resolves.


static func dir_name_test() -> void:
	# No --data-dir on the command line during tests, so the default folder name is kept.
	assert(AppDataDir.get_dir_name() == AppDataDir.DEFAULT_DIR_NAME)
	assert(AppDataDir.get_dir_path("").get_file() == AppDataDir.get_dir_name())
	pass


static func get_dir_path_test() -> void:
	var data_dir := AppDataDir.get_dir_path("")
	assert(data_dir == Workspace.get_root().path_join(AppDataDir.get_dir_name()))
	assert(AppDataDir.get_dir_path("sessions") == data_dir.path_join("sessions"))
	assert(AppDataDir.get_dir_path("cache/diff") == data_dir.path_join("cache/diff"))
	pass


static func app_scope_test() -> void:
	# App scope resolves against the application root, never against the workspace.
	var app_dir := AppDataDir.get_dir_path("", AppDataDir.Scope.APP)
	assert(app_dir == FileUtils.get_project_root_path().path_join(AppDataDir.get_dir_name()))
	assert(AppDataDir.get_dir_path("cache/diff", AppDataDir.Scope.APP) == app_dir.path_join("cache/diff"))
	pass


static func cloud_scope_test() -> void:
	# Cloud scope is the app folder plus CLOUD_SUBDIR, so it never follows a workspace switch.
	var app_dir := AppDataDir.get_dir_path("", AppDataDir.Scope.APP)
	var cloud_dir := AppDataDir.get_dir_path("", AppDataDir.Scope.CLOUD)
	assert(cloud_dir == app_dir.path_join(AppDataDir.CLOUD_SUBDIR))
	assert(AppDataDir.get_dir_path("sessions", AppDataDir.Scope.CLOUD) == cloud_dir.path_join("sessions"))
	pass
