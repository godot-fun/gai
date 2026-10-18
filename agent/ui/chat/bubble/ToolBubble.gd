class_name ToolBubble
extends Object

## Tool-call bubble showing the command, query, path, or primary argument sent to a tool.

static func append(chat_list: VBoxContainer, entry: ChatEntry, panel_style: StyleBoxFlat) -> RichTextLabel:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	wrapper.add_child(vbox)

	var title_label := Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.success)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	vbox.add_child(title_label)

	var rich_text := MarkdownHelper.create_plain_rich_text_label(Colors.success)
	vbox.add_child(rich_text)
	wrapper.set_meta(ChatBubbleFactory.META_BUBBLE_RICH_TEXT, rich_text)
	chat_list.add_child(wrapper)
	refresh(rich_text, entry)
	return rich_text


static func refresh(rich_text: RichTextLabel, entry: ChatEntry) -> void:
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	MarkdownHelper.update_rich_text_label_text(rich_text, entry.body, false)
	pass
