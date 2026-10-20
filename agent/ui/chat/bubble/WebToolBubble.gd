class_name WebToolBubble
extends BubbleContainer

var body_label: RichTextLabel

## Web-tool call bubble showing the query, URL, or primary argument sent to the tool.

func apply(_session_id: int, entry: ChatEntry) -> void:
	apply_background(Colors.info_surface)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.info)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	var body := entry.body.strip_edges()
	if HttpUtils.is_valid_http_url(body):
		header.add_child(create_url_button(body))
	else:
		body_label = create_body_label()
		header.add_child(body_label)
	vbox.add_child(header)

	refresh(entry)
	pass


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(body_label) or entry == null:
		return
	var body := entry.body.strip_edges()
	body_label.clear()
	body_label.add_text(body)
	body_label.tooltip_text = body
	body_label.visible = StringUtils.is_not_blank(body)
	pass


static func create_body_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Let the HBox constrain long text to the chat bubble instead of using its
	# full width as this control's minimum size.
	label.fit_content = false
	label.clip_contents = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("default_color", Colors.secondary_text)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_font_override("normal_font", Fonts.regular())
	label.add_theme_font_size_override("normal_font_size", Typography.label_medium_size)
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
