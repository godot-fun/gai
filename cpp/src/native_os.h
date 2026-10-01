#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

/// Native OS helpers that work while the Godot window is unfocused.
///
/// Windows covers synthesizing Ctrl+V into the foreground app (`SendInput`),
/// remembering / restoring the foreground window (for brief Godot focus steals),
/// querying the foreground text caret (`GetGUIThreadInfo`, then UI Automation),
/// and capturing the physical monitor under the mouse cursor to a PNG file.
///
/// GDScript example
/// ----------------
/// ```gdscript
/// NativeOS.remember_foreground_window()
/// # … briefly focus a Godot Window for keyboard input …
/// NativeOS.restore_foreground_window()
/// DisplayServer.clipboard_set("hello")
/// NativeOS.paste_clipboard()
/// var caret: Variant = NativeOS.get_caret_screen_position()
/// var ok: bool = NativeOS.capture_screen("user://sense/screen.png")
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
	/// Store the current foreground HWND for a later [method restore_foreground_window].
	/// Returns [code]true[/code] when a valid window was remembered. Windows only.
	bool remember_foreground_window();
	/// Activate the HWND from [method remember_foreground_window] and clear it.
	/// Call from the process that currently owns focus (e.g. after a picker Window
	/// steals activation) so paste / typing returns to the target app.
	/// Returns [code]true[/code] when restore succeeded. Windows only.
	bool restore_foreground_window();
	/// Screen position of the foreground text caret, in the same space as
	/// [code]DisplayServer.mouse_get_position()[/code]. Tries Win32
	/// [code]GetGUIThreadInfo[/code] first, then UI Automation
	/// ([code]TextPattern2.GetCaretRange[/code] / selection). Returns [code]null[/code]
	/// when unavailable (some apps never expose a caret).
	Variant get_caret_screen_position() const;
	/// Capture the full physical monitor under the mouse cursor and save it as PNG at
	/// [param path] ([code]user://[/code] / absolute / etc. via [code]FileAccess[/code]).
	/// Does not hide Godot overlays. Returns [code]true[/code] on success.
	/// Windows only; other platforms return [code]false[/code].
	bool capture_screen(const String &path) const;

protected:
	static void _bind_methods();

private:
	static NativeOS *singleton;
#ifdef _WIN32
	/// HWND from the last successful [method remember_foreground_window]; cleared on restore.
	void *remembered_foreground = nullptr;
#endif
};
