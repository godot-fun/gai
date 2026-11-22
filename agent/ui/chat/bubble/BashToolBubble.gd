class_name BashToolBubble
extends BubbleContainer

## Bash tool-call bubble with compact rendering for process polling operations.

var markdown_label: MarkdownRichTextLabel

func panel_color() -> Color:
	return Colors.success_surface


func apply(_session_id: int, entry: ChatEntry) -> void:
	apply_panel_style(panel_color())

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	add_child(vbox)

	var title_label := Label.new()
	var compact := entry.title == BashProcessTool.NAME
	title_label.text = compact_title(entry) if compact else entry.title
	title_label.add_theme_color_override("font_color", Colors.success)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium)
	vbox.add_child(title_label)
	if compact:
		return

	markdown_label = MarkdownHelper.create_plain_rich_text_label(Colors.success)
	vbox.add_child(markdown_label)
	refresh(entry)
	pass


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(markdown_label) or entry == null:
		return
	markdown_label.visible = StringUtils.is_not_blank(entry.body)
	MarkdownHelper.update_rich_text_label_text(markdown_label, entry.body, false)
	pass


static func compact_title(entry: ChatEntry) -> String:
	var body := entry.body.strip_edges()
	return entry.title if body.is_empty() else StringUtils.format("{}  {}", entry.title, body)
