class_name Workspace
extends RefCounted

## The active project — its root path plus where the agent keeps data for it.
##
## Three folders share the same name so all stay discoverable, and each is anchored differently:
## `<workspace root>/<data dir>` holds state that belongs to one project (checkpoints, editor tabs)
## — [method get_data_dir]; `<app root>/<data dir>` holds state shared by every workspace (caches),
## so switching workspace never duplicates it — [method get_shared_data_dir]; and
## `<app root>/<data dir>/cloud` is the folder Steam Cloud syncs, so it only ever holds small,
## machine-independent state — [method get_cloud_data_dir].
##
## This is the only script naming the folder: consumers call [method get_data_dir] or one of its
## qualified siblings, and the application derives its ignore rules from [method get_dir_name].


# ---------------------------------------------------------------------------
# Settings keys and folder names
# ---------------------------------------------------------------------------

## Key in [Setting] holding the last chosen root; missing or gone falls back to the project root.
const SETTING_KEY := "workspace_root"

## Command-line argument that overrides the folder: `--data-dir <path>` or `--data-dir=<path>`.
## The value is workspace-relative; user args after `--` win over engine args.
const CLI_DIR_ARG := "--data-dir"

## Folder name used when no [constant CLI_DIR_ARG] is given. An application chooses it by passing
## `--data-dir`; the value here is this application's editor-mode default.
const DEFAULT_DIR_NAME := ".gai_temp"

## Subfolder of the app-wide data folder that Steam Cloud syncs. Keep it small and machine
## independent — sessions belong here, caches and checkpoints never do.
const CLOUD_SUBDIR := "cloud"


# ---------------------------------------------------------------------------
# State and init
# ---------------------------------------------------------------------------

static var _dir_name := ""


static func _static_init() -> void:
	var value := OSUtils.get_cmdline_arg_value(CLI_DIR_ARG)
	_dir_name = value if StringUtils.is_not_blank(value) else DEFAULT_DIR_NAME
	pass


# ---------------------------------------------------------------------------
# Root
# ---------------------------------------------------------------------------

static func get_root() -> String:
	var saved := Setting.get_string(SETTING_KEY)
	if StringUtils.is_not_blank(saved) and DirAccess.dir_exists_absolute(saved):
		return FileUtils.normalize_path(saved)
	return FileUtils.normalize_path(FileUtils.get_project_root_path())


## Applies [param path] as workspace root; announces the switch on
## [signal gdf.events.workspace_changed] so listeners can reload.
static func set_root(path: String) -> bool:
	var normalized := FileUtils.normalize_path(path)
	if normalized.is_empty():
		return false
	if not DirAccess.dir_exists_absolute(normalized):
		return false
	Setting.set_string(SETTING_KEY, normalized)
	Setting.save()
	gdf.events.workspace_changed.emit(normalized)
	return true


## Resolves [param raw] against the workspace root: empty returns the root itself, `res://` / `user://`
## and absolute paths are only normalized, anything else is joined to the root.
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
# Data folders
# ---------------------------------------------------------------------------

## Folder name relative to its anchor, so it follows a workspace switch on its own.
static func get_dir_name() -> String:
	return _dir_name


## This workspace's data folder — the unqualified scope, so it follows the workspace root;
## empty [param subdir] returns the folder.
static func get_data_dir(subdir: String = "") -> String:
	var dir := get_root().path_join(_dir_name)
	var path := subdir.strip_edges()
	return dir if path.is_empty() else dir.path_join(path)


## The data folder shared by every workspace — never follows a workspace switch;
## empty [param subdir] returns the folder.
static func get_shared_data_dir(subdir: String = "") -> String:
	var dir := FileUtils.get_project_root_path().path_join(_dir_name)
	var path := subdir.strip_edges()
	return dir if path.is_empty() else dir.path_join(path)


## The app-wide folder Steam Cloud syncs — a subfolder of [method get_shared_data_dir];
## empty [param subdir] returns the folder.
static func get_cloud_data_dir(subdir: String = "") -> String:
	var dir := get_shared_data_dir(CLOUD_SUBDIR)
	var path := subdir.strip_edges()
	return dir if path.is_empty() else dir.path_join(path)
