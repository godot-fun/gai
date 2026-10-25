class_name WebToolBubble
extends BubbleContainer

## Web-tool call bubble showing the query, URL, or primary argument sent to the tool.

func panel_color() -> Color:
	return Colors.info_surface


func apply(_session_id: int, entry: ChatEntry) -> void:
	apply_panel_style(panel_color())

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	var title_label := Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.info)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	var body := entry.body.strip_edges()
	if HttpUtils.is_valid_http_url(body):
		header.add_child(create_url_button(body))
	else:
		header.add_child(create_body_label(body))
	pass


func refresh(_entry: ChatEntry) -> void:
	pass


static func create_body_label(body: String) -> Label:
	var label := Label.new()
	label.text = body
	label.tooltip_text = body
	label.visible = StringUtils.is_not_blank(body)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Let the HBox constrain long text to the chat bubble instead of using its
	# full width as this control's minimum size.
	label.clip_contents = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", Colors.secondary_text)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_font_override("font", Fonts.regular())
	label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	return label


static func create_url_button(url: String) -> LinkButton:
	var button := LinkButton.new()
	button.text = url
	button.tooltip_text = url
	button.underline = LinkButton.UNDERLINE_MODE_NEVER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, Colors.primary_text)
	button.add_theme_font_override("font", Fonts.regular())
	button.add_theme_font_size_override("font_size", Typography.label_medium_size)
	button.pressed.connect(func() -> void: open_url(button.text))
	return button


static func open_url(url: String) -> void:
	if not HttpUtils.is_valid_http_url(url):
		return
	var error := OS.shell_open(url)
	if error != OK:
		Log.error("open link failed url:[{}] err:[{}]", url, error)
	pass
