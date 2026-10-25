class_name ExplorerBubble
extends BubbleContainer

## Compact tool-call bubble for workspace exploration tools.


func panel_color() -> Color:
	return Colors.warning_surface


func apply(_session_id: int, entry: ChatEntry) -> void:
	apply_panel_style(panel_color())

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	var title_label := Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.warning)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	header.add_child(create_body_label(entry.body.strip_edges()))
	pass


func refresh(_entry: ChatEntry) -> void:
	pass


static func create_body_label(body: String) -> Label:
	var label := Label.new()
	label.text = body
	label.tooltip_text = body
	label.visible = StringUtils.is_not_blank(body)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_contents = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", Colors.secondary_text)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_font_override("font", Fonts.regular())
	label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	return label
