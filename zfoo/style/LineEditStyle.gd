class_name LineEditStyle
extends Object

## LineEdit affordances beyond field StyleBoxes. Godot's default clear-button tint targets dark UI.


static func apply_field_text(edit: LineEdit) -> void:
	edit.add_theme_color_override("font_color", Colors.primary_text)
	edit.add_theme_color_override("font_placeholder_color", Colors.secondary_text.darkened(0.08))
	edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	edit.add_theme_color_override("font_selected_color", Colors.primary_text)
	edit.add_theme_color_override("selection_color", ThemeColor.selection_color)
	edit.caret_blink = true
	pass


static func apply_transparent_field(edit: LineEdit) -> void:
	var empty := StyleBoxEmpty.new()
	edit.add_theme_stylebox_override("normal", empty)
	edit.add_theme_stylebox_override("hover", empty)
	edit.add_theme_stylebox_override("focus", empty)
	edit.add_theme_stylebox_override("read_only", empty)
	pass


static func apply_clear_button(edit: LineEdit) -> void:
	if not edit.clear_button_enabled:
		return
	edit.add_theme_color_override("clear_button_color", Colors.secondary_text)
	edit.add_theme_color_override("clear_button_color_pressed", ThemeColor.accent_theme_color())
	pass
