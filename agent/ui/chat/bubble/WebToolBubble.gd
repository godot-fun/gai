class_name WebToolBubble
extends Object

## Web-tool call bubble showing the query, URL, or primary argument sent to the tool.


static func append(chat_list: VBoxContainer, entry: ChatEntry, panel_style: StyleBoxFlat) -> RichTextLabel:
	var wrapper: PanelContainer = PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", panel_style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.info)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	var rich_text := create_body_label()
	header.add_child(rich_text)
	vbox.add_child(header)

	wrapper.set_meta(ChatBubbleFactory.META_BUBBLE_RICH_TEXT, rich_text)
	chat_list.add_child(wrapper)
	refresh(rich_text, entry)
	return rich_text


static func refresh(rich_text: RichTextLabel, entry: ChatEntry) -> void:
	var body := entry.body.strip_edges()
	rich_text.clear()
	if HttpUtils.is_valid_http_url(body):
		rich_text.push_meta(body)
		rich_text.add_text(body)
		rich_text.pop()
	else:
		rich_text.add_text(body)
	rich_text.tooltip_text = body
	rich_text.visible = StringUtils.is_not_blank(body)
	pass


static func create_body_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("default_color", Colors.secondary_text)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_font_override("normal_font", Fonts.regular())
	label.add_theme_font_size_override("normal_font_size", Typography.label_medium_size)
	label.meta_clicked.connect(MarkdownHelper.handle_meta_clicked)
	label.meta_hover_started.connect(handle_url_hover_started.bind(label))
	label.meta_hover_ended.connect(handle_url_hover_ended.bind(label))
	return label


static func handle_url_hover_started(_meta: Variant, label: RichTextLabel) -> void:
	label.add_theme_color_override("default_color", Colors.primary_text)
	pass


static func handle_url_hover_ended(_meta: Variant, label: RichTextLabel) -> void:
	label.add_theme_color_override("default_color", Colors.secondary_text)
	pass
