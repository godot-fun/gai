class_name AgentChatInputTheme
extends Object

## Theme styling and generated icons for the floating chat input.

const TRASH_ICON_PATH := "res://agent/asset/image/icon/trash.svg"
const RESUME_ICON_PATH := "res://agent/asset/image/icon/resume.svg"

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


static func apply_send_button(send_button: Button, stop_action: bool, show_activity: bool,
		compacting: bool) -> void:
	var show_shader_effect := not show_activity
	var base_color := Color.TRANSPARENT if show_shader_effect else ThemeColor.accent_theme_color()
	var radius: int = int(ControlSize.md * 0.5)
	var normal := StyleBoxHelper.create_style_box_flat(base_color, radius, Margin.ma_1, Margin.ma_1)
	ButtonStyle.apply(send_button, normal,
		ButtonStyle.filled(normal, base_color.lightened(0.10)),
		ButtonStyle.filled(normal, base_color.darkened(0.08)),
		ButtonStyle.filled(normal, base_color.darkened(0.25)))
	send_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	send_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	send_button.disabled = compacting
	if show_activity:
		send_button.text = ""
		send_button.tooltip_text = I18n.t("agent.input.compacting") if compacting else I18n.t("agent.visuals.running")
		send_button.icon = null
		return
	send_button.text = ""
	send_button.tooltip_text = I18n.t("agent.input.stop") if stop_action else I18n.t("agent.input.send")
	send_button.icon = null
	pass


static func apply_queue_badge(badge: Label, collapsed: bool, queue_count: int) -> void:
	badge.visible = collapsed and queue_count > 0
	if not badge.visible:
		return
	badge.text = "9+" if queue_count > 9 else str(queue_count)
	badge.add_theme_font_override("font", Fonts.semibold())
	badge.add_theme_font_size_override("font_size", Typography.label_small_size)
	badge.add_theme_color_override("font_color", Color.WHITE)
	var badge_color := ColorBase.error.lerp(ColorBase.surface, 0.15)
	badge.add_theme_stylebox_override("normal", StyleBoxHelper.create_style_box_flat(
		badge_color, Margin.ma_2 + 1, 0, 0))
	pass


static func apply_queue_delete_button(delete_button: Button) -> void:
	AgentToolbarButton.style_round(delete_button, delete_button.tooltip_text)
	delete_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_button.icon = make_trash_icon(ControlSize.xs, ThemeColor.accent_theme_color())
	pass


static func apply_queue_continue_button(continue_button: Button) -> void:
	AgentToolbarButton.style_round(continue_button, continue_button.tooltip_text)
	continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	continue_button.icon = make_resume_icon(ControlSize.xs, ThemeColor.accent_theme_color())
	pass


static func make_trash_icon(size: int, color: Color) -> ImageTexture:
	return make_tint_svg_icon(TRASH_ICON_PATH, size, color)


## Stroke resume mark (bar + triangle), same line weight as trash.
static func make_resume_icon(size: int, color: Color) -> ImageTexture:
	return make_tint_svg_icon(RESUME_ICON_PATH, size, color)


static func make_tint_svg_icon(path: String, size: int, color: Color) -> ImageTexture:
	var svg := FileAccess.get_file_as_string(path)
	svg = svg.replace("#" + Color.WHITE.to_html(false), "#" + color.to_html(false))
	var image := Image.new()
	if image.load_svg_from_string(svg, float(size) / 16.0) != OK:
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)
