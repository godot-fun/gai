func markdown_edit_text_and_view_mode_test() -> void:
	var editor := MarkdownEdit.new()
	gdf.gdf_node.add_child(editor)
	var edits: Array[String] = []
	editor.text_changed.connect(func() -> void: edits.append(editor.text))
	editor.text = "# Hello\n\nbody"
	assert(editor.text == "# Hello\n\nbody")
	assert(edits.size() == 1)
	assert(edits[0] == "# Hello\n\nbody")
	assert("Hello" in editor.preview_label.text)
	assert(editor.view_mode == MarkdownEdit.ViewMode.SPLIT)
	assert(editor.text_edit.visible)
	assert(editor.preview_panel.visible)
	assert(editor.split_mode_button.button_pressed)

	var modes: Array[int] = []
	editor.view_mode_changed.connect(func(mode: MarkdownEdit.ViewMode) -> void: modes.append(mode))
	editor.set_view_mode(MarkdownEdit.ViewMode.EDIT)
	assert(editor.text_edit.visible)
	assert(not editor.preview_panel.visible)
	assert(editor.edit_mode_button.button_pressed)
	editor.set_view_mode(MarkdownEdit.ViewMode.PREVIEW)
	assert(not editor.text_edit.visible)
	assert(editor.preview_panel.visible)
	assert(editor.preview_mode_button.button_pressed)
	assert(modes.size() == 2)
	assert(modes[0] == MarkdownEdit.ViewMode.EDIT)
	assert(modes[1] == MarkdownEdit.ViewMode.PREVIEW)

	editor.placeholder_text = "write here"
	assert(editor.text_edit.placeholder_text == "write here")
	editor.set_split_ratio(0.25)
	assert(is_equal_approx(editor.split_ratio, 0.25))

	var leading := CheckButton.new()
	editor.add_toolbar_leading(leading)
	assert(leading.get_index() < editor.toolbar_spacer.get_index())
	assert(editor.edit_mode_button.get_index() > editor.toolbar_spacer.get_index())

	editor.free()
	pass
