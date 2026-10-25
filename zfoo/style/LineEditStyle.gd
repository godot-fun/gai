class_name LineEditStyle
extends Object

## LineEdit affordances beyond field StyleBoxes. Godot's default clear-button tint targets dark UI.


static func apply_field_text(
	edit: LineEdit,
	font_color: Color = Colors.primary_text,
	placeholder_color: Color = Colors.secondary_text.darkened(0.08),
	selection_color: Color = ThemeColor.selection_color
) -> void:
	edit.add_theme_color_override("font_color", font_color)
	edit.add_theme_color_override("font_placeholder_color", placeholder_color)
	edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	edit.add_theme_color_override("font_selected_color", font_color)
	edit.add_theme_color_override("selection_color", selection_color)
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


## Apply the shared editable field treatment while allowing callers to supply their own surface.
static func apply_line_edit(
	edit: LineEdit,
	normal: StyleBoxFlat,
	font_color: Color = Colors.primary_text,
	placeholder_color: Color = Colors.secondary_text.darkened(0.08),
	selection_color: Color = ThemeColor.selection_color,
	focus_border_width: int = ControlSize.border_sm
) -> void:
	apply_field_text(edit, font_color, placeholder_color, selection_color)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = ThemeColor.accent_theme_color()
	if focus_border_width > 0:
		focus.set_border_width_all(focus_border_width)
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_stylebox_override("read_only", normal.duplicate())
	apply_clear_button(edit)
	pass
