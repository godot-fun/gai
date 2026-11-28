class_name AppDataDir
extends RefCounted

## Application data folder — one root for sessions, checkpoints, caches, and editor state.
##
## Three scopes share the same folder name so all stay discoverable:
## [constant Scope.WORKSPACE] sits under the workspace root (see [method Workspace.get_root])
## and holds state that belongs to one project; [constant Scope.APP] sits next to the application
## (see [method FileUtils.get_project_root_path]) and holds caches, so switching workspace never
## duplicates them; [constant Scope.CLOUD] is the app-wide subfolder that Steam Cloud syncs, so it
## only ever holds small, machine-independent state.
##
## This is the only script naming the folder: consumers call [method get_dir_path], and the
## application derives its ignore rules from [method get_dir_name].

enum Scope {
	## Per-workspace state: checkpoints, editor tabs.
	WORKSPACE,
	## App-wide state shared by every workspace: caches.
	APP,
	## App-wide state Steam Cloud syncs: sessions and their index, a subfolder of [constant Scope.APP].
	CLOUD,
}

## Folder name used when no [constant CLI_DIR_ARG] is given. An application chooses it by passing
## `--data-dir`; the value here is this application's editor-mode default.
const DEFAULT_DIR_NAME := ".gai_temp"

## Subfolder of [constant Scope.APP] that Steam Cloud syncs. Keep it small and machine independent —
## sessions belong here, caches and checkpoints never do.
const CLOUD_SUBDIR := "cloud"

## Command-line argument that overrides the folder: `--data-dir <path>` or `--data-dir=<path>`.
## The value is workspace-relative; user args after `--` win over engine args.
const CLI_DIR_ARG := "--data-dir"

static var _dir_name := ""


static func _static_init() -> void:
	var value := OSUtils.get_cmdline_arg_value(CLI_DIR_ARG)
	_dir_name = value if StringUtils.is_not_blank(value) else DEFAULT_DIR_NAME
	pass


## Folder name relative to the workspace root, so it follows a workspace switch on its own.
static func get_dir_name() -> String:
	return _dir_name


## Absolute path of [param subdir] inside the data folder; empty [param subdir] returns the folder.
static func get_dir_path(subdir: String, scope: Scope = Scope.WORKSPACE) -> String:
	var dir := ""
	match scope:
		Scope.WORKSPACE:
			dir = Workspace.get_root().path_join(_dir_name)
		Scope.APP:
			dir = FileUtils.get_project_root_path().path_join(_dir_name)
		Scope.CLOUD:
			dir = FileUtils.get_project_root_path().path_join(_dir_name).path_join(CLOUD_SUBDIR)
	var path := subdir.strip_edges()
	if path.is_empty():
		return dir
	return dir.path_join(path)
