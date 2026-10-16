class_name NoteSetting
extends RefCounted

## Persisted preferences for the Note app — open-on-startup, view mode, split ratio, and related toggles.

enum ViewMode { EDIT, SPLIT, PREVIEW }

const OPEN_ON_STARTUP_KEY := "note_open_on_startup"
const VIEW_MODE_KEY := "note_view_mode"
const SPLIT_RATIO_KEY := "note_split_ratio"

const DEFAULT_SPLIT_RATIO := 0.5
const MIN_SPLIT_RATIO := 0.15
const MAX_SPLIT_RATIO := 0.85


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


## Left-pane width as a fraction of the split (0–1). Restored across window sizes via split offset.
static func get_split_ratio() -> float:
	return clampf(Setting.get_float(SPLIT_RATIO_KEY, DEFAULT_SPLIT_RATIO), MIN_SPLIT_RATIO, MAX_SPLIT_RATIO)


static func set_split_ratio(ratio: float) -> void:
	var clamped := clampf(ratio, MIN_SPLIT_RATIO, MAX_SPLIT_RATIO)
	if is_equal_approx(get_split_ratio(), clamped):
		return
	Setting.set_float(SPLIT_RATIO_KEY, clamped)
	Setting.save()
	pass
