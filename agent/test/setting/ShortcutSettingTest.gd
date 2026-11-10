extends RefCounted


static func default_search_shortcut_test() -> void:
	var ctrl_f: Key = KEY_F | KEY_MASK_CTRL
	assert(ShortcutSetting.DEFAULT_SEARCH_SHORTCUT == ctrl_f)
	assert(OS.get_keycode_string(ctrl_f) == "Ctrl+F")
	var ctrl_page_up: Key = KEY_PAGEUP | KEY_MASK_CTRL
	var ctrl_page_down: Key = KEY_PAGEDOWN | KEY_MASK_CTRL
	assert(ShortcutSetting.DEFAULT_PREV_USER_MESSAGE_SHORTCUT == ctrl_page_up)
	assert(ShortcutSetting.DEFAULT_NEXT_USER_MESSAGE_SHORTCUT == ctrl_page_down)
	var ctrl_shift_page_up: Key = KEY_PAGEUP | KEY_MASK_SHIFT | KEY_MASK_CTRL
	var ctrl_shift_page_down: Key = KEY_PAGEDOWN | KEY_MASK_SHIFT | KEY_MASK_CTRL
	assert(ShortcutSetting.DEFAULT_PREV_REPLY_SHORTCUT == ctrl_shift_page_up)
	assert(ShortcutSetting.DEFAULT_NEXT_REPLY_SHORTCUT == ctrl_shift_page_down)
	pass


static func is_search_shortcut_valid_test() -> void:
	var ctrl_f: Key = KEY_F | KEY_MASK_CTRL
	assert(ShortcutSetting.is_search_shortcut_valid(ctrl_f))
	assert(ShortcutSetting.is_search_shortcut_valid(KEY_K | KEY_MASK_ALT | KEY_MASK_SHIFT))
	assert(not ShortcutSetting.is_search_shortcut_valid(KEY_F))
	assert(not ShortcutSetting.is_search_shortcut_valid(KEY_NONE))
	assert(not ShortcutSetting.is_search_shortcut_valid(KEY_CTRL | KEY_MASK_CTRL))
	assert(not ShortcutSetting.is_search_shortcut_valid(KEY_SHIFT | KEY_MASK_SHIFT))
	pass


static func make_shortcut_event_test() -> void:
	var ctrl_shift_f := ShortcutSetting.make_shortcut_event(KEY_F | KEY_MASK_CTRL | KEY_MASK_SHIFT)
	assert(ctrl_shift_f.keycode == KEY_F)
	assert(ctrl_shift_f.ctrl_pressed)
	assert(ctrl_shift_f.shift_pressed)
	assert(not ctrl_shift_f.alt_pressed)
	assert(not ctrl_shift_f.meta_pressed)
	var alt_meta_s := ShortcutSetting.make_shortcut_event(KEY_S | KEY_MASK_ALT | KEY_MASK_META)
	assert(alt_meta_s.keycode == KEY_S)
	assert(alt_meta_s.alt_pressed)
	assert(alt_meta_s.meta_pressed)
	assert(not alt_meta_s.ctrl_pressed)
	pass


static func make_search_shortcut_test() -> void:
	var shortcut := ShortcutSetting.make_search_shortcut()
	assert(shortcut.events.size() == 1)
	var event := shortcut.events[0] as InputEventKey
	assert(event != null)
	var expected := ShortcutSetting.make_shortcut_event(ShortcutSetting.get_search_shortcut())
	assert(event.keycode == expected.keycode)
	assert(event.ctrl_pressed == expected.ctrl_pressed)
	assert(event.alt_pressed == expected.alt_pressed)
	assert(event.shift_pressed == expected.shift_pressed)
	assert(event.meta_pressed == expected.meta_pressed)
	pass


static func set_search_shortcut_test() -> void:
	var previous: Key = ShortcutSetting.get_search_shortcut()
	var candidates: Array[Key] = [
		KEY_K | KEY_MASK_CTRL | KEY_MASK_SHIFT,
		KEY_J | KEY_MASK_CTRL | KEY_MASK_ALT,
		KEY_P | KEY_MASK_CTRL | KEY_MASK_META,
	]
	var new_key: Key = KEY_NONE
	for candidate in candidates:
		if candidate != previous:
			new_key = candidate
			break
	assert(new_key != KEY_NONE)
	var emit_count: Array[int] = [0]
	var on_changed := func() -> void: emit_count[0] += 1
	AgentEvents.events.search_shortcut_changed.connect(on_changed)
	ShortcutSetting.set_search_shortcut(new_key)
	assert(ShortcutSetting.get_search_shortcut() == new_key)
	assert(emit_count[0] == 1)
	ShortcutSetting.set_search_shortcut(previous)
	assert(ShortcutSetting.get_search_shortcut() == previous)
	assert(emit_count[0] == 2)
	AgentEvents.events.search_shortcut_changed.disconnect(on_changed)
	pass


static func set_prev_user_message_shortcut_test() -> void:
	var previous: Key = ShortcutSetting.get_prev_user_message_shortcut()
	var new_key: Key = KEY_U | KEY_MASK_CTRL | KEY_MASK_SHIFT
	var emit_count: Array[int] = [0]
	var on_changed := func() -> void: emit_count[0] += 1
	AgentEvents.events.prev_user_message_shortcut_changed.connect(on_changed)
	ShortcutSetting.set_prev_user_message_shortcut(new_key)
	assert(ShortcutSetting.get_prev_user_message_shortcut() == new_key)
	assert(emit_count[0] == 1)
	ShortcutSetting.set_prev_user_message_shortcut(previous)
	assert(emit_count[0] == 2)
	AgentEvents.events.prev_user_message_shortcut_changed.disconnect(on_changed)
	pass


static func set_next_user_message_shortcut_test() -> void:
	var previous: Key = ShortcutSetting.get_next_user_message_shortcut()
	var new_key: Key = KEY_J | KEY_MASK_CTRL | KEY_MASK_SHIFT
	var emit_count: Array[int] = [0]
	var on_changed := func() -> void: emit_count[0] += 1
	AgentEvents.events.next_user_message_shortcut_changed.connect(on_changed)
	ShortcutSetting.set_next_user_message_shortcut(new_key)
	assert(ShortcutSetting.get_next_user_message_shortcut() == new_key)
	assert(emit_count[0] == 1)
	ShortcutSetting.set_next_user_message_shortcut(previous)
	assert(emit_count[0] == 2)
	AgentEvents.events.next_user_message_shortcut_changed.disconnect(on_changed)
	pass


static func set_prev_reply_shortcut_test() -> void:
	var previous: Key = ShortcutSetting.get_prev_reply_shortcut()
	var new_key: Key = KEY_R | KEY_MASK_CTRL | KEY_MASK_SHIFT
	var emit_count: Array[int] = [0]
	var on_changed := func() -> void: emit_count[0] += 1
	AgentEvents.events.prev_reply_shortcut_changed.connect(on_changed)
	ShortcutSetting.set_prev_reply_shortcut(new_key)
	assert(ShortcutSetting.get_prev_reply_shortcut() == new_key)
	assert(emit_count[0] == 1)
	ShortcutSetting.set_prev_reply_shortcut(previous)
	assert(emit_count[0] == 2)
	AgentEvents.events.prev_reply_shortcut_changed.disconnect(on_changed)
	pass


static func set_next_reply_shortcut_test() -> void:
	var previous: Key = ShortcutSetting.get_next_reply_shortcut()
	var new_key: Key = KEY_T | KEY_MASK_CTRL | KEY_MASK_SHIFT
	var emit_count: Array[int] = [0]
	var on_changed := func() -> void: emit_count[0] += 1
	AgentEvents.events.next_reply_shortcut_changed.connect(on_changed)
	ShortcutSetting.set_next_reply_shortcut(new_key)
	assert(ShortcutSetting.get_next_reply_shortcut() == new_key)
	assert(emit_count[0] == 1)
	ShortcutSetting.set_next_reply_shortcut(previous)
	assert(emit_count[0] == 2)
	AgentEvents.events.next_reply_shortcut_changed.disconnect(on_changed)
	pass
