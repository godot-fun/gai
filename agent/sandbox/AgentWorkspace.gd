class_name AgentWorkspace
extends RefCounted

## Agent workspace root — read/write via Setting (user://setting.config).

const SETTING_KEY := "agent_workspace_root"


static func get_root() -> String:
	var saved := Setting.get_string(SETTING_KEY)
	if StringUtils.is_not_blank(saved) and DirAccess.dir_exists_absolute(saved):
		return FileUtils.normalize_path(saved)
	return FileUtils.normalize_path(FileUtils.get_project_root_path())


## Applies [param path] as workspace root; announces the switch on
## [signal AgentEvents.events.workspace_changed] so listeners can reload.
static func set_root(path: String) -> bool:
	var normalized := FileUtils.normalize_path(path)
	if normalized.is_empty():
		return false
	if not DirAccess.dir_exists_absolute(normalized):
		return false
	Setting.set_string(SETTING_KEY, normalized)
	Setting.save()
	GlobTool._static_init()
	AgentEvents.events.workspace_changed.emit(normalized)
	return true


static func resolve_path(raw: String) -> String:
	var path := raw.strip_edges()
	if path.is_empty():
		return get_root()
	if path.begins_with("res://") or path.begins_with("user://"):
		return FileUtils.normalize_path(path)
	if path.is_absolute_path():
		return FileUtils.normalize_path(path)
	return FileUtils.normalize_path(get_root().path_join(path))


# ---------------------------------------------------------------------------
# Data folder — sessions, caches, and checkpoints all live under it
# ---------------------------------------------------------------------------

## Folder name of the agent data folder inside the workspace. Everything goes through
## [method get_data_path], so renaming the folder — or later driving this name from a user
## setting — only touches this constant.
const DATA_DIR_NAME := ".gai"

## Absolute agent data folder of the current workspace; follows [method get_root], so it tracks
## [method set_root]. Build paths with [method get_data_path] instead of joining by hand.
static var data_dir: String:
	get:
		return get_root().path_join(DATA_DIR_NAME)


## Absolute path of [param subdir] inside [member data_dir]; empty [param subdir] returns the folder.
static func get_data_path(subdir: String) -> String:
	var path := subdir.strip_edges()
	if path.is_empty():
		return data_dir
	return data_dir.path_join(path)
