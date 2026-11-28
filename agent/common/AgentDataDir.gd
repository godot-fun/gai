class_name AgentDataDir
extends RefCounted

## Agent data folder — sessions, checkpoints, caches, and editor state all live inside it.
##
## Two scopes share the same folder name so both stay discoverable:
## [constant Scope.WORKSPACE] sits under the workspace root (see [method AgentWorkspace.get_root])
## and holds state that belongs to one project; [constant Scope.APP] sits next to the agent
## application (see [method FileUtils.get_project_root_path]) and holds caches, so switching
## workspace never duplicates them and every project hits the same cache.
##
## This is the only script naming the folder: consumers call [method get_dir_path], and
## [method GitIgnore.refresh_ignore_rules] uses [method get_dir_name] for its skip rule.

enum Scope {
	## Per-workspace state: sessions, checkpoints, editor tabs.
	WORKSPACE,
	## App-wide state shared by every workspace: caches.
	APP,
}

## Folder name used when no [constant CLI_DIR_ARG] is given.
const DEFAULT_DIR_NAME := ".gai"

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
## [constant Scope.APP] resolves against the agent application instead of the workspace.
static func get_dir_path(subdir: String, scope: Scope = Scope.WORKSPACE) -> String:
	var parent := FileUtils.get_project_root_path() if scope == Scope.APP else AgentWorkspace.get_root()
	var dir := parent.path_join(_dir_name)
	var path := subdir.strip_edges()
	if path.is_empty():
		return dir
	return dir.path_join(path)
