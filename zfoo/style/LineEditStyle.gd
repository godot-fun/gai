class_name LineEditStyle
extends Object

## LineEdit affordances beyond field StyleBoxes. Godot's default clear-button tint targets dark UI.


static func apply_clear_button(edit: LineEdit) -> void:
	if not edit.clear_button_enabled:
		return
	edit.add_theme_color_override("clear_button_color", Colors.secondary_text)
	edit.add_theme_color_override("clear_button_color_pressed", ThemeColor.accent_theme_color())
	pass
