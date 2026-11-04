func confirmation_dialog_style_uses_theme_colors_test() -> void:
	var dialog := ConfirmationDialog.new()
	var extra := dialog.add_button("discard", false, "discard")
	ConfirmationDialogStyle.apply(dialog, [extra])
	var panel := dialog.get_theme_stylebox("panel") as StyleBoxFlat
	assert(panel.bg_color == ThemeColor.inset_surface)
	assert(dialog.get_ok_button().get_theme_color("font_color") == ThemeColor.accent_theme_color())
	var ok_hover := dialog.get_ok_button().get_theme_stylebox("hover") as StyleBoxFlat
	assert(ok_hover.bg_color == ThemeColor.selected_surface)
	assert(ok_hover.border_color == ThemeColor.alpha_theme_color(Weights.w_10))
	assert(dialog.get_cancel_button().get_theme_stylebox("hover") is StyleBoxFlat)
	assert(dialog.get_cancel_button().get_theme_color("font_color") == ThemeColor.title_color)
	assert(extra.get_theme_color("font_color") == ThemeColor.title_color)
	dialog.free()
	pass
