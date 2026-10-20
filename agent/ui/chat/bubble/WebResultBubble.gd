class_name WebResultBubble
extends BubbleContainer

var rich_text: RichTextLabel

## Web-tool result bubble with a text preview and an optional browser screenshot.


func apply(_session_id: int, entry: ChatEntry) -> void:
	apply_background(Colors.neutral_surface)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	add_child(vbox)

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

	rich_text = MarkdownHelper.create_plain_rich_text_label(Colors.secondary_text)
	vbox.add_child(rich_text)
	append_screenshot(vbox, entry)

	refresh(entry)
	pass


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(rich_text) or entry == null:
		return
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
	var preview_width := 1024.0
	var preview_height := preview_width * float(screenshot.get_height()) / float(screenshot.get_width())
	var preview := TextureRect.new()
	var preview_texture := ImageTexture.create_from_image(screenshot)
	preview.texture = preview_texture
	preview.custom_minimum_size = Vector2(preview_width, preview_height)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.tooltip_text = screenshot_path
	preview.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	preview.gui_input.connect(func(event: InputEvent) -> void: on_screenshot_input(event, screenshot_path, preview_texture))
	parent.add_child(preview)
	pass


static func on_screenshot_input(event: InputEvent, screenshot_path: String, texture: Texture2D) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
		ImagePreviewWindow.show_image(texture, screenshot_path.get_file())
	pass
