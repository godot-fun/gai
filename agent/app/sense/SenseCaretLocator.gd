## Locates a one-shot DisplayServer screen point for Sense input UI (Godot caret / OS caret / screen center).
class_name SenseCaretLocator
extends RefCounted

## Drop OS caret hits glued to a screen's left edge (common UIA / Win32 glitch).
const OS_CARET_LEFT_MARGIN := 48


## Godot caret / mouse when a Godot window is focused; else OS caret / focused-screen center when background.
## Never uses OS caret while Godot is foreground (UIA/Win32 often lands on the wrong monitor).
static func resolve_anchor() -> Vector2i:
	var godot_anchor: Variant = godot_focus_anchor()
	if godot_anchor != null:
		return godot_anchor as Vector2i
	# Background only: [method query_os_caret] already rejects implausible UIA/Win32 hits.
	var os_caret := query_os_caret()
	if os_caret != Vector2i.ZERO:
		return os_caret
	return focused_screen_center()


## All Godot-side focus: focused [Window] (main / embedded popup / native subwindow) → that
## window's [TextEdit]/[CodeEdit] caret in DisplayServer screen space (multi-monitor + stretch
## via [method Viewport.get_final_transform] + [method DisplayServer.window_get_position], not
## [method CanvasItem.get_screen_transform]), else mouse.
## Returns [code]null[/code] when no Godot window has focus (app in background).
static func godot_focus_anchor() -> Variant:
	var window := Window.get_focused_window()
	if window == null:
		return null
	var focus: Control = window.gui_get_focus_owner()
	if not (focus is TextEdit):
		return DisplayServer.mouse_get_position()
	var text_edit := focus as TextEdit
	var viewport: Viewport = text_edit.get_viewport()
	if viewport == null:
		return DisplayServer.mouse_get_position()
	# Prefer window origin + final transform over get_screen_transform (native Window mismatch).
	var canvas_pos: Vector2 = text_edit.get_global_transform_with_canvas() * text_edit.get_caret_draw_pos()
	var window_pos: Vector2 = viewport.get_final_transform() * canvas_pos
	var origin: Vector2i = DisplayServer.window_get_position(viewport.get_window_id())
	return origin + Vector2i(roundi(window_pos.x), roundi(window_pos.y))


## Win32 / UIA caret via [code]NativeOS[/code], with plausibility checks inlined (former
## [code]is_plausible_os_caret[/code]). Returns [code]Vector2i.ZERO[/code] when NativeOS is missing,
## the caret is null, or the hit fails any of:
## - not inside any usable screen rect
## - glued to a screen's left edge within [constant OS_CARET_LEFT_MARGIN] (common UIA/Win32 glitch)
## - farther from the mouse than half that screen's longer side (wrong-monitor / stale caret)
static func query_os_caret() -> Vector2i:
	if not Engine.has_singleton("NativeOS"):
		return Vector2i.ZERO
	var caret: Variant = NativeOS.get_caret_screen_position()
	if caret == null:
		return Vector2i.ZERO
	var pos := caret as Vector2i
	var mouse := DisplayServer.mouse_get_position()
	for screen_i in DisplayServer.get_screen_count():
		var rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_i)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		if not rect.has_point(pos):
			continue
		# Left-edge glitch: UIA often reports (0, y)-ish on the wrong monitor.
		if pos.x < rect.position.x + OS_CARET_LEFT_MARGIN:
			return Vector2i.ZERO
		# Too far from the pointer → likely stale or cross-monitor noise.
		if Vector2(pos).distance_to(Vector2(mouse)) > maxf(rect.size.x, rect.size.y) * 0.5:
			return Vector2i.ZERO
		return pos
	return Vector2i.ZERO


## Fallback when neither Godot caret nor a plausible OS caret is available: center of the
## usable rect of the screen under the mouse (mouse itself if that rect is empty).
static func focused_screen_center() -> Vector2i:
	var mouse := DisplayServer.mouse_get_position()
	var screen := DisplayServer.get_screen_from_rect(Rect2(Vector2(mouse), Vector2.ONE))
	var rect: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return mouse
	return rect.position + rect.size / 2
