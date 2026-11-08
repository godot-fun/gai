func common_editor_text_and_view_mode_test() -> void:
	var editor := CommonEditor.new()
	gdf.gdf_node.add_child(editor)
	assert(not editor.text_edit.gutters_draw_line_numbers)
	var edits: Array[String] = []
	editor.text_changed.connect(func() -> void: edits.append(editor.text))
	editor.set_document("# Hello\n\nbody", "md")
	assert(editor.text == "# Hello\n\nbody")
	assert(edits.size() == 1)
	assert(edits[0] == "# Hello\n\nbody")
	assert("Hello" in editor.preview_label.text)
	assert(editor.mode_bar.visible)
	assert(editor.view_mode == CommonEditor.ViewMode.SPLIT)
	assert(editor.text_edit.visible)
	assert(editor.preview_panel.visible)
	assert(editor.preview_label.clip_contents)
	assert(editor.preview_panel.clip_contents)
	assert(editor.text_edit.get_theme_font_size("font_size") == Typography.body_large)
	assert(editor.text_edit.get_theme_font_size("font_size") == editor.preview_label.get_theme_font_size("normal_font_size"))
	assert(editor.preview_label.get_theme_font_size("bold_font_size") == Typography.body_large)
	assert(editor.preview_label.get_theme_font_size("italics_font_size") == Typography.body_large)
	assert(editor.preview_label.get_theme_font_size("bold_italics_font_size") == Typography.body_large)
	assert(editor.preview_label.get_theme_font_size("mono_font_size") == Typography.body_large)
	assert(editor.split_mode_button.button_pressed)

	var modes: Array[int] = []
	editor.view_mode_changed.connect(func(mode: CommonEditor.ViewMode) -> void: modes.append(mode))
	editor.set_view_mode(CommonEditor.ViewMode.EDIT)
	assert(editor.text_edit.visible)
	assert(not editor.preview_panel.visible)
	assert(editor.edit_mode_button.button_pressed)
	editor.set_view_mode(CommonEditor.ViewMode.PREVIEW)
	assert(not editor.text_edit.visible)
	assert(editor.preview_panel.visible)
	assert(editor.preview_mode_button.button_pressed)
	assert(modes.size() == 2)
	assert(modes[0] == CommonEditor.ViewMode.EDIT)
	assert(modes[1] == CommonEditor.ViewMode.PREVIEW)

	editor.placeholder_text = "write here"
	assert(editor.text_edit.placeholder_text == "write here")
	editor.set_split_ratio(0.25)
	assert(is_equal_approx(editor.split_ratio, 0.25))

	editor.set_document("func ready() -> void:\n\tpass\n", "gd")
	assert(not editor.mode_bar.visible)
	assert(editor.text_edit.visible)
	assert(not editor.preview_panel.visible)
	assert(editor.text_edit.gutters_draw_line_numbers)
	assert(editor.text_edit.syntax_highlighter is CodeHighlighterInstance)

	editor.set_document("", "")
	assert(not editor.text_edit.gutters_draw_line_numbers)

	editor.free()
	pass


func common_editor_find_navigation_test() -> void:
	I18nHelper.init_i18n()
	var editor := CommonEditor.new()
	gdf.gdf_node.add_child(editor)
	editor.set_document("cat\ndog cat\nCat", "txt")
	editor.open_find(false)
	assert(editor.find_bar.visible)
	assert(not editor.replace_row.visible)
	editor.set_find_query("c")
	assert(editor.text_edit.get_selected_text() == "c")
	assert(editor.text_edit.get_caret_line() == 0)
	editor.set_find_query("cat")
	assert(editor.text_edit.get_selected_text() == "cat")
	assert(editor.text_edit.get_caret_line() == 0)
	assert(editor.text_edit.get_selection_from_column() == 0)
	assert(editor.find_count_label.text == StringUtils.format(I18n.t("markdown.find_count"), 1, 2))

	editor.find_next()
	assert(editor.text_edit.get_caret_line() == 1)
	assert(editor.text_edit.get_selection_from_column() == 4)
	assert(editor.find_count_label.text == StringUtils.format(I18n.t("markdown.find_count"), 2, 2))
	editor.find_next()
	assert(editor.text_edit.get_caret_line() == 0)
	assert(editor.text_edit.get_selection_from_column() == 0)
	editor.find_previous()
	assert(editor.text_edit.get_caret_line() == 1)
	editor.text_edit.deselect()
	editor.text_edit.set_caret_line(0)
	editor.text_edit.set_caret_column(0)
	editor.find_previous()
	assert(editor.text_edit.get_caret_line() == 0)
	assert(editor.text_edit.get_selected_text() == "cat")

	editor.set_find_query("")
	editor.find_next()
	assert(editor.find_count_label.text == "")

	editor.text_edit.select(0, 0, 0, 3)
	editor.close_find()
	assert(not editor.find_bar.visible)
	editor.open_find(false)
	assert(editor.find_edit.text == "cat")
	assert(editor.text_edit.get_caret_line() == 0)
	assert(editor.text_edit.get_selection_from_column() == 0)
	editor.set_find_query("dog")
	editor.open_find(false)
	assert(editor.find_edit.text == "dog")
	assert(not editor.replace_row.visible)

	editor.set_document("# cat", "md")
	editor.set_view_mode(CommonEditor.ViewMode.PREVIEW)
	editor.close_find()
	editor.open_find(false)
	assert(editor.view_mode == CommonEditor.ViewMode.SPLIT)
	assert(editor.text_edit.visible)

	var find_key := InputEventKey.new()
	find_key.pressed = true
	find_key.keycode = KEY_R
	find_key.ctrl_pressed = true
	editor._unhandled_input(find_key)
	assert(editor.replace_row.visible)
	var close_key := InputEventKey.new()
	close_key.pressed = true
	close_key.keycode = KEY_ESCAPE
	editor._unhandled_input(close_key)
	assert(not editor.find_bar.visible)
	assert(editor.find_count_label.text == "")

	editor.free()
	pass


func common_editor_replace_test() -> void:
	I18nHelper.init_i18n()
	var editor := CommonEditor.new()
	gdf.gdf_node.add_child(editor)
	editor.set_document("xx cat", "txt")
	editor.open_find(true)
	assert(editor.replace_row.visible)
	assert(editor.replace_edit.visible)
	assert(editor.find_edit.get_parent() == editor.replace_edit.get_parent())
	assert(editor.find_edit.custom_minimum_size.x == ControlSize.image_md)
	assert(editor.replace_edit.custom_minimum_size.x == ControlSize.image_md)
	assert(editor.replace_button.get_meta("find_icon_path") == "res://agent/asset/image/ui/find_replace.svg")
	assert(editor.replace_all_button.get_meta("find_icon_path") == "res://agent/asset/image/ui/done_all.svg")
	assert(editor.replace_button.text == "")
	assert(editor.replace_all_button.text == "")
	editor.set_find_query("cat")
	editor.replace_edit.text = "dog"
	editor.text_edit.deselect()
	editor.text_edit.set_caret_line(0)
	editor.text_edit.set_caret_column(0)
	editor.replace_current()
	assert(editor.text == "xx cat")
	assert(editor.text_edit.get_selected_text() == "cat")
	editor.replace_current()
	assert(editor.text == "xx dog")

	editor.set_document("cat and cat", "txt")
	editor.find_anchor = Vector2i.ZERO
	editor.set_find_query("")
	editor.set_find_query("cat")
	editor.replace_edit.text = "dog"
	assert(editor.text_edit.get_selected_text() == "cat")
	editor.replace_current()
	assert(editor.text == "dog and cat")
	assert(editor.text_edit.get_selected_text() == "cat")
	editor.replace_current()
	assert(editor.text == "dog and dog")
	editor.text_edit.undo()
	assert(editor.text == "dog and cat")
	editor.text_edit.undo()
	assert(editor.text == "cat and cat")

	editor.set_find_query("cat")
	editor.replace_edit.text = "dog"
	editor.replace_all_matches()
	assert(editor.text == "dog and dog")
	assert(editor.find_count_label.text == StringUtils.format(I18n.t("markdown.replaced_count"), 2))
	editor.text_edit.undo()
	assert(editor.text == "cat and cat")

	editor.editable = false
	editor.set_find_query("cat")
	assert(editor.replace_button.disabled)
	assert(editor.replace_all_button.disabled)
	editor.replace_current()
	editor.replace_all_matches()
	assert(editor.text == "cat and cat")

	editor.free()
	pass
