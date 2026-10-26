class_name ChatInputTheme
extends Object

## Theme styling and generated icons for the floating chat input.

const TRASH_ICON_PATH := "res://agent/asset/image/icon/trash.svg"
const RESUME_ICON_PATH := "res://agent/asset/image/icon/resume.svg"

static func apply_wrap(input_wrap: PanelContainer, expanded: bool) -> void:
	input_wrap.add_theme_stylebox_override("panel", build_wrap_style(expanded))
	pass


static func build_wrap_style(expanded: bool) -> StyleBoxFlat:
	var radius := 16 if expanded else int(ControlSize.xl / 2)
	var wrap_style := StyleBoxHelper.create_style_box_flat(Colors.surface, radius, Margin.ma_1, Margin.ma_1)
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
	input_style.content_margin_right = Margin.ma_12
	input_field.add_theme_stylebox_override("normal", input_style)
	input_field.add_theme_stylebox_override("focus", input_style.duplicate())
	input_field.add_theme_stylebox_override("read_only", input_style.duplicate())
	input_field.add_theme_font_override("font", Fonts.regular())
	input_field.add_theme_color_override("font_color", Colors.primary_text)
	input_field.add_theme_color_override("font_placeholder_color", Colors.secondary_text)
	input_field.add_theme_color_override("font_readonly_color", Colors.secondary_text)
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
	ButtonStyle.apply_style(send_button, normal,
		StyleBoxHelper.duplicate_with_bg_color(normal, base_color.lightened(0.10)),
		StyleBoxHelper.duplicate_with_bg_color(normal, base_color.darkened(0.08)))
	send_button.add_theme_stylebox_override("disabled", StyleBoxHelper.duplicate_with_bg_color(normal, base_color.darkened(0.25)))
	send_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	send_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	send_button.disabled = compacting
	if show_activity:
		send_button.text = ""
		send_button.tooltip_text = I18n.t("agent.tokens.compacting") if compacting else I18n.t("agent.visuals.running")
		send_button.icon = null
		return
	send_button.text = ""
	send_button.tooltip_text = I18n.t("common.stop") if stop_action else I18n.t("agent.input.send")
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
	var badge_color := Colors.error.lerp(Colors.surface, 0.15)
	badge.add_theme_stylebox_override("normal", StyleBoxHelper.create_style_box_flat(
		badge_color, Margin.ma_2 + 1, 0, 0))
	pass


static func apply_queue_scroll(scroll: ScrollContainer) -> void:
	var empty := StyleBoxEmpty.new()
	scroll.add_theme_stylebox_override("panel", empty)
	ScrollBarStyle.apply_custom(scroll.get_v_scroll_bar(), ScrollBarStyle.Thickness.MD, ThemeColor.body_color, ThemeColor.promote(ThemeColor.theme_color, Weights.w_7), ThemeColor.promote(ThemeColor.theme_color, Weights.w_4))
	pass


static func apply_queue_row(row: PanelContainer, title: Label, header: bool, hovered: bool) -> void:
	var guide_color := Color(Colors.border, 0.65)
	var row_style := StyleBoxHelper.create_style_box_flat(Colors.hover_surface if hovered else Color.TRANSPARENT, ControlSize.radius_md, Margin.ma_3, Margin.ma_1)
	row_style.border_color = guide_color
	row_style.set_border_width(SIDE_BOTTOM, ControlSize.border_xs)
	row.add_theme_stylebox_override("panel", row_style)
	title.add_theme_font_override("font", Fonts.semibold() if header else Fonts.regular())
	title.add_theme_color_override("font_color",
		Colors.primary_text if hovered or not header else Colors.secondary_text)
	pass


static func apply_queue_action_button(button: Button) -> void:
	button.text = ""
	button.custom_minimum_size = ControlSize.square(ControlSize.sm)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.flat = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", ControlSize.icon_md)
	button.add_theme_constant_override("icon_max_height", ControlSize.icon_md)
	var normal := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, ControlSize.sm / 2, Margin.ma_1, Margin.ma_1)
	ButtonStyle.apply_style(button, normal,
		StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.selected_surface),
		StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.selected_surface.lerp(ThemeColor.accent_theme_color(), Weights.w_2)))
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
