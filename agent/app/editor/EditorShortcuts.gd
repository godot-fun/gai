class_name EditorShortcuts
extends Object

## Editor window chords and [Binding] to the editor scene root. Tests subclass [Host].


class Host extends RefCounted:
	func is_input_blocked() -> bool:
		return false

	func can_delete_selection() -> bool:
		return false

	func can_paste_selection() -> bool:
		return false

	func can_copy_selection() -> bool:
		return false

	func save_active() -> void:
		pass

	func save_all() -> void:
		pass

	func close_active_tab() -> void:
		pass

	func switch_tab(direction: int) -> void:
		pass

	func delete_selection() -> void:
		pass

	func paste_selection() -> void:
		pass

	func copy_selection() -> void:
		pass


class Binding extends Host:
	var editor: Node

	func is_input_blocked() -> bool:
		return editor.confirm != null and editor.confirm.visible

	func can_delete_selection() -> bool:
		return editor.file_tree.has_focus()

	func can_paste_selection() -> bool:
		return editor.file_tree.has_focus() and editor.file_tree.can_paste()

	func can_copy_selection() -> bool:
		return editor.file_tree.has_focus()

	func save_active() -> void:
		editor.save_active_from_shortcut()
		pass

	func save_all() -> void:
		editor.save_all_from_shortcut()
		pass

	func close_active_tab() -> void:
		editor.close_active_from_shortcut()
		pass

	func switch_tab(direction: int) -> void:
		editor.switch_tab(direction)
		pass

	func delete_selection() -> void:
		editor.file_tree.delete_selected()
		pass

	func paste_selection() -> void:
		editor.file_tree.paste_selected()
		pass

	func copy_selection() -> void:
		editor.file_tree.copy_selected()
		pass


static func bind_editor(editor_root: Node) -> Host:
	var host := Binding.new()
	host.editor = editor_root
	return host


static func handle_input(event: InputEvent, host: Host) -> bool:
	if host.is_input_blocked():
		return false
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	if matches_save_active(key):
		host.save_active()
		return true
	if matches_save_all(key):
		host.save_all()
		return true
	if matches_close_tab(key):
		host.close_active_tab()
		return true
	if matches_next_tab(key):
		host.switch_tab(1)
		return true
	if matches_prev_tab(key):
		host.switch_tab(-1)
		return true
	if matches_delete(key) and host.can_delete_selection():
		host.delete_selection()
		return true
	if matches_copy(key) and host.can_copy_selection():
		host.copy_selection()
		return true
	if matches_paste(key) and host.can_paste_selection():
		host.paste_selection()
		return true
	return false


static func chord_modifiers_ok(key: InputEventKey) -> bool:
	return key.ctrl_pressed or key.meta_pressed


static func matches_save_active(key: InputEventKey) -> bool:
	if key.alt_pressed or key.shift_pressed or not chord_modifiers_ok(key):
		return false
	return key.keycode == KEY_S


static func matches_save_all(key: InputEventKey) -> bool:
	if key.alt_pressed or not key.shift_pressed or not chord_modifiers_ok(key):
		return false
	return key.keycode == KEY_S


static func matches_close_tab(key: InputEventKey) -> bool:
	if key.alt_pressed or key.shift_pressed or not chord_modifiers_ok(key):
		return false
	return key.keycode == KEY_W


static func matches_next_tab(key: InputEventKey) -> bool:
	if key.alt_pressed or key.shift_pressed or not chord_modifiers_ok(key):
		return false
	return key.keycode == KEY_TAB


static func matches_prev_tab(key: InputEventKey) -> bool:
	if key.alt_pressed or not key.shift_pressed or not chord_modifiers_ok(key):
		return false
	return key.keycode == KEY_TAB


## Delete selected workspace file when the file tree has focus.
static func matches_delete(key: InputEventKey) -> bool:
	if key.alt_pressed or key.ctrl_pressed or key.meta_pressed or key.shift_pressed:
		return false
	return primary_keycode(key) == KEY_DELETE


## Copy the selected workspace file or directory when the file tree has focus.
static func matches_copy(key: InputEventKey) -> bool:
	if key.alt_pressed or key.shift_pressed or not chord_modifiers_ok(key):
		return false
	return primary_keycode(key) == KEY_C


## Paste the copied workspace file or directory when the file tree has focus.
static func matches_paste(key: InputEventKey) -> bool:
	if key.alt_pressed or key.shift_pressed or not chord_modifiers_ok(key):
		return false
	return primary_keycode(key) == KEY_V


static func primary_keycode(key: InputEventKey) -> Key:
	if key.keycode != KEY_NONE:
		return key.keycode
	return key.physical_keycode
