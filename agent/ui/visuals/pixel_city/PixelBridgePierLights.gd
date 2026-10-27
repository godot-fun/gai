class_name PixelBridgePierLights
extends Node2D

var pixel: float = 4.0
var bridge_color := Color.WHITE
var lamp_center := Vector2.ZERO
var light_post_rect := Rect2()
var light_pulse: float = 1.0
var glow_scale: float = 1.0
var lamp_tint := Color(1.0, 0.76, 0.34, 1.0)
var active := false


func sync_visual(new_pixel: float, new_bridge_color: Color, new_lamp_center: Vector2, new_post_rect: Rect2, pulse: float, lamp: Color, pier_active: bool, new_glow_scale: float) -> void:
	pixel = new_pixel
	bridge_color = new_bridge_color
	lamp_center = new_lamp_center
	light_post_rect = new_post_rect
	light_pulse = pulse
	glow_scale = new_glow_scale
	lamp_tint = lamp
	active = pier_active
	visible = pier_active
	queue_redraw()
	pass


func _draw() -> void:
	if not active:
		return
	draw_rect(light_post_rect, Color(bridge_color, 0.28))
	var bloom_base := 0.095 if ThemeColor.is_dark_theme() else 0.068
	var ring_count := 4
	for ring in range(ring_count, 0, -1):
		var radius := pixel * (0.72 + float(ring) * 0.78) * glow_scale
		var ring_alpha := bloom_base * light_pulse * (float(ring) / float(ring_count))
		draw_circle(lamp_center, radius, VisualColor.stroke(lamp_tint, ring_alpha))
	var lamp_size := Vector2(pixel * 3.0, pixel)
	var lamp_rect := Rect2(lamp_center - lamp_size * 0.5, lamp_size)
	draw_rect(lamp_rect, Color(lamp_tint, 0.78 + 0.14 * light_pulse))
	draw_rect(lamp_rect.grow(-pixel * 0.25), Color(1.0, 0.92, 0.72, 0.35 + 0.28 * light_pulse))
	pass
