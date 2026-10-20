class_name ToolBubble
extends BubbleContainer

var rich_text: RichTextLabel

## Tool-call bubble showing the command, query, path, or primary argument sent to a tool.

static func append(chat_list: VBoxContainer, entry: ChatEntry, panel_style: StyleBoxFlat) -> ToolBubble:
	var wrapper := ToolBubble.new()
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

	wrapper.rich_text = MarkdownHelper.create_plain_rich_text_label(Colors.success)
	vbox.add_child(wrapper.rich_text)
	chat_list.add_child(wrapper)
	wrapper.refresh(entry)
	return wrapper


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(rich_text) or entry == null:
		return
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	MarkdownHelper.update_rich_text_label_text(rich_text, entry.body, false)
	pass
