@abstract
class_name BubbleContainer
extends PanelContainer

## Base control for transcript bubbles. Subclasses own their UI and refresh behavior.

@abstract
func apply(session_id: int, entry: ChatEntry) -> void


@abstract
func refresh(entry: ChatEntry) -> void


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass


func apply_panel_style(bg_color: Color) -> void:
	add_theme_stylebox_override("panel", create_panel_style(bg_color))
	pass


static func create_panel_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(bg_color, 8, Margin.ma_3, Margin.ma_3)
	if ThemeColor.is_light_theme():
		style.border_color = Colors.border
		style.set_border_width_all(ControlSize.border_xs)
		style.shadow_color = Color(0, 0, 0, 0.04)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 2)
	return style


## Applies the shared appearance for bubble header actions such as Copy, Delete, and Revert.
static func style_header_button(button: Button, bubble_bg: Color, tooltip: String, min_width: float) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(min_width, 18)
	button.add_theme_font_size_override("font_size", Typography.label_small_size)

	var theme_color: Color = ThemeColor.accent_theme_color()
	ButtonStyle.apply_font_colors(button, theme_color, ThemeColor.promote(theme_color, 0.12), ThemeColor.demote(theme_color, 0.10))

	var normal := StyleBoxHelper.create_style_box_flat(bubble_bg, 4, Margin.ma_2, Margin.ma_0, ThemeColor.alpha_theme_color(0.45), ControlSize.border_xs)
	ButtonStyle.apply(button, normal,
		ButtonStyle.filled(normal, ThemeColor.selected_surface, ThemeColor.alpha_theme_color(0.85)),
		ButtonStyle.filled(normal, ThemeColor.promote(ThemeColor.selected_surface, 0.06), theme_color))
	pass
