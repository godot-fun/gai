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
