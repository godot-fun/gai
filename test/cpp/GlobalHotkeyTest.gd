## Unit tests for GlobalHotkey dynamic register / unregister.
extends RefCounted


func global_hotkey_register_unregister_test() -> void:
	const ID := 9001
	# Prefer an uncommon combo so OS rejection is unlikely on a clean desktop.
	var ok: bool = GlobalHotkey.register_hotkey(ID, KEY_F9, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_MASK_ALT)
	assert(ok)
	assert(GlobalHotkey.is_registered(ID))
	assert(GlobalHotkey.get_registered_ids().has(ID))

	assert(GlobalHotkey.unregister_hotkey(ID))
	assert(not GlobalHotkey.is_registered(ID))
	assert(not GlobalHotkey.unregister_hotkey(ID))
	pass


func global_hotkey_held_false_when_idle_test() -> void:
	const ID := 9004
	GlobalHotkey.unregister_all()
	assert(GlobalHotkey.register_hotkey(ID, KEY_F8, KEY_MASK_CTRL | KEY_MASK_ALT))
	assert(not GlobalHotkey.is_hotkey_held(ID))
	assert(GlobalHotkey.unregister_hotkey(ID))
	pass


func global_hotkey_replace_and_unregister_all_test() -> void:
	const ID_A := 9002
	const ID_B := 9003
	assert(GlobalHotkey.register_hotkey(ID_A, KEY_F10, KEY_MASK_CTRL | KEY_MASK_ALT))
	# Same id, different key — replace in place.
	assert(GlobalHotkey.register_hotkey(ID_A, KEY_F11, KEY_MASK_CTRL | KEY_MASK_ALT))
	assert(GlobalHotkey.register_hotkey(ID_B, KEY_F12, KEY_MASK_CTRL | KEY_MASK_SHIFT))
	assert(GlobalHotkey.is_registered(ID_A))
	assert(GlobalHotkey.is_registered(ID_B))

	GlobalHotkey.unregister_all()
	assert(not GlobalHotkey.is_registered(ID_A))
	assert(not GlobalHotkey.is_registered(ID_B))
	assert(GlobalHotkey.get_registered_ids().is_empty())
	pass


func global_hotkey_key_mapping_matches_godot_windows_test() -> void:
	# Inverse of Godot KeyMappingWindows::vk_map — physical VKs only.
	var supported: Array[int] = [
		KEY_BACKSPACE, KEY_TAB, KEY_CLEAR, KEY_ENTER, KEY_KP_ENTER,
		KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_PAUSE, KEY_CAPSLOCK, KEY_ESCAPE,
		KEY_SPACE, KEY_PAGEUP, KEY_PAGEDOWN, KEY_END, KEY_HOME,
		KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_PRINT, KEY_INSERT, KEY_DELETE, KEY_HELP,
		KEY_META, KEY_MENU, KEY_STANDBY,
		KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9,
		KEY_KP_MULTIPLY, KEY_KP_ADD, KEY_KP_SUBTRACT, KEY_KP_PERIOD, KEY_KP_DIVIDE,
		KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12,
		KEY_F13, KEY_F14, KEY_F15, KEY_F16, KEY_F17, KEY_F18, KEY_F19, KEY_F20, KEY_F21, KEY_F22, KEY_F23, KEY_F24,
		KEY_NUMLOCK, KEY_SCROLLLOCK,
		KEY_BACK, KEY_FORWARD, KEY_REFRESH, KEY_STOP, KEY_SEARCH, KEY_FAVORITES, KEY_HOMEPAGE,
		KEY_VOLUMEMUTE, KEY_VOLUMEDOWN, KEY_VOLUMEUP,
		KEY_MEDIANEXT, KEY_MEDIAPREVIOUS, KEY_MEDIASTOP, KEY_MEDIAPLAY,
		KEY_LAUNCHMAIL, KEY_LAUNCHMEDIA, KEY_LAUNCH0, KEY_LAUNCH1,
		KEY_SEMICOLON, KEY_EQUAL, KEY_COMMA, KEY_MINUS, KEY_PERIOD, KEY_SLASH, KEY_QUOTELEFT,
		KEY_BRACKETLEFT, KEY_BACKSLASH, KEY_BRACKETRIGHT, KEY_APOSTROPHE, KEY_BAR,
		KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
		KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I, KEY_J, KEY_K, KEY_L, KEY_M,
		KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T, KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z,
	]
	for key in supported:
		assert(GlobalHotkey.is_key_supported(key), "expected supported: %s" % key)

	# No Windows VK in Godot's vk_map (shifted glyphs, unused, platform-specific).
	var unsupported: Array[int] = [
		KEY_NONE, KEY_SPECIAL, KEY_UNKNOWN, KEY_BACKTAB, KEY_SYSREQ, KEY_HYPER,
		KEY_MEDIARECORD, KEY_OPENURL,
		KEY_LAUNCH2, KEY_LAUNCH3, KEY_LAUNCH4, KEY_LAUNCH5, KEY_LAUNCH6, KEY_LAUNCH7, KEY_LAUNCH8, KEY_LAUNCH9,
		KEY_LAUNCHA, KEY_LAUNCHB, KEY_LAUNCHC, KEY_LAUNCHD, KEY_LAUNCHE, KEY_LAUNCHF,
		KEY_GLOBE, KEY_KEYBOARD, KEY_JIS_EISU, KEY_JIS_KANA, KEY_SECTION,
		KEY_EXCLAM, KEY_QUOTEDBL, KEY_NUMBERSIGN, KEY_DOLLAR, KEY_PERCENT, KEY_AMPERSAND,
		KEY_PARENLEFT, KEY_PARENRIGHT, KEY_ASTERISK, KEY_PLUS, KEY_COLON, KEY_LESS, KEY_GREATER,
		KEY_QUESTION, KEY_AT, KEY_ASCIICIRCUM, KEY_UNDERSCORE, KEY_BRACELEFT, KEY_BRACERIGHT,
		KEY_ASCIITILDE, KEY_YEN, KEY_F25, KEY_F26, KEY_F27, KEY_F28, KEY_F29, KEY_F30,
		KEY_F31, KEY_F32, KEY_F33, KEY_F34, KEY_F35,
	]
	for key in unsupported:
		assert(not GlobalHotkey.is_key_supported(key), "expected unsupported: %s" % key)
	pass
