extends RefCounted


class ShortcutTestHost extends EditorShortcuts.Host:
	var saves: Array[int] = [0]
	var save_alls: Array[int] = [0]
	var closes: Array[int] = [0]
	var tab_direction: Array[int] = [0]
	var deletes: Array[int] = [0]
	var delete_enabled: bool = false
	var blocked: bool = false

	func is_input_blocked() -> bool:
		return blocked

	func can_delete_selection() -> bool:
		return delete_enabled

	func save_active() -> void:
		saves[0] += 1
		pass

	func save_all() -> void:
		save_alls[0] += 1
		pass

	func close_active_tab() -> void:
		closes[0] += 1
		pass

	func switch_tab(direction: int) -> void:
		tab_direction[0] = direction
		pass

	func delete_selection() -> void:
		deletes[0] += 1
		pass


static func editor_shortcuts_chords_test() -> void:
	var ctrl_s := key_event(KEY_S, true, false, false, false)
	var meta_s := key_event(KEY_S, false, false, false, true)
	var ctrl_shift_s := key_event(KEY_S, true, true, false, false)
	var ctrl_w := key_event(KEY_W, true, false, false, false)
	var ctrl_tab := key_event(KEY_TAB, true, false, false, false)
	var ctrl_shift_tab := key_event(KEY_TAB, true, true, false, false)
	assert(EditorShortcuts.matches_save_active(ctrl_s))
	assert(EditorShortcuts.matches_save_active(meta_s))
	assert(not EditorShortcuts.matches_save_active(ctrl_shift_s))
	assert(EditorShortcuts.matches_save_all(ctrl_shift_s))
	assert(not EditorShortcuts.matches_save_all(ctrl_s))
	assert(EditorShortcuts.matches_close_tab(ctrl_w))
	assert(EditorShortcuts.matches_next_tab(ctrl_tab))
	assert(EditorShortcuts.matches_prev_tab(ctrl_shift_tab))
	assert(not EditorShortcuts.matches_next_tab(ctrl_shift_tab))
	var delete_key := key_event(KEY_DELETE, false, false, false, false)
	assert(EditorShortcuts.matches_delete(delete_key))
	assert(not EditorShortcuts.matches_delete(key_event(KEY_DELETE, true, false, false, false)))
	pass


static func editor_shortcuts_handle_input_test() -> void:
	var host := ShortcutTestHost.new()
	assert(not EditorShortcuts.handle_input(key_event(KEY_DELETE, false, false, false, false), host))
	host.delete_enabled = true
	assert(EditorShortcuts.handle_input(key_event(KEY_DELETE, false, false, false, false), host))
	assert(host.deletes[0] == 1)
	assert(EditorShortcuts.handle_input(key_event(KEY_S, true, false, false, false), host))
	assert(host.saves[0] == 1)
	assert(EditorShortcuts.handle_input(key_event(KEY_S, true, true, false, false), host))
	assert(host.save_alls[0] == 1)
	assert(EditorShortcuts.handle_input(key_event(KEY_W, true, false, false, false), host))
	assert(host.closes[0] == 1)
	assert(EditorShortcuts.handle_input(key_event(KEY_TAB, true, false, false, false), host))
	assert(host.tab_direction[0] == 1)
	assert(EditorShortcuts.handle_input(key_event(KEY_TAB, true, true, false, false), host))
	assert(host.tab_direction[0] == -1)

	host.blocked = true
	assert(not EditorShortcuts.handle_input(key_event(KEY_S, true, false, false, false), host))
	assert(host.saves[0] == 1)
	pass


static func key_event(keycode: Key, ctrl: bool, shift: bool, alt: bool, meta_key: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	key.physical_keycode = keycode
	key.ctrl_pressed = ctrl
	key.shift_pressed = shift
	key.alt_pressed = alt
	key.meta_pressed = meta_key
	return key
