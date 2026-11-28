extends RefCounted

## Workspace — root resolution, path normalization, and the three data folders. Read-only: writing
## the root would persist into the shared settings file and leak into other suites.


static func get_root_is_a_real_directory_test() -> void:
	# A saved root that no longer exists must fall back, so whatever comes back has to be usable.
	assert(DirAccess.dir_exists_absolute(Workspace.get_root()))
	pass


static func resolve_path_test() -> void:
	var root := Workspace.get_root()
	# Empty input means "the root itself".
	assert(Workspace.resolve_path("") == root)
	assert(Workspace.resolve_path("   ") == root)
	# Relative paths hang off the root.
	assert(Workspace.resolve_path("sub/file.gd") == FileUtils.normalize_path(root.path_join("sub/file.gd")))
	# Absolute and engine paths are only normalized, never joined.
	assert(Workspace.resolve_path("res://zfoo") == FileUtils.normalize_path("res://zfoo"))
	assert(Workspace.resolve_path("user://logs") == FileUtils.normalize_path("user://logs"))
	pass


static func data_dir_anchors_test() -> void:
	# Per-project data follows the workspace root.
	var data_dir := Workspace.get_data_dir()
	assert(data_dir == Workspace.get_root().path_join(Workspace.get_dir_name()))
	assert(Workspace.get_data_dir("checkpoints") == data_dir.path_join("checkpoints"))
	# Shared data is anchored at the application root instead, so switching workspace cannot
	# duplicate it.
	var shared_dir := Workspace.get_shared_data_dir()
	assert(shared_dir == FileUtils.get_project_root_path().path_join(Workspace.get_dir_name()))
	assert(Workspace.get_shared_data_dir("cache/diff") == shared_dir.path_join("cache/diff"))
	pass


static func cloud_dir_is_a_subfolder_of_shared_data_test() -> void:
	var cloud_dir := Workspace.get_cloud_data_dir()
	assert(cloud_dir == Workspace.get_shared_data_dir().path_join(Workspace.CLOUD_SUBDIR))
	assert(Workspace.get_cloud_data_dir("sessions") == cloud_dir.path_join("sessions"))
	pass


static func event_lives_on_the_framework_bus_test() -> void:
	# The switch is a framework lifecycle event, so it is declared on gdf.events and stays
	# available to static-init listeners.
	assert(gdf.events.has_signal("workspace_changed"))
	pass
