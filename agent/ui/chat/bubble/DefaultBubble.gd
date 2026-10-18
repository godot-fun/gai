class_name DefaultBubble
extends Object

## Basic titled markdown bubble used by system and unknown chat entry kinds.


static func append(
	chat_list: VBoxContainer,
	entry: ChatEntry,
	panel_style: StyleBoxFlat,
	text_color: Color,
	title_color: Color = Colors.secondary_text
) -> RichTextLabel:
	var wrapper: PanelContainer = PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", panel_style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	wrapper.add_child(vbox)

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", title_color)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	vbox.add_child(title_label)

	var rich_text: RichTextLabel = MarkdownHelper.create_rich_text_label(
		text_color,
		entry.body,
		AgentSetting.get_markdown_enabled()
	)
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	vbox.add_child(rich_text)
	wrapper.set_meta(ChatBubbleFactory.META_BUBBLE_RICH_TEXT, rich_text)

	chat_list.add_child(wrapper)
	return rich_text
