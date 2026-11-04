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

	var leading := CheckButton.new()
	editor.add_toolbar_leading(leading)
	assert(leading.get_index() < editor.toolbar_spacer.get_index())

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
