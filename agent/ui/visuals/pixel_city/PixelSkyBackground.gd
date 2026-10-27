class_name PixelSkyBackground
extends Node2D

var viewport_size := Vector2.ZERO
var daylight: float = 0.0
var rain_intensity: float = 0.0


func update_visual(new_size: Vector2, new_daylight: float, new_rain: float) -> void:
	viewport_size = new_size
	daylight = new_daylight
	rain_intensity = new_rain
	queue_redraw()
	pass


func _draw() -> void:
	var night_color := Color("101a35") if ThemeColor.is_dark_theme() else Color("72829d")
	var day_color := Color("5ba8d1") if ThemeColor.is_dark_theme() else Color("4b7894")
	var sky_color := night_color.lerp(day_color, daylight).darkened(rain_intensity * 0.18)
	draw_rect(Rect2(Vector2.ZERO, Vector2(viewport_size.x, viewport_size.y * PixelCity.RIVER_TOP_RATIO)), Color(sky_color, 0.075))
	pass
