class_name CommonEditor
extends CodeEdit

## Plain text and source editor. Colors come from [method CommonHighlighter.create] for [member file_path].

var file_path: String = ""


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	editable = true
	caret_blink = true
	highlight_current_line = true
	wrap_mode = TextEdit.LINE_WRAPPING_NONE
	gutters_draw_line_numbers = true
	apply_theme()
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	pass


func apply_file(path: String) -> void:
	file_path = path
	syntax_highlighter = CommonHighlighter.create(path)
	pass


func apply_theme() -> void:
	CodeEditStyle.apply_diff_editor(self)
	add_theme_font_size_override("font_size", Typography.body_large_size)
	syntax_highlighter = CommonHighlighter.create(file_path)
	pass


func focus_editor() -> void:
	if is_inside_tree() and is_visible_in_tree():
		grab_focus()
	pass
