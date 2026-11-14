class_name GitDiffBubble
extends BubbleContainer

## Git diff bubble appended after agent_end, listing files changed from the run checkpoint.

const HELP_ICON_PATH := "res://agent/asset/image/ui/help.svg"

var markdown_label: MarkdownRichTextLabel

func panel_color() -> Color:
	return Colors.control_surface


func apply(session_id: int, entry: ChatEntry) -> void:
	apply_panel_style(panel_color())
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
	title_label.add_theme_font_size_override("font_size", Typography.label_medium)
	header.add_child(title_label)

	# Revert restores the whole workspace, not only the listed files: hover summarises the tradeoff,
	# clicking opens the comparison other coding agents make in the same situation.
	# It sits on the xs tier of the header buttons beside it — a larger disc would set the row height and
	# stretch Revert / Diff to match.
	var help_button := ButtonStyle.create_icon_button(HELP_ICON_PATH, I18n.t("git.rollback_help"), ControlSize.xs)
	help_button.name = "RollbackHelpButton"
	help_button.pressed.connect(on_help_pressed)
	header.add_child(help_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var checkpoint: String = entry.details.get(ChatEntry.DETAIL_CHECKPOINT, "")
	var revert_button := Button.new()
	revert_button.name = "RevertButton"
	revert_button.text = I18n.t("git.revert")
	revert_button.disabled = StringUtils.is_blank(checkpoint)
	revert_button.pressed.connect(on_revert_pressed.bind(session_id, entry))
	style_header_button(revert_button, Colors.surface, I18n.t("git.restore_workspace"), ControlSize.xxl)
	header.add_child(revert_button)

	var diff_button := Button.new()
	diff_button.name = "DiffButton"
	diff_button.text = I18n.t("git.diff")
	var patch_path: String = entry.details.get(ChatEntry.DETAIL_GIT_DIFF_PATCH, "")
	diff_button.disabled = StringUtils.is_blank(patch_path)
	diff_button.pressed.connect(on_diff_pressed.bind(patch_path))
	style_header_button(diff_button, Colors.surface, I18n.t("git.open_side_by_side"), ControlSize.xl)
	header.add_child(diff_button)

	markdown_label = MarkdownHelper.create_plain_rich_text_label(Colors.secondary_text)
	markdown_label.meta_clicked.connect(open_file_diff.bind(patch_path))
	markdown_label.tooltip_text = I18n.t("git.open_file")
	vbox.add_child(markdown_label)
	refresh(entry)
	pass


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(markdown_label) or entry == null:
		return
	markdown_label.clear()
	var paths := entry.body.split(FileUtils.NEWLINE_LF, false)
	if paths.is_empty():
		markdown_label.add_text(I18n.t("git.no_files_changed"))
		return
	for i in paths.size():
		var parts := paths[i].split("\t", false)
		var path := parts[0].strip_edges()
		if StringUtils.is_blank(path):
			continue
		markdown_label.push_meta(path)
		markdown_label.add_text(path)
		markdown_label.pop()
		var added := parts[1].strip_edges() if parts.size() > 1 else "0"
		var removed := parts[2].strip_edges() if parts.size() > 2 else "0"
		markdown_label.add_text("  ")
		markdown_label.push_color(Colors.success)
		markdown_label.add_text("+" + ("?" if added == "-" else added))
		markdown_label.pop()
		markdown_label.add_text("  ")
		markdown_label.push_color(Colors.error)
		markdown_label.add_text("-" + ("?" if removed == "-" else removed))
		markdown_label.pop()
		if i < paths.size() - 1:
			markdown_label.newline()
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


## Whole-tree rollback is the same choice Codex snapshots make, not the per-file tracking Claude Code
## and Cursor use; the popup spells out both tradeoffs instead of hiding them behind a one-liner.
static func on_help_pressed() -> void:
	var window := PopupWindow.new()
	window.title = I18n.t("git.rollback_help_title")
	gdf.gdf_node.add_child(window)
	window.set_body(I18n.t("git.rollback_help_detail"))
	# set_body parks the view at the tail for streamed text; this help must open at the top.
	window.text_edit.scroll_vertical = 0
	window.present_centered(60, 70)
	pass


static func on_revert_pressed(session_id: int, entry: ChatEntry) -> void:
	var checkpoint: String = entry.details.get(ChatEntry.DETAIL_CHECKPOINT, "")
	var restore_error := await GitCheckpointManager.async_restore(session_id, checkpoint)
	if restore_error != OK:
		Alert.alert(I18n.t("git.restore_failed"), Colors.error)
		return
	AgentSessionManager.delete_chat_from_entry(session_id, entry)
	Alert.alert(I18n.t("git.restored"), Colors.success)
	pass
