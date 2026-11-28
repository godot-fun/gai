class_name Workspace
extends RefCounted

## The workspace root — the project folder tools, editor, and sessions work against.
## Persisted through [Setting]; the switch is announced on [signal Workspace.events.changed]
## so listeners can reload. Confinement policies live in the application, not here.

## Key in [Setting] holding the last chosen root; missing or gone falls back to the project root.
const SETTING_KEY := "workspace_root"

## Switch announcements for [method set_root]. A plain RefCounted bus, not [gdf.events]: connecting a
## static callback to the autoload-owned bus crashes the process on exit.
static var events := Events.new()


class Events:
	signal changed(path: String)


static func get_root() -> String:
	var saved := Setting.get_string(SETTING_KEY)
	if StringUtils.is_not_blank(saved) and DirAccess.dir_exists_absolute(saved):
		return FileUtils.normalize_path(saved)
	return FileUtils.normalize_path(FileUtils.get_project_root_path())


## Applies [param path] as workspace root; announces the switch on
## [signal Workspace.events.changed] so listeners can reload.
static func set_root(path: String) -> bool:
	var normalized := FileUtils.normalize_path(path)
	if normalized.is_empty():
		return false
	if not DirAccess.dir_exists_absolute(normalized):
		return false
	Setting.set_string(SETTING_KEY, normalized)
	Setting.save()
	Workspace.events.changed.emit(normalized)
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
