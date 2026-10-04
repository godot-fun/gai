class_name ThinkingBubble
extends Object

## Thinking / reasoning bubble — plain text preview in chat.
## Full text lives on ChatEntry.body; the header ··· button opens it in PopupWindow.


static func append(
	chat_list: VBoxContainer,
	entry: ChatEntry,
	panel_style: StyleBoxFlat
) -> RichTextLabel:
	var wrapper: PanelContainer = PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", panel_style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	wrapper.add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", ColorBase.purple)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	var view_button: Button = Button.new()
	view_button.text = "…"
	style_view_button(view_button)
	view_button.pressed.connect(entry.open_full_view)
	header.add_child(view_button)

	var line_label: Label = Label.new()
	line_label.add_theme_color_override("font_color", ColorBase.secondary_text)
	line_label.add_theme_font_size_override("font_size", Typography.label_small_size)
	header.add_child(line_label)

	vbox.add_child(header)

	var rich_text: RichTextLabel = MarkdownHelper.create_plain_rich_text_label(ColorBase.secondary_text)
	ChatBubblePreview.enable_fixed_height_at_limit(rich_text)
	vbox.add_child(rich_text)

	wrapper.set_meta(AgentChatView.META_BUBBLE_RICH_TEXT, rich_text)

	chat_list.add_child(wrapper)
	ChatBubblePreview.apply(rich_text, entry.body)
	return rich_text


static func style_view_button(button: Button) -> void:
	button.tooltip_text = "View full thinking"
	button.custom_minimum_size = Vector2(22, 18)
	button.add_theme_font_size_override("font_size", Typography.label_small_size)
	ButtonStyle.apply_font_colors(button, ColorBase.purple, ButtonStyle.hover_color(ColorBase.purple, 0.12), ButtonStyle.press_color(ColorBase.purple, 0.08))

	var border := ButtonStyle.press_color(ColorBase.purple)
	var normal := StyleBoxHelper.create_style_box_flat(ButtonStyle.hover_color(ColorBase.purple_surface, 0.08), 4, Margin.ma_1, Margin.ma_0, border, ControlSize.border_xs)
	ButtonStyle.apply(button, normal,
		ButtonStyle.filled(normal, ButtonStyle.hover_color(ColorBase.purple_surface, 0.16), ColorBase.purple),
		ButtonStyle.filled(normal, ButtonStyle.press_color(ColorBase.purple_surface, 0.06), ColorBase.purple))
	pass
