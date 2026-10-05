class_name OrbColorController
extends RefCounted

## Smooth display_color → target_color blend for phase tint changes (~0.65s).

const BLEND_SPEED := 4.2

var display_color: Color = Color(0.0, 0.9, 1.0, 1.0)
var target_color: Color = Color(0.0, 0.9, 1.0, 1.0)


func set_target(color: Color) -> void:
	target_color = color
	pass


func snap_to(color: Color) -> void:
	display_color = color
	target_color = color
	pass


func update(delta: float) -> void:
	if display_color.is_equal_approx(target_color):
		display_color = target_color
		return
	var blend := clampf(delta * BLEND_SPEED, 0.0, 1.0)
	display_color = display_color.lerp(target_color, blend)
	pass
