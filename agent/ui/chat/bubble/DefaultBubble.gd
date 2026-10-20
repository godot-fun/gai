class_name DefaultBubble
extends BubbleContainer

var rich_text: RichTextLabel

## Basic titled markdown bubble used by system and unknown chat entry kinds.


static func append(
	chat_list: VBoxContainer,
	entry: ChatEntry,
	panel_style: StyleBoxFlat,
	text_color: Color,
	title_color: Color = Colors.secondary_text
) -> DefaultBubble:
	var wrapper := DefaultBubble.new()
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

	wrapper.rich_text = MarkdownHelper.create_rich_text_label(
		text_color,
		entry.body,
		AgentSetting.get_markdown_enabled()
	)
	wrapper.rich_text.visible = StringUtils.is_not_blank(entry.body)
	vbox.add_child(wrapper.rich_text)

	chat_list.add_child(wrapper)
	return wrapper


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(rich_text) or entry == null:
		return
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	MarkdownHelper.update_rich_text_label_text(rich_text, entry.body, AgentSetting.get_markdown_enabled())
	pass
