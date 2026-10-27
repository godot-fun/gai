class_name PixelBridgeSegment
extends Node2D

var pixel: float = 4.0
var segment_width: float = 120.0
var segment_height: float = 120.0
var bridge_color := Color.WHITE
var elapsed: float = 0.0
var segment_index: int = 0


func configure(new_pixel: float, width: float, height: float, color: Color, new_elapsed: float, index: int) -> void:
	pixel = new_pixel
	segment_width = width
	segment_height = height
	bridge_color = color
	elapsed = new_elapsed
	segment_index = index
	queue_redraw()
	pass


func _draw() -> void:
	var alpha := 0.34 if ThemeColor.is_dark_theme() else 0.22
	draw_rect(Rect2(0.0, 0.0, segment_width + pixel, pixel * 4.0), Color(bridge_color, alpha))
	draw_rect(Rect2(0.0, pixel * 5.0, segment_width + pixel, pixel), Color(bridge_color, alpha * 0.74))
	draw_line(Vector2.ZERO, Vector2(segment_width * 0.5, segment_height), Color(bridge_color, alpha * 0.72), pixel, false)
	draw_line(Vector2(segment_width * 0.5, segment_height), Vector2(segment_width, 0.0), Color(bridge_color, alpha * 0.72), pixel, false)
	if segment_index % 3 == 0:
		draw_rect(Rect2(0.0, 0.0, pixel * 2.0, segment_height + pixel * 12.0), Color(bridge_color, alpha * 0.62))
	var pulse := 0.74 + 0.26 * sin(elapsed * 2.0 + float(segment_index) * 0.7)
	draw_rect(Rect2(0.0, -pixel * 3.0, pixel, pixel * 3.0), Color(bridge_color, 0.28))
	draw_rect(Rect2(-pixel, -pixel * 4.0, pixel * 3.0, pixel), Color(1.0, 0.76, 0.34, 0.48 * pulse))
	pass
