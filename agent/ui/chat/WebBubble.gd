class_name WebBubble
extends Object

## Web-tool result bubble with a text preview and an optional browser screenshot.


static func append(chat_list: VBoxContainer, entry: ChatEntry, panel_style: StyleBoxFlat) -> RichTextLabel:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	wrapper.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_label := Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.secondary_text)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	var view_button := Button.new()
	view_button.text = "⋯"
	ResultBubble.style_view_button(view_button)
	view_button.pressed.connect(entry.open_full_view)
	header.add_child(view_button)

	var line_label := Label.new()
	line_label.add_theme_color_override("font_color", Colors.secondary_text)
	line_label.add_theme_font_size_override("font_size", Typography.label_small_size)
	header.add_child(line_label)
	vbox.add_child(header)

	var rich_text := MarkdownHelper.create_plain_rich_text_label(Colors.secondary_text)
	vbox.add_child(rich_text)
	append_screenshot(vbox, entry)

	wrapper.set_meta(AgentChatView.META_BUBBLE_RICH_TEXT, rich_text)
	chat_list.add_child(wrapper)
	refresh(rich_text, entry)
	return rich_text


static func refresh(rich_text: RichTextLabel, entry: ChatEntry) -> void:
	ChatBubblePreview.apply(rich_text, entry.body)
	pass


static func append_screenshot(parent: VBoxContainer, entry: ChatEntry) -> void:
	var screenshot_path: String = entry.details.get(AgentToolResult.DETAIL_SCREENSHOT_PATH, "")
	if StringUtils.is_blank(screenshot_path) or not FileAccess.file_exists(screenshot_path):
		return
	var screenshot := Image.load_from_file(screenshot_path)
	if screenshot == null or screenshot.is_empty():
		Log.error("failed to load web screenshot path:[{}]", screenshot_path)
		return
	var preview := TextureRect.new()
	preview.texture = ImageTexture.create_from_image(screenshot)
	preview.custom_minimum_size = Vector2(0, 180)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.tooltip_text = screenshot_path
	parent.add_child(preview)
	pass
