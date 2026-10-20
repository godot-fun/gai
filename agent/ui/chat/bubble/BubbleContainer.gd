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


func apply_panel_style(bg_color: Color = Color.TRANSPARENT) -> void:
	var style: StyleBox = StyleBoxEmpty.new() if bg_color == Color.TRANSPARENT else create_panel_style(bg_color)
	add_theme_stylebox_override("panel", style)
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
