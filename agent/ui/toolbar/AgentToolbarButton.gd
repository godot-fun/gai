class_name AgentToolbarButton
extends Object

## Shared styling for compact Code Agent toolbar buttons (Log, Markdown, …).


static func style(button: Button, tooltip: String) -> void:
	button.tooltip_text = tooltip
	button.custom_minimum_size = ControlSize.square(ControlSize.sm)
	button.flat = false
	button.add_theme_font_size_override("font_size", Typography.label_small_size)
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, ThemeColor.accent_theme_color())

	var normal := StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1, Colors.subtle_border, ControlSize.border_xs)
	ButtonStyle.apply_style(button, normal,
		StyleBoxHelper.duplicate_with_bg_color(normal, Colors.hover_surface),
		StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.selected_surface))
	button.add_theme_stylebox_override("hover_pressed", StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.promote(ThemeColor.selected_surface, Weights.w_2)))
	pass


static func style_round(button: Button, tooltip: String) -> void:
	button.tooltip_text = tooltip
	button.text = ""
	button.custom_minimum_size = ControlSize.square(ControlSize.sm)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.flat = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", Typography.label_small_size)
	button.add_theme_constant_override("icon_max_width", ControlSize.icon_md)
	button.add_theme_constant_override("icon_max_height", ControlSize.icon_md)
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, ThemeColor.accent_theme_color())

	# Equal margins keep the button square (sm×sm); asymmetric h/v margins stretch it into an ellipse.
	var normal := StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.sm / 2, Margin.ma_1, Margin.ma_1, Colors.subtle_border, ControlSize.border_xs)
	ButtonStyle.apply_style(button, normal,
		StyleBoxHelper.duplicate_with_bg_color(normal, Colors.hover_surface),
		StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.selected_surface))
	button.add_theme_stylebox_override("hover_pressed", StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.promote(ThemeColor.selected_surface, Weights.w_2)))
	pass
