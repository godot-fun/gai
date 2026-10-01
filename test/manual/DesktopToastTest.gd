extends Node

## Manual shortcut: Ctrl + Windows (Meta) + Alt shows a [DesktopToast].


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var code: Key = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	if code != KEY_CTRL and code != KEY_ALT and code != KEY_META:
		return
	# Event modifier flags stay false for the key being pressed itself; query Input state instead.
	if not (Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_ALT) and Input.is_key_pressed(KEY_META)):
		return
	DesktopToast.show_toast("DesktopToast", "Ctrl+Win+Alt manual test", ColorBase.success)
	get_viewport().set_input_as_handled()
	pass
