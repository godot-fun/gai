## Unit tests for NativeOS paste / caret / screen-capture helpers.
extends RefCounted


func native_os_caret_screen_position_smoke_test() -> void:
	# Headless / no focused caret → null; a real caret yields Vector2i. Either is fine.
	var caret: Variant = NativeOS.get_caret_screen_position()
	assert(caret == null or typeof(caret) == TYPE_VECTOR2I)
	pass


func native_os_foreground_remember_restore_smoke_test() -> void:
	var remembered := NativeOS.remember_foreground_window()
	var restored := NativeOS.restore_foreground_window()
	if OS.get_name() != "Windows":
		assert(not remembered)
		assert(not restored)
		return
	# Headless may lack a usable foreground HWND; both paths must stay bool-safe.
	assert(typeof(remembered) == TYPE_BOOL)
	assert(typeof(restored) == TYPE_BOOL)
	# Restore with nothing remembered must fail cleanly.
	assert(not NativeOS.restore_foreground_window())
	pass


func native_os_capture_screen_test() -> void:
	var path := OS.get_user_data_dir().path_join("native_os_capture_smoke.png")
	var ok := NativeOS.capture_screen(path)
	if OS.get_name() != "Windows":
		assert(not ok)
		return
	assert(ok)
	var img := Image.load_from_file(path)
	assert(img != null and not img.is_empty())
	assert(img.get_width() > 0 and img.get_height() > 0)
	pass
