class_name AgentChatInputTheme
extends Object

## Theme styling and generated icons for the floating chat input.

const TRASH_ICON_PATH := "res://agent/asset/image/icon/trash.svg"

static func apply_wrap(input_wrap: PanelContainer, expanded: bool) -> void:
	input_wrap.add_theme_stylebox_override("panel", build_wrap_style(expanded))
	pass


static func build_wrap_style(expanded: bool) -> StyleBoxFlat:
	var radius := 16 if expanded else int(ControlSize.xl / 2)
	var wrap_style := StyleBoxHelper.create_style_box_flat(ColorBase.surface, radius, Margin.ma_1, Margin.ma_1)
	if ThemeColor.is_dark_theme():
		wrap_style.shadow_color = Color(0, 0, 0, 0.40)
		wrap_style.shadow_size = 16 if expanded else 10
		wrap_style.shadow_offset = Vector2(0, 6 if expanded else 4)
	else:
		wrap_style.shadow_color = Color(0, 0, 0, 0.08)
		wrap_style.shadow_size = 12 if expanded else 8
		wrap_style.shadow_offset = Vector2(0, 4 if expanded else 2)
	return wrap_style


static func apply_field(input_field: TextEdit) -> void:
	var input_style := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, 0, Margin.ma_3, Margin.ma_3)
	input_style.content_margin_right = Margin.ma_13
	input_field.add_theme_stylebox_override("normal", input_style)
	input_field.add_theme_stylebox_override("focus", input_style.duplicate())
	input_field.add_theme_stylebox_override("read_only", input_style.duplicate())
	input_field.add_theme_font_override("font", Fonts.regular())
	input_field.add_theme_color_override("font_color", ColorBase.primary_text)
	input_field.add_theme_color_override("font_placeholder_color", ColorBase.secondary_text)
	input_field.add_theme_color_override("font_readonly_color", ColorBase.secondary_text)
	input_field.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	input_field.add_theme_color_override("font_selected_color", ThemeColor.title_color)
	input_field.add_theme_color_override("selection_color", ThemeColor.selection_color)
	ScrollBarStyle.apply(input_field.get_v_scroll_bar())
	ScrollBarStyle.apply(input_field.get_h_scroll_bar())
	input_field.caret_blink = true
	pass


static func apply_send_button(send_button: Button, stop_action: bool = false) -> void:
	var base_color := ColorBase.error if stop_action else ThemeColor.accent_theme_color()
	send_button.tooltip_text = I18n.t("agent.input.stop") if stop_action else I18n.t("agent.input.send")
	var icon_size := ControlSize.xs
	send_button.icon = make_stop_icon(icon_size, Color.WHITE) if stop_action else make_arrow_up_icon(icon_size, Color.WHITE)
	send_button.add_theme_constant_override("icon_max_width", icon_size)
	send_button.add_theme_constant_override("icon_max_height", icon_size)
	var radius: int = int(ControlSize.md * 0.5)
	var normal := StyleBoxHelper.create_style_box_flat(base_color, radius, Margin.ma_1, Margin.ma_1)
	ButtonStyle.apply(send_button, normal,
		ButtonStyle.filled(normal, base_color.lightened(0.10)),
		ButtonStyle.filled(normal, base_color.darkened(0.08)),
		ButtonStyle.filled(normal, base_color.darkened(0.25)))
	send_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pass


static func apply_queue_delete_button(delete_button: Button) -> void:
	AgentToolbarButton.style_round(delete_button, delete_button.tooltip_text)
	delete_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon_size := ControlSize.xs
	delete_button.icon = make_trash_icon(icon_size, ThemeColor.accent_theme_color())
	delete_button.add_theme_constant_override("icon_max_width", icon_size)
	delete_button.add_theme_constant_override("icon_max_height", icon_size)
	delete_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pass


static func apply_queue_continue_button(continue_button: Button) -> void:
	AgentToolbarButton.style(continue_button, I18n.t("agent.input.continue_queue"))
	continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pass


static func make_trash_icon(size: int, color: Color) -> ImageTexture:
	var svg := FileAccess.get_file_as_string(TRASH_ICON_PATH)
	svg = svg.replace("#ffffff", "#" + color.to_html(false))
	var image := Image.new()
	if image.load_svg_from_string(svg, float(size) / 16.0) != OK:
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)


static func make_arrow_up_icon(size: int, color: Color) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: int = size / 2
	var top: int = int(size * 0.12)
	var bottom: int = int(size * 0.72)
	var half_w: int = int(size * 0.34)
	for y in range(top, bottom + 1):
		var progress: float = float(y - top) / float(bottom - top)
		var half_width: int = int(float(half_w) * progress)
		for x in range(cx - half_width, cx + half_width + 1):
			img.set_pixel(x, y, color)
	var stem_w: int = maxi(1, int(size * 0.12))
	var stem_left: int = cx - stem_w / 2
	var stem_right: int = stem_left + stem_w - 1
	for y in range(bottom, size):
		for x in range(stem_left, stem_right + 1):
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func make_stop_icon(size: int, color: Color) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var square_size: int = maxi(4, int(size * 0.56))
	var left: int = (size - square_size) / 2
	var top: int = (size - square_size) / 2
	for y in range(top, top + square_size):
		for x in range(left, left + square_size):
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
