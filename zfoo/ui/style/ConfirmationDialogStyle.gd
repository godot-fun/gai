class_name ConfirmationDialogStyle
extends Object

## Shared theme for an embedded [ConfirmationDialog].
##
## The frame uses the accent surface, the body uses the inset surface, the OK action uses the
## accent color, and cancel plus any extra buttons stay on the title color. Call [method apply]
## again after a theme or accent-color change.
##
## [codeblock]
## ConfirmationDialogStyle.apply(dialog, [discard_button])
## [/codeblock]


## Paint [param dialog] and treat [param secondary_buttons] like Cancel.
static func apply(dialog: ConfirmationDialog, secondary_buttons: Array[Button] = []) -> void:
	dialog.transient = true
	dialog.oversampling_override = DisplayScale.compute_ui_scale()
	CommonWindow.apply_window_theme(dialog, ThemeColor.accent_surface, ThemeColor.title_color, ThemeColor.title_color)
	dialog.add_theme_stylebox_override("panel", make_body_style())
	dialog.add_theme_color_override("font_color", ThemeColor.title_color)
	dialog.add_theme_font_override("font", Fonts.regular())
	dialog.add_theme_font_size_override("font_size", Typography.body_medium_size)
	var label := dialog.get_label()
	label.add_theme_color_override("font_color", ThemeColor.title_color)
	label.add_theme_font_override("font", Fonts.regular())
	style_button(dialog.get_ok_button(), true)
	style_button(dialog.get_cancel_button(), false)
	for button in secondary_buttons:
		style_button(button, false)
	pass


static func style_button(button: Button, primary: bool) -> void:
	var accent := ThemeColor.accent_theme_color()
	var border := accent if primary else Color(ThemeColor.title_color, 0.35)
	var normal := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, ControlSize.radius_md, Margin.ma_3, Margin.ma_1, border, ControlSize.border_xs)
	var hover_fill := Color(accent, 0.28) if primary else Color(accent, 0.16)
	var pressed_fill := Color(accent, 0.42) if primary else Color(accent, 0.28)
	var hover := StyleBoxHelper.duplicate_with_bg_color(normal, hover_fill, accent)
	var pressed := StyleBoxHelper.duplicate_with_bg_color(normal, pressed_fill, accent)
	ButtonStyle.apply_style(button, normal, hover, pressed)
	var text := accent if primary else ThemeColor.title_color
	var pressed_text := ThemeColor.inset_surface if primary else text
	ButtonStyle.apply_font_colors(button, text, text, pressed_text)
	pass


static func make_body_style() -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, 0, Margin.ma_2, Margin.ma_2)
	style.expand_margin_left = ControlSize.border_xs
	style.expand_margin_top = ControlSize.border_xs
	style.expand_margin_right = ControlSize.border_xs
	style.expand_margin_bottom = ControlSize.border_xs
	return style
