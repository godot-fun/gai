class_name RangeStyle
extends Object

## Apply the shared [SpinBox] treatment. The embedded line edit uses the themed card surface;
## compact increment and decrement controls derive their normal and hover boxes from it.
static func apply_spin_box(spin: SpinBox) -> void:
	var normal := StyleBoxHelper.create_style_box_flat(ThemeColor.card_surface, ControlSize.radius_md, Margin.ma_3, Margin.ma_0
			, Color(ThemeColor.title_color, Colors.am_2), ControlSize.border_xs)
	LineEditStyle.apply_line_edit(spin.get_line_edit(), normal)
	spin.add_theme_color_override("font_color", Colors.primary_text)
	spin.add_theme_color_override("font_placeholder_color", Colors.secondary_text)
	spin.add_theme_color_override("up_icon_modulate", Colors.primary_text)
	spin.add_theme_color_override("down_icon_modulate", Colors.primary_text)
	spin.add_theme_color_override("up_hover_icon_modulate", ThemeColor.accent_theme_color())
	spin.add_theme_color_override("down_hover_icon_modulate", ThemeColor.accent_theme_color())
	spin.add_theme_color_override("up_pressed_icon_modulate", ThemeColor.accent_theme_color())
	spin.add_theme_color_override("down_pressed_icon_modulate", ThemeColor.accent_theme_color())
	var button_normal: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	button_normal.content_margin_left = Margin.ma_0
	button_normal.content_margin_right = Margin.ma_0
	var hover := StyleBoxHelper.duplicate_with_bg_color(button_normal, Colors.hover_surface)
	for side: String in ["up", "down"]:
		spin.add_theme_stylebox_override(side + "_background", button_normal)
		spin.add_theme_stylebox_override(side + "_background_hovered", hover)
		spin.add_theme_stylebox_override(side + "_background_pressed", hover.duplicate())
		spin.add_theme_stylebox_override(side + "_background_disabled", button_normal.duplicate())
	spin.add_theme_stylebox_override("field_and_buttons_separator", StyleBoxEmpty.new())
	spin.add_theme_stylebox_override("up_down_buttons_separator", StyleBoxEmpty.new())
	pass
