class_name GitDiffBubble
extends RefCounted

## Git diff bubble appended after agent_end, listing files changed from the run checkpoint.

static func append(chat_list: VBoxContainer, entry: ChatEntry, panel_style: StyleBoxFlat) -> RichTextLabel:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.visible = StringUtils.is_not_blank(entry.body)
	wrapper.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	wrapper.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	vbox.add_child(header)

	var title_label := Label.new()
	title_label.text = ChatEntry.TITLE_GIT_DIFF
	title_label.add_theme_color_override("font_color", ColorBase.secondary_text)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var diff_button := Button.new()
	diff_button.text = "Diff"
	var patch_path: String = entry.details.get(ChatEntry.DETAIL_GIT_DIFF_PATCH, "")
	diff_button.disabled = StringUtils.is_blank(patch_path)
	diff_button.pressed.connect(on_diff_pressed.bind(patch_path))
	AgentBubble.style_header_button(diff_button, panel_style.bg_color, "Open this run in Delta", 52.0)
	header.add_child(diff_button)

	var rich_text := MarkdownHelper.create_plain_rich_text_label(ColorBase.secondary_text)
	rich_text.meta_clicked.connect(open_file_diff.bind(patch_path))
	rich_text.tooltip_text = "Open file diff"
	vbox.add_child(rich_text)
	wrapper.set_meta(AgentChatView.META_BUBBLE_RICH_TEXT, rich_text)
	chat_list.add_child(wrapper)
	refresh(rich_text, entry)
	return rich_text


static func refresh(rich_text: RichTextLabel, entry: ChatEntry) -> void:
	rich_text.clear()
	var paths := entry.body.split(FileUtils.NEWLINE_LF, false)
	if paths.is_empty():
		rich_text.add_text("No files changed")
		return
	for i in paths.size():
		var parts := paths[i].split("\t", false)
		var path := parts[0].strip_edges()
		if StringUtils.is_blank(path):
			continue
		rich_text.push_meta(path)
		rich_text.add_text(path)
		rich_text.pop()
		var added := parts[1].strip_edges() if parts.size() > 1 else "0"
		var removed := parts[2].strip_edges() if parts.size() > 2 else "0"
		rich_text.add_text("  ")
		rich_text.push_color(ColorBase.success)
		rich_text.add_text("+" + ("?" if added == "-" else added))
		rich_text.pop()
		rich_text.add_text("  ")
		rich_text.push_color(ColorBase.error)
		rich_text.add_text("-" + ("?" if removed == "-" else removed))
		rich_text.pop()
		if i < paths.size() - 1:
			rich_text.newline()
	pass


static func open_file_diff(meta: Variant, patch_path: String) -> void:
	var relative_path := str(meta)
	if not AgentCheckpoint.open_file_diff(patch_path, relative_path):
		Alert.alert(StringUtils.format("Git diff is unavailable: {}", relative_path), ColorBase.error)
	pass


static func on_diff_pressed(patch_path: String) -> void:
	AgentCheckpoint.open_diff(patch_path)
	pass
