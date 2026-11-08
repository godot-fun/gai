## Unit coverage for token-based UI scaling. Each test restores the configured application scale.


func numeric_scale_helpers_test() -> void:
	assert(DisplayScale.scale_int(5, 0.5) == 3)
	assert(is_equal_approx(DisplayScale.scale_float(2.5, 1.2), 3.0))
	assert(DisplayScale.scale_int_min(1, 0.1) == 1)
	assert(DisplayScale.scale_int_min(4, 0.5, 3) == 3)
	assert(is_equal_approx(DisplayScale.scale_float_min(-2.0, 2.0), 0.0))
	assert(is_equal_approx(DisplayScale.scale_float_min(2.0, 0.5, 0.25), 1.0))
	pass


func shared_tokens_scale_from_immutable_constants_test() -> void:
	Typography.apply_scale(1.25)
	Margin.apply_scale(1.25)
	ControlSize.apply_scale(1.25)
	assert(Typography.body_large == 20)
	assert(Margin.ma_5 == 25)
	assert(ControlSize.md == 45)

	# Reapplying must use base values rather than multiplying the previous result.
	Typography.apply_scale(1.5)
	Margin.apply_scale(1.5)
	ControlSize.apply_scale(1.5)
	assert(Typography.body_large == 24)
	assert(Margin.ma_5 == 30)
	assert(ControlSize.md == 54)
	restore_configured_scale()
	pass


func display_scale_updates_tokens_test() -> void:
	DisplayScale.apply_ui_scale()
	assert(Typography.body_large == roundi(Typography.BODY_LARGE * DisplayScale.get_ui_scale()))
	pass


func common_window_chrome_scales_with_ui_test() -> void:
	var window := Window.new()
	CommonWindow.apply_window_theme(window, Color.BLACK, Color.WHITE, Color.WHITE)
	var border := window.get_theme_stylebox("embedded_border") as StyleBoxFlat
	assert(window.get_theme_constant("title_height") == ControlSize.md)
	assert(window.get_theme_constant("close_h_offset") == ControlSize.icon_sm + ControlSize.border_sm)
	assert(window.get_theme_constant("close_v_offset") == roundi((ControlSize.md + ControlSize.icon_sm) * 0.5))
	assert(window.get_theme_icon("close").get_size() == ControlSize.square(ControlSize.icon_sm))
	assert(is_equal_approx(border.content_margin_left, Margin.ma_5 * 0.5))
	assert(is_equal_approx(border.content_margin_top, Margin.ma_7))
	assert(is_equal_approx(border.content_margin_right, Margin.ma_5 * 0.5))
	assert(is_equal_approx(border.content_margin_bottom, Margin.ma_2))
	assert(is_equal_approx(border.expand_margin_left, Margin.ma_2))
	assert(is_equal_approx(border.expand_margin_top, ControlSize.md))
	assert(is_equal_approx(border.expand_margin_right, Margin.ma_2))
	assert(is_equal_approx(border.expand_margin_bottom, Margin.ma_3 * 0.5))
	window.free()
	pass


func restore_configured_scale() -> void:
	var scale := DisplayScale.get_ui_scale()
	Typography.apply_scale(scale)
	Margin.apply_scale(scale)
	ControlSize.apply_scale(scale)
	pass
