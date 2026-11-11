class_name ChatInputTheme
extends Object

## Theme styling and generated icons for the floating chat input.

const TRASH_ICON_PATH := "res://agent/asset/image/ui/delete.svg"
const RESUME_ICON_PATH := "res://agent/asset/image/ui/resume.svg"
static func apply_wrap(input_wrap: PanelContainer, expanded: bool) -> void:
	input_wrap.add_theme_stylebox_override("panel", build_wrap_style(expanded))
	pass


static func build_wrap_style(expanded: bool) -> StyleBoxFlat:
	var radius := ControlSize.radius_xxl if expanded else int(ControlSize.xl / 2)
	var wrap_style := StyleBoxHelper.create_style_box_flat(ThemeColor.demote(Colors.surface, Weights.w_3), radius, Margin.ma_1, Margin.ma_1)
	if ThemeColor.is_dark_theme():
		wrap_style.shadow_color = Color(0, 0, 0, 0.40)
		wrap_style.shadow_size = Margin.ma_4 if expanded else Margin.ma_3
		wrap_style.shadow_offset = Vector2(0, Margin.ma_2 if expanded else Margin.ma_1)
	else:
		wrap_style.shadow_color = Color(0, 0, 0, 0.08)
		wrap_style.shadow_size = Margin.ma_3 if expanded else Margin.ma_2
		wrap_style.shadow_offset = Vector2(0, Margin.ma_1 if expanded else ControlSize.radius_xs)
	return wrap_style


static func apply_field(input_field: CodeEdit) -> void:
	var input_style := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, 0, Margin.ma_3, Margin.ma_3)
	input_style.content_margin_right = Margin.ma_12
	input_field.add_theme_stylebox_override("normal", input_style)
	input_field.add_theme_stylebox_override("focus", input_style.duplicate())
	input_field.add_theme_stylebox_override("read_only", input_style.duplicate())
	CodeEditStyle.apply_base(input_field)
	input_field.add_theme_color_override("font_placeholder_color", Colors.secondary_text)
	input_field.add_theme_color_override("font_readonly_color", Colors.disabled_text)
	input_field.add_theme_color_override("font_selected_color", ThemeColor.title_color)
	input_field.syntax_highlighter = MarkdownHighlighter.create()
	input_field.caret_blink = true
	pass


## Themes the built-in `/skill` and `@file` completion list: same surface, radius and text colors as the
## composer so the popup does not look like an editor widget.
static func apply_completion(input_field: CodeEdit) -> void:
	var panel := StyleBoxHelper.create_style_box_flat(Colors.surface_container_high, ControlSize.radius_md,
		Margin.ma_2, Margin.ma_2)
	panel.border_color = Colors.outline
	panel.set_border_width(SIDE_LEFT, ControlSize.border_xs)
	panel.set_border_width(SIDE_TOP, ControlSize.border_xs)
	panel.set_border_width(SIDE_RIGHT, ControlSize.border_xs)
	panel.set_border_width(SIDE_BOTTOM, ControlSize.border_xs)
	panel.shadow_color = Color(0, 0, 0, 0.32 if ThemeColor.is_dark_theme() else 0.10)
	panel.shadow_size = Margin.ma_3
	panel.shadow_offset = Vector2(0, Margin.ma_1)
	input_field.add_theme_stylebox_override("completion", panel)
	input_field.add_theme_color_override("completion_background_color", Color.TRANSPARENT)
	input_field.add_theme_color_override("completion_existing_color", Color.TRANSPARENT)
	input_field.add_theme_color_override("completion_selected_color", ThemeColor.selected_surface)
	# [CodeEdit] paints the list scrollbar itself — there is no [ScrollBar] node for [method
	# ScrollBarStyle.apply] to reach — so reuse its thickness preset and grabber colors instead.
	input_field.add_theme_color_override("completion_scroll_color", ScrollBarStyle.grabber_color())
	input_field.add_theme_color_override("completion_scroll_hovered_color", ScrollBarStyle.grabber_hover_color())
	input_field.add_theme_constant_override("completion_scroll_width", DisplayScale.scale_int_floor_min(ScrollBarStyle.Thickness.MD, DisplayScale.get_ui_scale()))
	input_field.add_theme_constant_override("completion_lines", ChatInputCompletion.POPUP_ROWS)
	input_field.add_theme_constant_override("completion_max_width", ChatInputCompletion.POPUP_MAX_WIDTH)
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
	badge.add_theme_font_size_override("font_size", Typography.label_small)
	badge.add_theme_color_override("font_color", Color.WHITE)
	var badge_color := Colors.error.lerp(Colors.surface, 0.15)
	badge.add_theme_stylebox_override("normal", StyleBoxHelper.create_style_box_flat(
		badge_color, Margin.ma_2 + ControlSize.border_xs, 0, 0))
	pass


static func apply_queue_scroll(scroll: ScrollContainer) -> void:
	var empty := StyleBoxEmpty.new()
	scroll.add_theme_stylebox_override("panel", empty)
	ScrollBarStyle.apply_custom(scroll.get_v_scroll_bar(), ScrollBarStyle.Thickness.MD, ThemeColor.body_color, ThemeColor.promote(ThemeColor.theme_color, Weights.w_7), ThemeColor.promote(ThemeColor.theme_color, Weights.w_4))
	pass


static func apply_queue_row(row: PanelContainer, title: Label, header: bool, hovered: bool) -> void:
	var guide_color := Colors.outline_variant
	var fill := Colors.hover(Color.TRANSPARENT) if hovered else Color.TRANSPARENT
	var row_style := StyleBoxHelper.create_style_box_flat(fill, ControlSize.radius_md, Margin.ma_3, Margin.ma_1)
	row_style.border_color = guide_color
	row_style.set_border_width(SIDE_BOTTOM, ControlSize.border_xs)
	row.add_theme_stylebox_override("panel", row_style)
	title.add_theme_font_override("font", Fonts.semibold() if header else Fonts.regular())
	title.add_theme_color_override("font_color",
		Colors.primary_text if hovered or not header else Colors.secondary_text)
	pass


static func apply_queue_action_button(button: Button) -> void:
	button.text = ""
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ButtonStyle.apply_icon_button(button)
	pass


static func make_trash_icon(size: int, color: Color) -> ImageTexture:
	return ImageHelper.tint_svg(TRASH_ICON_PATH, color, float(size) / 16.0)


## Resume mark, same tint path as the delete icon.
static func make_resume_icon(size: int, color: Color) -> ImageTexture:
	return ImageHelper.tint_svg(RESUME_ICON_PATH, color, float(size) / 16.0)
