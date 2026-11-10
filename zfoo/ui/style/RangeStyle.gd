class_name RangeStyle
extends Object

const PRESSED_STATE_OPACITY := 0.12


## Apply the shared [SpinBox] treatment. The embedded line edit uses the themed field surface;
## increment and decrement controls add lightweight state layers without replacing that surface.
static func apply_spin_box(spin: SpinBox) -> void:
	var normal := LineEditStyle.theme_normal_style()
	LineEditStyle.apply(spin.get_line_edit(), normal)
	spin.add_theme_color_override("font_color", Colors.primary_text)
	spin.add_theme_color_override("font_placeholder_color", Colors.secondary_text)
	var button_normal := StyleBoxHelper.create_style_box_flat(ThemeColor.field_surface, ControlSize.radius_xs, Margin.ma_0, Margin.ma_0,
		Colors.outline_variant, ControlSize.border_xs)
	var hover := StyleBoxHelper.duplicate_with_bg_color(button_normal, Colors.hover(ThemeColor.field_surface), Colors.outline)
	var pressed_fill := ThemeColor.field_surface.blend(Color(Colors.primary_text, PRESSED_STATE_OPACITY))
	var pressed := StyleBoxHelper.duplicate_with_bg_color(button_normal, pressed_fill, ThemeColor.accent_theme_color())
	var disabled := StyleBoxHelper.duplicate_with_bg_color(button_normal, ThemeColor.demote(ThemeColor.field_surface), Colors.outline_variant)
	spin.add_theme_stylebox_override("field_and_buttons_separator", StyleBoxEmpty.new())
	spin.add_theme_stylebox_override("up_down_buttons_separator", StyleBoxEmpty.new())
	spin.add_theme_constant_override("buttons_width", ControlSize.icon_xs)
	spin.add_theme_constant_override("icon_max_width", ControlSize.icon_xs)
	spin.add_theme_constant_override("set_min_buttons_width_from_icons", 0)
	spin.add_theme_constant_override("field_and_buttons_separation", Margin.ma_1)
	spin.add_theme_constant_override("buttons_vertical_separation", Margin.ma_1)

	# Up button
	spin.add_theme_color_override("up_icon_modulate", Colors.primary_text)
	spin.add_theme_color_override("up_hover_icon_modulate", Colors.primary_text)
	spin.add_theme_color_override("up_pressed_icon_modulate", ThemeColor.accent_theme_color())
	spin.add_theme_color_override("up_disabled_icon_modulate", Colors.disabled_text)
	spin.add_theme_stylebox_override("up_background", button_normal)
	spin.add_theme_stylebox_override("up_background_hovered", hover)
	spin.add_theme_stylebox_override("up_background_pressed", pressed)
	spin.add_theme_stylebox_override("up_background_disabled", disabled)

	# ----------------------------------------------------------------------------------------------------------------------
	# Down button
	spin.add_theme_color_override("down_icon_modulate", Colors.primary_text)
	spin.add_theme_color_override("down_hover_icon_modulate", Colors.primary_text)
	spin.add_theme_color_override("down_pressed_icon_modulate", ThemeColor.accent_theme_color())
	spin.add_theme_color_override("down_disabled_icon_modulate", Colors.disabled_text)
	spin.add_theme_stylebox_override("down_background", button_normal)
	spin.add_theme_stylebox_override("down_background_hovered", hover)
	spin.add_theme_stylebox_override("down_background_pressed", pressed)
	spin.add_theme_stylebox_override("down_background_disabled", disabled)
	pass


## Apply the shared [Slider] treatment: a recessed field-surface track with an accent-filled
## progress area. The grabber keeps the engine icon, which already follows the active theme.
static func apply_slider(slider: Slider) -> void:
	var radius := ControlSize.radius_xs
	slider.custom_minimum_size.y = ControlSize.md
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.add_theme_constant_override("center_grabber", 0)
	slider.add_theme_constant_override("grabber_offset", 0)
	# Track thickness comes from the boxes' content margins — the slider draws each box at its
	# minimum height, so a box without vertical padding would collapse to nothing.
	var padding := Margin.ma_2 / 2
	var track := StyleBoxHelper.create_style_box_flat(ThemeColor.demote(ThemeColor.field_surface, Weights.w_4),
		radius, Margin.ma_0, padding, Colors.outline_variant, ControlSize.border_xs)
	slider.add_theme_stylebox_override("slider", track)
	var accent := ThemeColor.accent_theme_color()
	slider.add_theme_stylebox_override("grabber_area", StyleBoxHelper.create_style_box_flat(accent, radius, Margin.ma_0, padding))
	slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxHelper.create_style_box_flat(ThemeColor.promote(accent, Weights.w_2), radius, Margin.ma_0, padding))
	pass
