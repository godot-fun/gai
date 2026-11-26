## Unit tests for NativeOS paste and window helpers.
extends RefCounted


static func native_file_drag_rejects_empty_paths_test() -> void:
	assert(not NativeOS.drag_files(PackedStringArray()))
	pass


func native_os_apply_title_bar_dark_mode_smoke_test() -> void:
	var ok: bool = NativeOS.apply_title_bar_dark_mode(0, true)
	if OS.get_name() != "Windows":
		assert(not ok)
		return
	assert(typeof(ok) == TYPE_BOOL)
	pass
