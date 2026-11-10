class_name ScreenUtils
extends Object

## Monitor geometry on top of [DisplayServer] — which screen a point, a rectangle, a window or the
## user belongs to, and where the usable (taskbar-free) area of a screen sits.
##
## Two ideas are kept apart on purpose, because mixing them up puts UI on the wrong monitor:
## [method window_screen] is the monitor hosting a window (use it for window-relative geometry and
## scale), while [method active_screen] is the monitor the user is working on (use it to decide
## where a new toast, popup or menu should appear).


## Screen containing [param point] in global screen coordinates, or -1 when no screen does.
## Coordinates are global, so screens left of or above the primary one report negative values.
static func screen_at(point: Vector2i) -> int:
	# A zero-size rect overlaps no screen and reports -1, so probe the point as a single pixel.
	return DisplayServer.get_screen_from_rect(Rect2(Vector2(point), Vector2.ONE))


## Screen holding the largest part of [param rect] in global screen coordinates, or -1 when the
## rectangle overlaps no screen.
static func screen_of_rect(rect: Rect2i) -> int:
	return DisplayServer.get_screen_from_rect(Rect2(Vector2(rect.position), Vector2(maxi(1, rect.size.x), maxi(1, rect.size.y))))


## Screen hosting [param window_id] (the main window by default) — the monitor whose usable area and
## scale a window-relative decision belongs to.
static func window_screen(window_id: int = DisplayServer.MAIN_WINDOW_ID) -> int:
	return DisplayServer.window_get_current_screen(window_id)


## Screen the user is currently working on: the monitor under the pointer. It falls back to
## [method window_screen] when the pointer sits on no screen, e.g. a headless run.
static func active_screen() -> int:
	var screen := screen_at(DisplayServer.mouse_get_position())
	return screen if screen >= 0 else window_screen()


## Usable area of [param screen] — the screen minus docked bars such as the Windows taskbar.
## [param screen] below zero means [method active_screen]. Returns an empty rect when there is no such
## screen, which is also what a headless run reports, so callers that divide by its size keep their
## own guard.
static func usable_rect(screen: int = -1) -> Rect2i:
	var target := active_screen() if screen < 0 else screen
	return DisplayServer.screen_get_usable_rect(target) if target >= 0 else Rect2i()


## True while [param window_id] covers the usable area of its screen — either maximized, or minimized
## from maximized, where Godot drops the maximized flag and the cached size is all that is left.
static func window_covers_usable(window_id: int = DisplayServer.MAIN_WINDOW_ID) -> bool:
	var window_size := Vector2(DisplayServer.window_get_size_with_decorations(window_id))
	var usable_size := Vector2(usable_rect(window_screen(window_id)).size)
	return window_size.x >= usable_size.x and window_size.y >= usable_size.y


## Clamp a window of [param size] into the usable area of [param screen] (below zero means
## [method active_screen]), keeping [param margin] away from its edges. When the window is larger than
## the usable area the low edge wins, so the top-left corner stays reachable.
static func clamp_rect_to_usable(position: Vector2i, size: Vector2i, margin: int, screen: int = -1) -> Vector2i:
	var usable := usable_rect(screen)
	var x := clamp_axis(position.x, usable.position.x + margin, usable.end.x - size.x - margin)
	var y := clamp_axis(position.y, usable.position.y + margin, usable.end.y - size.y - margin)
	return Vector2i(x, y)


## [method clampi] that tolerates an inverted range, which [method clamp_rect_to_usable] produces for
## a window bigger than the usable area.
static func clamp_axis(value: int, low: int, high: int) -> int:
	return clampi(value, low, maxi(low, high))
