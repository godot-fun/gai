class_name CodeEditStyle
extends Object

## Shared CodeEdit fonts, caret, selection, and scrollbars for the git diff viewer and chat composer.

static func apply_base(edit: CodeEdit) -> void:
	edit.add_theme_font_override("font", Fonts.code())
	edit.add_theme_color_override("font_color", Colors.primary_text)
	edit.add_theme_color_override("font_readonly_color", Colors.disabled_text)
	edit.add_theme_color_override("font_selected_color", Colors.primary_text)
	edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	edit.add_theme_color_override("selection_color", ThemeColor.selection_color)
	edit.add_theme_constant_override("line_spacing", 4)
	ScrollBarStyle.apply(edit.get_v_scroll_bar(), ScrollBarStyle.Thickness.LG)
	ScrollBarStyle.apply(edit.get_h_scroll_bar(), ScrollBarStyle.Thickness.LG)
	pass


## Side-by-side diff panes: surface background, line numbers, and current-line tint.
static func apply_diff_editor(edit: CodeEdit) -> void:
	var editor_style := StyleBoxHelper.create_style_box_flat(Colors.surface, 0, 0, Margin.ma_2)
	for state in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(state, editor_style.duplicate())
	edit.add_theme_color_override("background_color", Colors.surface)
	apply_base(edit)
	edit.add_theme_color_override("line_number_color", Colors.secondary_text)
	edit.add_theme_color_override("current_line_color", Color(ThemeColor.accent_theme_color(), 0.10))
	pass
