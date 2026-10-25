@abstract
class_name BubbleContainer
extends PanelContainer

## Base control for transcript bubbles. Subclasses own their UI and refresh behavior.

@abstract
func apply(session_id: int, entry: ChatEntry) -> void


@abstract
func refresh(entry: ChatEntry) -> void


## Stable card background for this bubble; flash highlight restores to this instead of reading StyleBox mid-tween.
@abstract
func panel_color() -> Color


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass


func apply_panel_style(bg_color: Color) -> void:
	add_theme_stylebox_override("panel", create_panel_style(bg_color))
	pass


## Panel that receives the pulse; override when the visible card is not [code]self[/code] (e.g. [UserBubble]).
func flash_panel() -> PanelContainer:
	return self


## Pulses the panel background when this bubble is scrolled into view (e.g. chat search jump).
func flash_highlight() -> void:
	var panel := flash_panel()
	var base_color := panel_color()
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	var apply_pulse := func(weight: float) -> void: style.bg_color = base_color.lerp(Colors.warning, weight)
	var tween := panel.create_tween()
	for _i in 4:
		tween.tween_method(apply_pulse, 0.0, 0.6, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_method(apply_pulse, 0.6, 0.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
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
	ButtonStyle.apply_font_colors(button, theme_color, ThemeColor.promote(theme_color, Weights.w_2), ThemeColor.demote(theme_color, Weights.w_2))

	var normal := StyleBoxHelper.create_style_box_flat(bubble_bg, 4, Margin.ma_2, Margin.ma_0, ThemeColor.alpha_theme_color(0.45), ControlSize.border_xs)
	ButtonStyle.apply_style(button, normal)
	pass
