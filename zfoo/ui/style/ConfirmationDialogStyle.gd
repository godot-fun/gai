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
	CommonWindow.apply_window_theme(dialog, ThemeColor.accent_surface, ThemeColor.title_color)
	dialog.add_theme_stylebox_override("panel", FileDialogStyle.make_dialog_body_style())
	dialog.add_theme_color_override("font_color", ThemeColor.title_color)
	dialog.add_theme_font_override("font", Fonts.regular())
	dialog.add_theme_font_size_override("font_size", Typography.body_medium)
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
	var text := accent if primary else ThemeColor.title_color
	var normal := FileDialogStyle.make_outline_action_normal(accent if primary else Color(text, 0.35))
	if primary:
		ButtonStyle.apply_style(button, normal, null, StyleBoxHelper.duplicate_with_bg_color(normal, accent, accent))
	else:
		ButtonStyle.apply_style(button, normal)
	ButtonStyle.apply_font_colors(button, text, text, ThemeColor.inset_surface if primary else text)
	pass
