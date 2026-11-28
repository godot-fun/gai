extends RefCounted

## Workspace — root resolution and path normalization. Read-only: writing the root would persist
## into the shared settings file and leak into other suites.


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


static func event_lives_on_the_framework_bus_test() -> void:
	# The switch is a framework lifecycle event, so it is declared on gdf.events and stays
	# available to static-init listeners.
	assert(gdf.events.has_signal("workspace_changed"))
	pass
