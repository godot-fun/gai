extends RefCounted


static func search_shortcut_text_test() -> void:
	var ctrl_f: Key = KEY_F | KEY_MASK_CTRL
	assert(ShortcutSetting.DEFAULT_SEARCH_SHORTCUT == ctrl_f)
	assert(OS.get_keycode_string(ctrl_f) == "Ctrl+F")
	assert(ShortcutSetting.is_search_shortcut_valid(ctrl_f))
	assert(not ShortcutSetting.is_search_shortcut_valid(KEY_F))
	assert(not ShortcutSetting.is_search_shortcut_valid(KEY_CTRL | KEY_MASK_CTRL))
	var key_event := ShortcutSetting.make_shortcut_event(KEY_F | KEY_MASK_CTRL | KEY_MASK_SHIFT)
	assert(key_event.keycode == KEY_F)
	assert(key_event.ctrl_pressed)
	assert(key_event.shift_pressed)
	assert(not key_event.alt_pressed)
	assert(not key_event.meta_pressed)
	pass
