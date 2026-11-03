class_name ShortcutSetting
extends RefCounted

## Persisted in-app shortcuts. Each shortcut is one [enum Key]: the primary key in the low bits
## and modifier flags in the high bits. Edited by [ShortcutSettingSection].

const SEARCH_SHORTCUT_KEY := "agent_search_shortcut"
## Opens chat search. Default is Ctrl+F.
const DEFAULT_SEARCH_SHORTCUT: Key = KEY_F | KEY_MASK_CTRL


static func get_search_shortcut() -> Key:
	return Setting.get_int(SEARCH_SHORTCUT_KEY, DEFAULT_SEARCH_SHORTCUT) as Key


static func set_search_shortcut(key: Key) -> void:
	if get_search_shortcut() == key:
		return
	Setting.set_int(SEARCH_SHORTCUT_KEY, key)
	Setting.save()
	AgentEvents.events.search_shortcut_changed.emit()
	pass


static func is_search_shortcut_valid(key: Key) -> bool:
	var code := key & KEY_CODE_MASK
	if code == KEY_NONE or code in [KEY_CTRL, KEY_ALT, KEY_SHIFT, KEY_META]:
		return false
	return (key & (KEY_MASK_CTRL | KEY_MASK_ALT | KEY_MASK_SHIFT | KEY_MASK_META)) != 0


static func make_search_shortcut() -> Shortcut:
	var shortcut := Shortcut.new()
	shortcut.events = [make_shortcut_event(get_search_shortcut())]
	return shortcut


static func make_shortcut_event(key: Key) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.keycode = key & KEY_CODE_MASK
	key_event.ctrl_pressed = (key & KEY_MASK_CTRL) != 0
	key_event.alt_pressed = (key & KEY_MASK_ALT) != 0
	key_event.shift_pressed = (key & KEY_MASK_SHIFT) != 0
	key_event.meta_pressed = (key & KEY_MASK_META) != 0
	return key_event
