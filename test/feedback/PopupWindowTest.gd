## Unit tests for [PopupWindow]. Loaded with the other scripts in this folder by [code]test/feedback/FeedbackTest.tscn[/code] ([UnitTest]).

## [method PopupWindow.show_window] opens a centered, read-only window sized as a percent of the screen.
func PopupWindow_show_window_test() -> void:
	close_open_windows()
	PopupWindow.show_window("feedback popup", "feedback popup body", 50, 60)
	var windows := open_windows()
	assert(windows.size() == 1)
	var window := windows[0]
	assert(window.visible)
	assert(window.title == "feedback popup")
	assert(window.text_edit.editable == false)
	assert(window.text_edit.text == "feedback popup body")
	if has_display():
		var viewport := gdf.gdf_node.get_tree().root.get_visible_rect().size
		assert(window.size.x == int(viewport.x * 0.5))
		assert(window.size.y == int(viewport.y * 0.6))
	# Hold the window open so a run with a display shows the popup.
	await ThreadUtils.async_sleep(1500)
	await close_window(window)
	pass


## Width and height percents are clamped to 1–100.
func PopupWindow_clamp_percent_test() -> void:
	close_open_windows()
	PopupWindow.show_window("feedback popup", "body", 0, 200)
	var windows := open_windows()
	assert(windows.size() == 1)
	if has_display():
		var viewport := gdf.gdf_node.get_tree().root.get_visible_rect().size
		assert(windows[0].size.x == int(viewport.x * 0.01))
		assert(windows[0].size.y == int(viewport.y))
	# Hold the window open so a run with a display shows the clamped popup.
	await ThreadUtils.async_sleep(1500)
	await close_window(windows[0])
	pass


## Popup title and body are translated at the display boundary.
func PopupWindow_i18n_text_test() -> void:
	close_open_windows()
	var translation := feedback_test_translation("feedback.popup.title", "Translated popup")
	translation.add_message("feedback.popup.body", "Translated popup body")
	PopupWindow.show_window("feedback.popup.title", "feedback.popup.body", 40, 40)
	var window := open_windows()[0]
	assert(window.title == "Translated popup")
	assert(window.text_edit.text == "Translated popup body")
	window.on_close_requested()
	await gdf.gdf_node.get_tree().process_frame
	TranslationServer.remove_translation(translation)
	pass


## [method PopupWindow.set_body] replaces the text and scrolls the read-only view to the last line.
func PopupWindow_set_body_test() -> void:
	var window := PopupWindow.new()
	gdf.gdf_node.add_child(window)
	window.size = Vector2i(400, 300)
	window.popup_centered()
	var body := ""
	for i in 200:
		body += "line-%d\n" % i
	window.set_body(body)
	assert(window.text_edit.text == body)
	# Scrolled to the end: the last line sits at the bottom of the view.
	var scroll_bar := window.text_edit.get_v_scroll_bar()
	assert(scroll_bar.max_value > 0.0)
	assert(is_equal_approx(window.text_edit.scroll_vertical, scroll_bar.max_value - scroll_bar.page))
	window.set_body("short body")
	assert(window.text_edit.text == "short body")
	assert(window.text_edit.scroll_vertical == 0.0)
	window.free()
	pass


## Esc dismisses the popup through [method PopupWindow.on_window_input].
func PopupWindow_cancel_input_test() -> void:
	close_open_windows()
	PopupWindow.show_window("feedback popup", "body", 40, 40)
	var windows := open_windows()
	assert(windows.size() == 1)
	var window := windows[0]
	# Hold the window open so a run with a display shows the popup before Esc.
	await ThreadUtils.async_sleep(1500)
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	if is_instance_valid(window):
		window.on_window_input(event)
	await gdf.gdf_node.get_tree().process_frame
	assert(!is_instance_valid(window))
	pass


## A fresh popup is a transient child window that stays hidden until [method PopupWindow.show_window] pops it.
func PopupWindow_transient_test() -> void:
	var window := PopupWindow.new()
	assert(window.transient)
	assert(!window.visible)
	assert(window.text_edit.editable == false)
	assert(window.text_edit.offset_left == -ControlSize.border_xs)
	assert(window.text_edit.offset_top == -ControlSize.border_xs)
	assert(window.text_edit.offset_right == ControlSize.border_xs)
	assert(window.text_edit.offset_bottom == ControlSize.border_xs)
	window.free()
	pass


## The popup lives under `gdf_node`, so it follows the app window and closes with it.
func PopupWindow_parent_test() -> void:
	close_open_windows()
	PopupWindow.show_window("feedback popup", "body", 40, 40)
	var windows := open_windows()
	assert(windows.size() == 1)
	assert(windows[0].get_parent() == gdf.gdf_node)
	assert(is_equal_approx(windows[0].oversampling_override, DisplayScale.compute_ui_scale()))
	# Hold the window open so a run with a display shows the popup.
	await ThreadUtils.async_sleep(1500)
	await close_window(windows[0])
	pass


## [method PopupWindow.apply_theme] paints the frame from [ThemeColor] and the text area from its inset surface.
func PopupWindow_theme_test() -> void:
	var window := PopupWindow.new()
	gdf.gdf_node.add_child(window)
	var border := window.get_theme_stylebox("embedded_border") as StyleBoxFlat
	assert(border.bg_color == ThemeColor.accent_surface)
	assert(border.corner_radius_top_left == ControlSize.radius_md)
	assert(border.get_minimum_size().y == window.get_theme_stylebox("embedded_unfocused_border").get_minimum_size().y)
	assert(window.get_theme_color("title_color") == ThemeColor.title_color)
	assert(window.get_theme_font("title_font") == Fonts.semibold())
	assert(window.get_theme_font_size("title_font_size") == Typography.title_medium_size)
	assert((window.get_theme_stylebox("embedded_unfocused_border") as StyleBoxFlat).bg_color == ThemeColor.accent_surface)
	assert((window.text_edit.get_theme_stylebox("read_only") as StyleBoxFlat).bg_color == ThemeColor.inset_surface)
	assert((window.text_edit.get_theme_stylebox("read_only") as StyleBoxFlat).content_margin_left == Margin.ma_4)
	assert(window.text_edit.get_theme_color("font_readonly_color") == ThemeColor.title_color)
	assert(window.text_edit.get_theme_color("caret_color") == ThemeColor.accent_theme_color())
	assert(window.text_edit.get_theme_font("font") == Fonts.regular())
	assert(window.text_edit.get_theme_font_size("font_size") == Typography.body_large_size)
	# The popup uses the shared thin scrollbar geometry and palette.
	var grabber := window.text_edit.get_v_scroll_bar().get_theme_stylebox("grabber") as StyleBoxFlat
	assert(grabber.bg_color == ThemeColor.body_color)
	window.free()
	pass


## A theme change repaints an open popup: the frame follows the accent, so does the caret.
func PopupWindow_theme_change_test() -> void:
	var window := PopupWindow.new()
	gdf.gdf_node.add_child(window)
	var original: Color = ThemeColor.theme_color
	# Start from an accent this test picks: the palette statics are only as fresh as the last refresh.
	ThemeColor.theme_color = Color(0.2, 0.45, 1.0)
	ThemeColor.refresh_derived_colors()
	gdf.events.theme_color_changed.emit()
	var painted := window.get_theme_stylebox("embedded_border") as StyleBoxFlat
	assert(painted.bg_color == ThemeColor.accent_surface)
	ThemeColor.theme_color = Color(1.0, 0.35, 0.05)
	ThemeColor.refresh_derived_colors()
	gdf.events.theme_color_changed.emit()
	var repainted := window.get_theme_stylebox("embedded_border") as StyleBoxFlat
	assert(repainted.bg_color == ThemeColor.accent_surface)
	assert(repainted.bg_color != painted.bg_color)
	assert(window.text_edit.get_theme_color("caret_color") == ThemeColor.accent_theme_color())
	# Back to the accent the project was started with, so no other test sees a repaint.
	ThemeColor.theme_color = original
	ThemeColor.refresh_derived_colors()
	gdf.events.theme_color_changed.emit()
	gdf.events.theme_changed.emit()
	assert(window.text_edit.get_theme_color("font_readonly_color") == ThemeColor.title_color)
	# The frame is rebuilt from the engine box on every repaint, so its geometry must survive.
	var engine_border: StyleBox = ThemeDB.get_default_theme().get_stylebox("embedded_border", "Window")
	var final_border := window.get_theme_stylebox("embedded_border") as StyleBoxFlat
	assert(final_border.expand_margin_top == engine_border.expand_margin_top)
	assert(final_border.expand_margin_left == engine_border.expand_margin_left)
	assert((window.get_theme_stylebox("embedded_unfocused_border") as StyleBoxFlat).expand_margin_top == engine_border.expand_margin_top)
	window.free()
	pass


## The headless dummy display clamps embedded windows to 1×1, so percent sizing is only measurable with a real one.
func has_display() -> bool:
	return DisplayServer.get_name() != "headless"


func open_windows() -> Array[PopupWindow]:
	var windows: Array[PopupWindow] = []
	for child in gdf.gdf_node.get_children():
		if child is PopupWindow:
			windows.push_back(child)
	return windows


func close_open_windows() -> void:
	for window in open_windows():
		window.on_close_requested()
	pass


func close_window(window: PopupWindow) -> void:
	if is_instance_valid(window):
		window.on_close_requested()
	await gdf.gdf_node.get_tree().process_frame
	pass


func feedback_test_translation(key: String, value: String) -> Translation:
	var translation := Translation.new()
	translation.locale = TranslationServer.get_locale()
	translation.add_message(key, value)
	TranslationServer.add_translation(translation)
	return translation
