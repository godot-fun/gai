class_name NoteSetting
extends RefCounted

## Persisted preferences for the Note app — open-on-startup, view mode, and related toggles.

enum ViewMode { EDIT, SPLIT, PREVIEW }

const OPEN_ON_STARTUP_KEY := "note_open_on_startup"
const VIEW_MODE_KEY := "note_view_mode"


static func get_open_on_startup() -> bool:
	return Setting.get_bool(OPEN_ON_STARTUP_KEY, true)


static func set_open_on_startup(enabled: bool) -> void:
	Setting.set_bool(OPEN_ON_STARTUP_KEY, enabled)
	Setting.save()
	pass


static func get_view_mode() -> ViewMode:
	var mode: ViewMode = Setting.get_int(VIEW_MODE_KEY, ViewMode.SPLIT)
	if mode == ViewMode.EDIT or mode == ViewMode.SPLIT or mode == ViewMode.PREVIEW:
		return mode
	return ViewMode.SPLIT


static func set_view_mode(mode: ViewMode) -> void:
	if get_view_mode() == mode:
		return
	Setting.set_int(VIEW_MODE_KEY, mode)
	Setting.save()
	pass
