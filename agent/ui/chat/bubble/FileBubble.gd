class_name FileBubble
extends BubbleContainer

## File-change result bubble with added/removed line counts.


func apply(_session_id: int, entry: ChatEntry) -> void:
	apply_panel_style(Colors.warning_surface)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	var title_label := Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.warning)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	var file_path: String = entry.details.get(AgentToolResult.DETAIL_FILE_PATH, "")
	var file_lines_added: int = int(entry.details.get(AgentToolResult.DETAIL_FILE_LINES_ADDED, "0"))
	var file_lines_removed: int = int(entry.details.get(AgentToolResult.DETAIL_FILE_LINES_REMOVED, "0"))
	var file_message: String = entry.details.get(AgentToolResult.DETAIL_FILE_MESSAGE, "")
	if file_lines_added > 0:
		header.add_child(create_file_detail_label(StringUtils.format("+{}", file_lines_added), Colors.success))
	if file_lines_removed > 0:
		header.add_child(create_file_detail_label(StringUtils.format("-{}", file_lines_removed), Colors.error))
	if StringUtils.is_not_blank(file_message):
		header.add_child(create_file_detail_label(file_message, Colors.error))
	if StringUtils.is_not_blank(file_path):
		header.add_child(create_file_path_button(file_path))
	pass


func refresh(_entry: ChatEntry) -> void:
	pass


static func open_file(path: String) -> void:
	if FileUtils.open_file(path) != OK:
		Alert.alert(StringUtils.format(I18n.t("common.file_not_found"), path), Colors.error)
	pass


static func create_file_detail_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", Typography.label_small_size)
	return label


static func create_file_path_button(file_path: String) -> LinkButton:
	var button := LinkButton.new()
	button.text = file_path
	button.tooltip_text = file_path
	button.underline = LinkButton.UNDERLINE_MODE_NEVER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, Colors.primary_text)
	button.add_theme_font_override("font", Fonts.regular())
	button.add_theme_font_size_override("font_size", Typography.label_medium_size)
	button.pressed.connect(open_file.bind(file_path))
	return button
