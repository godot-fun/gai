static func action_button_uses_blue_grey_surface_test() -> void:
	var button := Button.new()
	ButtonStyle.apply_action_button(button)
	var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
	var hover := button.get_theme_stylebox("hover") as StyleBoxFlat
	var pressed := button.get_theme_stylebox("pressed") as StyleBoxFlat

	assert(normal.bg_color == Colors.blue_grey_surface)
	assert(hover.bg_color == Colors.hover(Colors.blue_grey_surface))
	assert(pressed.bg_color == ThemeColor.promote(Colors.blue_grey_surface, Weights.w_2))
	button.free()
	pass
