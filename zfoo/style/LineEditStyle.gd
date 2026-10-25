class_name LineEditStyle
extends Object

## LineEdit affordances beyond field StyleBoxes. Godot's default clear-button tint targets dark UI.


## Standard card-surface field box shared by line edits and spin boxes.
static func theme_normal_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(ThemeColor.card_surface,
		ControlSize.radius_md, Margin.ma_3, Margin.ma_0,
		Color(ThemeColor.title_color, Weights.w_2), ControlSize.border_xs)


## Apply the shared editable field treatment while allowing callers to supply their own surface.
static func apply(
	edit: LineEdit,
	normal: StyleBoxFlat = theme_normal_style(),
	font_color: Color = Colors.primary_text,
	placeholder_color: Color = ThemeColor.demote(Colors.secondary_text, Weights.w_2),
	selection_color: Color = ThemeColor.selection_color,
	focus_border_width: int = ControlSize.border_sm
) -> void:
	edit.add_theme_color_override("font_color", font_color)
	edit.add_theme_color_override("font_placeholder_color", placeholder_color)
	edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	edit.add_theme_color_override("font_selected_color", font_color)
	edit.add_theme_color_override("selection_color", selection_color)
	edit.caret_blink = true
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = ThemeColor.accent_theme_color()
	if focus_border_width > 0:
		focus.set_border_width_all(focus_border_width)
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_stylebox_override("read_only", normal.duplicate())
	if edit.clear_button_enabled:
		edit.add_theme_color_override("clear_button_color", Colors.secondary_text)
		edit.add_theme_color_override("clear_button_color_pressed", ThemeColor.accent_theme_color())
	pass
