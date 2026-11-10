## Unit tests for [ScreenUtils]. Loaded with the other scripts in this folder by [code]test/utils/UtilsTest.tscn[/code].

## Point and rectangle lookups report the screen that holds them, and -1 when no screen does.
func ScreenUtils_screen_lookup_test() -> void:
	var count: int = DisplayServer.get_screen_count()
	# -1 is the "no screen" answer, which is all a headless run has.
	assert(ScreenUtils.active_screen() <= count - 1)
	assert(ScreenUtils.window_screen() <= count - 1)
	if count == 0:
		assert(ScreenUtils.screen_at(Vector2i.ZERO) == -1)
		return
	assert(ScreenUtils.window_screen() >= 0)
	assert(ScreenUtils.active_screen() >= 0)
	var origin: Vector2i = DisplayServer.screen_get_position(0)
	assert(ScreenUtils.screen_at(origin + Vector2i(1, 1)) == 0)
	assert(ScreenUtils.screen_of_rect(Rect2i(origin, Vector2i(8, 8))) == 0)
	assert(ScreenUtils.screen_at(Vector2i(-999999, -999999)) == -1)
	pass


## The usable rect is the display server's own, for an explicit screen and for the active one.
func ScreenUtils_usable_rect_test() -> void:
	if DisplayServer.get_screen_count() == 0:
		assert(ScreenUtils.usable_rect() == Rect2i())
		assert(ScreenUtils.usable_rect(0) == Rect2i())
		return
	assert(ScreenUtils.usable_rect() == DisplayServer.screen_get_usable_rect(ScreenUtils.active_screen()))
	assert(ScreenUtils.usable_rect(0) == DisplayServer.screen_get_usable_rect(0))
	pass


## Clamping leaves a window inside the usable area, and keeps the low edge reachable when it is bigger.
func ScreenUtils_clamp_rect_to_usable_test() -> void:
	var toast_size := Vector2i(300, 200)
	var margin := 16
	if DisplayServer.get_screen_count() == 0:
		# No screens: the usable area is empty, so the low edge wins instead of inverting the range.
		assert(ScreenUtils.clamp_rect_to_usable(Vector2i(500, 400), toast_size, margin, 0) == Vector2i(margin, margin))
		return
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(0)
	var free_spot: Vector2i = usable.position + Vector2i(50, 60)
	assert(ScreenUtils.clamp_rect_to_usable(free_spot, toast_size, margin, 0) == free_spot)
	assert(ScreenUtils.clamp_rect_to_usable(usable.end + Vector2i(5000, 5000), toast_size, margin, 0) == usable.end - toast_size - Vector2i(margin, margin))
	assert(ScreenUtils.clamp_rect_to_usable(usable.end, usable.size + Vector2i(400, 400), margin, 0) == usable.position + Vector2i(margin, margin))
	pass
