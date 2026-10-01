## Unit tests for [DesktopToast]. Loaded with the other scripts in this folder by [code]test/feedback/FeedbackTest.tscn[/code] ([UnitTest]).

## [method DesktopToast.corner_position] pins the toast to the bottom-right of the usable screen area.
func DesktopToast_corner_position_test() -> void:
	var toast_size: Vector2i = Vector2i(roundi(DesktopToast.CARD_WIDTH), 120)
	var corner: Vector2i = DesktopToast.corner_position(toast_size)
	var screen: int = DisplayServer.window_get_current_screen(DisplayServer.MAIN_WINDOW_ID)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var margin: int = roundi(Margin.ma_6 * DisplayScale.compute_ui_scale())
	assert(corner.x == usable.position.x + usable.size.x - toast_size.x - margin)
	assert(corner.y == usable.position.y + usable.size.y - toast_size.y - margin)
	pass


## Every global [enum Corner] pins the toast inside the matching usable-screen corner.
func DesktopToast_all_corner_positions_test() -> void:
	var toast_size: Vector2i = Vector2i(roundi(DesktopToast.CARD_WIDTH), 120)
	var screen: int = DisplayServer.window_get_current_screen(DisplayServer.MAIN_WINDOW_ID)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var margin: int = roundi(Margin.ma_6 * DisplayScale.compute_ui_scale())
	var top_left: Vector2i = DesktopToast.corner_position(toast_size, Corner.CORNER_TOP_LEFT)
	var top_right: Vector2i = DesktopToast.corner_position(toast_size, Corner.CORNER_TOP_RIGHT)
	var bottom_left: Vector2i = DesktopToast.corner_position(toast_size, Corner.CORNER_BOTTOM_LEFT)
	var bottom_right: Vector2i = DesktopToast.corner_position(toast_size, Corner.CORNER_BOTTOM_RIGHT)
	assert(top_left == Vector2i(usable.position.x + margin, usable.position.y + margin))
	assert(top_right == Vector2i(usable.end.x - toast_size.x - margin, usable.position.y + margin))
	assert(bottom_left == Vector2i(usable.position.x + margin, usable.end.y - toast_size.y - margin))
	assert(bottom_right == Vector2i(usable.end.x - toast_size.x - margin, usable.end.y - toast_size.y - margin))
	pass


## [method DesktopToast.build_card] lays out the accent stripe, title and wrapped body at the app UI scale.
func DesktopToast_build_card_test() -> void:
	var scale := DisplayScale.compute_ui_scale()
	var toast: DesktopToast = DesktopToast.new()
	toast.title_text = "feedback toast"
	toast.body_text = "feedback toast body"
	toast.accent = ColorBase.success
	toast.build_card()
	assert(toast.card != null)
	assert(toast.size.x == roundi(DesktopToast.CARD_WIDTH * scale))
	assert(toast.position == DesktopToast.corner_position(toast.size))
	var column: VBoxContainer = toast.card.get_child(0) as VBoxContainer
	var title_label: Label = column.get_child(0) as Label
	assert(title_label.text == "feedback toast")
	assert(title_label.get_theme_font_size("font_size") == roundi(Typography.title_medium_size * scale))
	assert(toast.body_label != null)
	assert(toast.body_label.text == "feedback toast body")
	assert(toast.body_label.max_lines_visible == DesktopToast.MAX_BODY_LINES)
	var style: StyleBoxFlat = toast.card.get_theme_stylebox("panel") as StyleBoxFlat
	assert(style.border_color == ColorBase.success)
	assert(style.border_width_left == roundi(ControlSize.border_md * scale))
	assert(style.bg_color == ThemeColor.accent_surface)
	toast.free()
	pass


## A toast without a body skips the body label, so the card only holds the title.
func DesktopToast_empty_body_test() -> void:
	var toast: DesktopToast = DesktopToast.new()
	toast.title_text = "feedback toast"
	toast.body_text = "   "
	toast.build_card()
	assert(toast.body_label == null)
	assert((toast.card.get_child(0) as VBoxContainer).get_child_count() == 1)
	toast.free()
	pass


## Toast title and body are translated before the native window is mounted.
func DesktopToast_i18n_text_test() -> void:
	var translation := feedback_test_translation("feedback.toast.title", "Translated toast")
	translation.add_message("feedback.toast.body", "Translated body")
	var before := DesktopToast.toasts.size()
	DesktopToast.show_toast("feedback.toast.title", "feedback.toast.body", ColorBase.success)
	var toast := DesktopToast.toasts[before]
	assert(toast.title_text == "Translated toast")
	assert(toast.body_text == "Translated body")
	toast.close_toast()
	TranslationServer.remove_translation(translation)
	pass


## [method DesktopToast.relayout] stacks live toasts upward from the screen corner, newest last.
func DesktopToast_relayout_test() -> void:
	var gap := roundi(Margin.ma_3 * DisplayScale.compute_ui_scale())
	var live: Array = DesktopToast.toasts.duplicate()
	DesktopToast.toasts.clear()
	var older: DesktopToast = DesktopToast.new()
	older.size = Vector2i(400, 100)
	var newer: DesktopToast = DesktopToast.new()
	newer.size = Vector2i(400, 100)
	var top_left_older: DesktopToast = DesktopToast.new()
	top_left_older.size = Vector2i(400, 100)
	top_left_older.toast_corner = Corner.CORNER_TOP_LEFT
	var top_left_newer: DesktopToast = DesktopToast.new()
	top_left_newer.size = Vector2i(400, 100)
	top_left_newer.toast_corner = Corner.CORNER_TOP_LEFT
	DesktopToast.toasts.append_array([older, newer, top_left_older, top_left_newer])
	DesktopToast.relayout()
	assert(newer.position.y == DesktopToast.corner_position(newer.size).y)
	assert(older.position.y == newer.position.y - newer.size.y - gap)
	assert(top_left_newer.position == DesktopToast.corner_position(top_left_newer.size, Corner.CORNER_TOP_LEFT))
	assert(top_left_older.position.y == top_left_newer.position.y + top_left_newer.size.y + gap)
	older.free()
	newer.free()
	top_left_older.free()
	top_left_newer.free()
	# Other scenes may still own live toasts; leave the stack as it was.
	DesktopToast.toasts.clear()
	DesktopToast.toasts.append_array(live)
	pass


## [method DesktopToast.show_toast] mounts the toast window, [method DesktopToast.close_toast] retires it.
func DesktopToast_show_toast_test() -> void:
	var before: int = DesktopToast.toasts.size()
	DesktopToast.show_toast("feedback toast", "run finished", ColorBase.success)
	assert(DesktopToast.toasts.size() == before + 1)
	var toast: DesktopToast = DesktopToast.toasts[before]
	assert(toast.title_text == "feedback toast")
	assert(toast.body_text == "run finished")
	assert(toast.accent == ColorBase.success)
	assert(toast.toast_corner == Corner.CORNER_BOTTOM_RIGHT)
	assert(toast.is_inside_tree())
	assert(toast.size.x == roundi(DesktopToast.CARD_WIDTH * DisplayScale.compute_ui_scale()))
	# Hold the toast on screen so a run with a display shows the card before it is dismissed.
	await ThreadUtils.async_sleep(1500)
	if is_instance_valid(toast):
		toast.close_toast()
		assert(toast.is_queued_for_deletion())
		# Closing twice is a no-op, so the second auto-dismiss timer cannot double-free the toast.
		toast.close_toast()
	assert(DesktopToast.toasts.size() == before)
	await gdf.gdf_node.get_tree().process_frame
	assert(!is_instance_valid(toast))
	pass


## The optional fourth argument selects a corner without changing the bottom-right default.
func DesktopToast_show_toast_in_corner_test() -> void:
	var before: int = DesktopToast.toasts.size()
	DesktopToast.show_toast("feedback toast", "run finished", ColorBase.success, Corner.CORNER_TOP_LEFT)
	var toast: DesktopToast = DesktopToast.toasts[before]
	assert(toast.toast_corner == Corner.CORNER_TOP_LEFT)
	assert(toast.position == DesktopToast.corner_position(toast.size, Corner.CORNER_TOP_LEFT))
	toast.close_toast()
	pass


## The toast must stay out of the native popup list: a display-server popup redirects every key event
## to itself and swallows clicks landing on the app window, so the app looks frozen while it lives.
func DesktopToast_no_popup_window_test() -> void:
	DesktopToast.show_toast("feedback toast", "run finished", ColorBase.success)
	var toast: DesktopToast = DesktopToast.toasts.back()
	await ThreadUtils.async_sleep(100)
	assert(!toast.popup_window)
	# `unfocusable` alone keeps it off the taskbar / alt-tab list and out of the way of clicks.
	assert(toast.unfocusable)
	assert(DisplayServer.window_get_active_popup() != toast.get_window_id())
	toast.close_toast()
	pass


func feedback_test_translation(key: String, value: String) -> Translation:
	var translation := Translation.new()
	translation.locale = TranslationServer.get_locale()
	translation.add_message(key, value)
	TranslationServer.add_translation(translation)
	return translation
