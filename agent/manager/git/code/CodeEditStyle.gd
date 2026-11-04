class_name CodeEditStyle
extends Object

## Shared CodeEdit fonts, caret, selection, and scrollbars for the git diff viewer and chat composer.


static func apply_base(edit: CodeEdit) -> void:
	edit.add_theme_font_override("font", Fonts.regular())
	edit.add_theme_color_override("font_color", Colors.primary_text)
	edit.add_theme_color_override("font_readonly_color", Colors.primary_text)
	edit.add_theme_color_override("font_selected_color", Colors.primary_text)
	edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	edit.add_theme_color_override("selection_color", ThemeColor.selection_color)
	ScrollBarStyle.apply(edit.get_v_scroll_bar(), ScrollBarStyle.Thickness.LG)
	ScrollBarStyle.apply(edit.get_h_scroll_bar(), ScrollBarStyle.Thickness.LG)
	pass


## Side-by-side diff panes: app background, line numbers, and current-line tint.
static func apply_diff_editor(edit: CodeEdit) -> void:
	var editor_style := StyleBoxHelper.create_style_box_flat(Colors.app_background, 0, 0, Margin.ma_2)
	edit.add_theme_stylebox_override("normal", editor_style.duplicate())
	edit.add_theme_stylebox_override("focus", editor_style.duplicate())
	edit.add_theme_stylebox_override("read_only", editor_style.duplicate())
	edit.add_theme_color_override("background_color", Colors.app_background)
	apply_base(edit)
	ScrollBarStyle.apply(edit.get_v_scroll_bar(), ScrollBarStyle.Thickness.MD)
	ScrollBarStyle.apply(edit.get_h_scroll_bar(), ScrollBarStyle.Thickness.MD)
	edit.add_theme_color_override("line_number_color", Colors.secondary_text)
	edit.add_theme_color_override("current_line_color", Color(ThemeColor.accent_theme_color(), 0.10))
	pass
