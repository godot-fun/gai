class_name FileBubble
extends Object

## File-change result bubble with added/removed line counts.


static func append(chat_list: VBoxContainer, entry: ChatEntry, panel_style: StyleBoxFlat) -> RichTextLabel:
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
	title_label.add_theme_color_override("font_color", ColorBase.warning)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	var file_path: String = entry.details.get(AgentToolResult.DETAIL_FILE_PATH, "")
	var file_lines_added: int = int(entry.details.get(AgentToolResult.DETAIL_FILE_LINES_ADDED, "0"))
	var file_lines_removed: int = int(entry.details.get(AgentToolResult.DETAIL_FILE_LINES_REMOVED, "0"))
	var file_message: String = entry.details.get(AgentToolResult.DETAIL_FILE_MESSAGE, "")
	if file_lines_added > 0:
		header.add_child(create_file_detail_label(StringUtils.format("+{}", file_lines_added), ColorBase.success))
	if file_lines_removed > 0:
		header.add_child(create_file_detail_label(StringUtils.format("-{}", file_lines_removed), ColorBase.error))
	if StringUtils.is_not_blank(file_message):
		header.add_child(create_file_detail_label(file_message, ColorBase.error))
	if StringUtils.is_not_blank(file_path):
		header.add_child(create_file_path_button(file_path))
	vbox.add_child(header)

	var rich_text: RichTextLabel = RichTextLabel.new()
	rich_text.visible = false
	vbox.add_child(rich_text)
	wrapper.set_meta(AgentChatView.META_BUBBLE_RICH_TEXT, rich_text)

	chat_list.add_child(wrapper)
	# refresh(rich_text, entry)
	return rich_text


static func refresh(rich_text: RichTextLabel, entry: ChatEntry) -> void:
	rich_text.clear()
	rich_text.push_meta(entry.body)
	rich_text.add_text(entry.body)
	rich_text.pop()
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	pass


static func open_file(meta: Variant) -> void:
	var path: String = str(meta)
	if FileUtils.open_file(path) != OK:
		Alert.alert(StringUtils.format("File not found: {}", path), ColorBase.error)
	pass


static func create_file_detail_label(text: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", Typography.label_small_size)
	return label


static func create_file_path_button(file_path: String) -> LinkButton:
	var button: LinkButton = LinkButton.new()
	button.text = file_path
	button.tooltip_text = "Open file"
	button.underline = LinkButton.UNDERLINE_MODE_NEVER
	ButtonStyle.apply_font_colors(button, ColorBase.secondary_text, ColorBase.primary_text, ColorBase.primary_text)
	button.add_theme_font_override("font", Fonts.regular())
	button.add_theme_font_size_override("font_size", Typography.label_medium_size)
	button.pressed.connect(open_file.bind(file_path))
	return button
