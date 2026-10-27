class_name PixelVehicle
extends Node2D

var tool_call_id: String = ""
var lane: int = 0
var progress: float = 0.0
var speed: float = 0.0
var result: int = PixelCity.VehicleResult.RUNNING
var exiting: bool = false
var seed: int = 0
var pixel: float = 4.0


func update_layout(viewport_size: Vector2, new_pixel: float) -> void:
	pixel = new_pixel
	var x := lerpf(-pixel * 14.0, viewport_size.x + pixel * 14.0, progress)
	var road_y := snappedf(viewport_size.y * PixelCity.BRIDGE_TOP_RATIO + pixel * 7.0, pixel)
	var lane_offset := pixel * (1.0 + float(lane) * 2.0)
	position = Vector2(x, snappedf(road_y - pixel * 2.0 + lane_offset, pixel))
	queue_redraw()
	pass


func _draw() -> void:
	var color := ThemeColor.accent_theme_color()
	if result == PixelCity.VehicleResult.SUCCESS:
		color = Colors.success
	elif result == PixelCity.VehicleResult.FAILED:
		color = Colors.error
	var length := pixel * (8.0 + float(seed % 5))
	draw_rect(Rect2(0.0, 0.0, length, pixel * 2.0), Color(color, 0.78))
	draw_rect(Rect2(pixel * 2.0, -pixel, length * 0.48, pixel), Color(color, 0.50))
	draw_rect(Rect2(length, 0.0, pixel * 2.0, pixel), Color(1.0, 0.82, 0.42, 0.68))
	pass
