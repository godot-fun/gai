class_name PixelWeather
extends Node2D

var viewport_size := Vector2.ZERO
var pixel: float = 4.0
var elapsed: float = 0.0
var rain_intensity: float = 0.0


func update_visual(new_size: Vector2, new_pixel: float, new_elapsed: float, new_rain: float) -> void:
	viewport_size = new_size
	pixel = new_pixel
	elapsed = new_elapsed
	rain_intensity = new_rain
	queue_redraw()
	pass


func _draw() -> void:
	if rain_intensity <= 0.01:
		return
	var safe := Rect2(viewport_size.x * 0.22, viewport_size.y * 0.16, viewport_size.x * 0.56, viewport_size.y * 0.50)
	var count := int(40.0 + rain_intensity * 72.0)
	for index in range(count):
		var x := fposmod(PixelCity.stable_random(index, 41) * viewport_size.x + elapsed * (92.0 + PixelCity.stable_random(index, 43) * 54.0), viewport_size.x)
		var y := fposmod(PixelCity.stable_random(index, 47) * viewport_size.y + elapsed * (190.0 + PixelCity.stable_random(index, 53) * 130.0), viewport_size.y)
		var alpha := rain_intensity * 0.34
		if safe.has_point(Vector2(x, y)):
			alpha *= 0.22
		var start := Vector2(snappedf(x, pixel), snappedf(y, pixel))
		draw_line(start, start + Vector2(-pixel, pixel * 3.0), Color(0.49, 0.76, 0.96, alpha), pixel, false)
	pass
