class_name AgentWorkspace
extends RefCounted

## Agent workspace root — read/write via Setting (user://setting.config).

const SETTING_KEY := "agent_workspace_root"


static func get_root() -> String:
	var saved := Setting.get_string(SETTING_KEY)
	if StringUtils.is_not_blank(saved) and DirAccess.dir_exists_absolute(saved):
		return saved
	return FileUtils.get_project_root_path()


## Applies [param path] as workspace root; announces the switch on
## [signal AgentEvents.events.workspace_changed] so listeners can reload. Returns false for
## a missing / empty folder.
static func set_root(path: String) -> bool:
	var normalized := path.strip_edges()
	if normalized.is_empty() or not DirAccess.dir_exists_absolute(normalized):
		return false
	if get_root() == normalized:
		return true
	Setting.set_string(SETTING_KEY, normalized)
	Setting.save()
	GlobTool._static_init()
	AgentEvents.events.workspace_changed.emit(normalized)
	return true


static func resolve_path(raw: String) -> String:
	var path := raw.strip_edges()
	if path.is_empty():
		return get_root().simplify_path()
	if path.begins_with("res://"):
		return ProjectSettings.globalize_path(path).simplify_path()
	if path.is_absolute_path():
		return path.simplify_path()
	return get_root().path_join(path).simplify_path()
