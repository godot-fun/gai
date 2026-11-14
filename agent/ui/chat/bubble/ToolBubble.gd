class_name ToolBubble
extends BubbleContainer

## Tool-call bubble showing the command, query, path, or primary argument sent to a tool.

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
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.success)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium)
	vbox.add_child(title_label)

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
