#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

/// Native OS helpers that work while the Godot window is unfocused.
///
/// Windows covers synthesizing Ctrl+V into the foreground app (`SendInput`),
/// and native file dragging.
///
/// GDScript example
/// ----------------
/// ```gdscript
/// DisplayServer.clipboard_set("hello")
/// NativeOS.paste_clipboard()
/// ```
class NativeOS : public Object {
	GDCLASS(NativeOS, Object)

public:
	static NativeOS *get_singleton();
	/// Allocate the singleton and register it with `Engine` as `"NativeOS"`.
	static void create_singleton();
	/// Unregister from `Engine` and free the singleton.
	static void destroy_singleton();

	/// Synthesize Ctrl+V into the foreground window (Windows `SendInput`).
	/// Call after putting text on the clipboard so another app can receive a paste while Godot is unfocused.
	void paste_clipboard();
	/// Windows DWM immersive dark title bar ([param dark_mode]). Returns [code]false[/code] off Windows or when HWND is missing.
	bool apply_title_bar_dark_mode(int window_id, bool dark_mode);
	/// Start a native Windows OLE file drag and block until the user drops or cancels it.
	/// The paths are exposed as CF_HDROP, so Godot windows receive them through files_dropped.
	bool drag_files(const PackedStringArray &paths) const;

protected:
	static void _bind_methods();

private:
	static NativeOS *singleton;
};
