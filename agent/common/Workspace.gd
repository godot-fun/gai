class_name Workspace
extends RefCounted

## The agent workspace root — the user project every tool, editor, and session works against.
## Persisted through [Setting]; [SandboxPolicy] turns it into the file-tool boundary, so this class
## holds the path and the sandbox folder holds the policy.

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
	AgentEvents.events.workspace_changed.emit(normalized)
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
