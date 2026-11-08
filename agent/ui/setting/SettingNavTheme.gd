class_name SettingNavTheme
extends Object

## Left-rail navigation chrome for [AgentSettingWindow].


static func nav_panel() -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(ThemeColor.card_surface, 0)
	style.border_color = Colors.outline_variant
	style.set_border_width(SIDE_RIGHT, ControlSize.border_xs)
	return style


static func nav_divider() -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = ThemeColor.alpha_theme_color(0.42 if ThemeColor.is_dark_theme() else 0.32)
	line.grow_begin = 2
	line.grow_end = 2
	line.thickness = 1
	return line


static func apply_nav_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", Typography.label_large)
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, Colors.primary_text)
	var normal := nav_button_style(Color.TRANSPARENT)
	var hover := nav_button_style(Colors.hover(Color.TRANSPARENT))
	var pressed := nav_button_style(ThemeColor.selected_surface, true)
	ButtonStyle.apply_style(button, normal, hover, pressed)
	pass


static func nav_button_style(fill: Color, selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(fill, ControlSize.radius_md)
	StyleBoxHelper.apply_margin(style, Margin.ma_2, Margin.ma_1, Margin.ma_2, Margin.ma_3)
	if selected:
		style.border_color = ThemeColor.accent_theme_color()
		style.set_border_width(SIDE_LEFT, ControlSize.border_sm)
	return style
