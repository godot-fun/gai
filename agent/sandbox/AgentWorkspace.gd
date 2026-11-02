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

## Data folder used when no [constant CLI_DATA_DIR_ARG] is given. Everything goes through
## [method get_data_path], so this is the only place naming it.
const DEFAULT_DATA_DIR := ".gai"

## Command-line argument that overrides the data folder: `--data-dir <path>` or `--data-dir=<path>`.
## The value is workspace-relative; user args after `--` win over engine args.
const CLI_DATA_DIR_ARG := "--data-dir"

## Data folder relative to the workspace root: the [constant CLI_DATA_DIR_ARG] value when present,
## otherwise [constant DEFAULT_DATA_DIR]. [method get_data_path] joins it with [method get_root],
## so it follows a workspace switch on its own.
static var data_dir := ""


static func _static_init() -> void:
	data_dir = OSUtils.get_cmdline_arg_value(CLI_DATA_DIR_ARG)
	if data_dir.is_empty():
		data_dir = DEFAULT_DATA_DIR
	pass


## Absolute path of [param subdir] inside [member data_dir]; empty [param subdir] returns the folder.
static func get_data_path(subdir: String) -> String:
	var path := subdir.strip_edges()
	var dir := get_root().path_join(data_dir)
	if path.is_empty():
		return dir
	return dir.path_join(path)
