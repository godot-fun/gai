class_name GitDiffBubble
extends BubbleContainer

var rich_text: RichTextLabel

## Git diff bubble appended after agent_end, listing files changed from the run checkpoint.

func apply(session_id: int, entry: ChatEntry) -> void:
	apply_panel_style(Colors.surface)
	visible = StringUtils.is_not_blank(entry.body)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	vbox.add_child(header)

	var title_label := Label.new()
	title_label.text = I18n.t("git.title")
	title_label.add_theme_color_override("font_color", Colors.secondary_text)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var checkpoint: String = entry.details.get(ChatEntry.DETAIL_CHECKPOINT, "")
	var revert_button := Button.new()
	revert_button.name = "RevertButton"
	revert_button.text = I18n.t("git.revert")
	revert_button.disabled = StringUtils.is_blank(checkpoint)
	revert_button.pressed.connect(on_revert_pressed.bind(session_id, entry))
	style_header_button(revert_button, Colors.surface, I18n.t("git.restore_workspace"), 58.0)
	header.add_child(revert_button)

	var diff_button := Button.new()
	diff_button.name = "DiffButton"
	diff_button.text = I18n.t("git.diff")
	var patch_path: String = entry.details.get(ChatEntry.DETAIL_GIT_DIFF_PATCH, "")
	diff_button.disabled = StringUtils.is_blank(patch_path)
	diff_button.pressed.connect(on_diff_pressed.bind(patch_path))
	style_header_button(diff_button, Colors.surface, I18n.t("git.open_side_by_side"), 52.0)
	header.add_child(diff_button)

	rich_text = MarkdownHelper.create_plain_rich_text_label(Colors.secondary_text)
	rich_text.meta_clicked.connect(open_file_diff.bind(patch_path))
	rich_text.tooltip_text = I18n.t("git.open_file")
	vbox.add_child(rich_text)
	refresh(entry)
	pass


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(rich_text) or entry == null:
		return
	rich_text.clear()
	var paths := entry.body.split(FileUtils.NEWLINE_LF, false)
	if paths.is_empty():
		rich_text.add_text(I18n.t("git.no_files_changed"))
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
		rich_text.push_color(Colors.success)
		rich_text.add_text("+" + ("?" if added == "-" else added))
		rich_text.pop()
		rich_text.add_text("  ")
		rich_text.push_color(Colors.error)
		rich_text.add_text("-" + ("?" if removed == "-" else removed))
		rich_text.pop()
		if i < paths.size() - 1:
			rich_text.newline()
	pass


static func open_file_diff(meta: Variant, patch_path: String) -> void:
	var relative_path := str(meta)
	if not GitDiffManager.open_file_diff(patch_path, relative_path):
		Alert.alert(StringUtils.format(I18n.t("git.unavailable_file"), relative_path), Colors.error)
	pass


static func on_diff_pressed(patch_path: String) -> void:
	if not GitDiffManager.open_diff(patch_path):
		Alert.alert(I18n.t("git.unavailable"), Colors.error)
	pass


static func on_revert_pressed(session_id: int, entry: ChatEntry) -> void:
	var checkpoint: String = entry.details.get(ChatEntry.DETAIL_CHECKPOINT, "")
	if not await GitCheckpointManager.async_restore(session_id, checkpoint):
		Alert.alert(I18n.t("git.restore_failed"), Colors.error)
		return
	AgentSessionManager.delete_chat_from_entry(session_id, entry)
	Alert.alert(I18n.t("git.restored"), Colors.success)
	pass
