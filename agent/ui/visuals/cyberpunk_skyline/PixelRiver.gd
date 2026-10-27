class_name PixelRiver
extends Node2D

var viewport_size := Vector2.ZERO
var pixel: float = 4.0
var camera_x: float = 0.0
var elapsed: float = 0.0
var daylight: float = 0.0
var rain_intensity: float = 0.0
var reasoning_energy: float = 0.0


func update_visual(new_size: Vector2, new_pixel: float, new_camera_x: float, new_elapsed: float, new_daylight: float, new_rain: float, new_reasoning: float) -> void:
	viewport_size = new_size
	pixel = new_pixel
	camera_x = new_camera_x
	elapsed = new_elapsed
	daylight = new_daylight
	rain_intensity = new_rain
	reasoning_energy = new_reasoning
	queue_redraw()
	pass


func _draw() -> void:
	var river_top := viewport_size.y * PixelCity.RIVER_TOP_RATIO
	var water_color := Color("12344d").lerp(Color("287895"), daylight * 0.55)
	draw_rect(Rect2(0.0, river_top, viewport_size.x, viewport_size.y - river_top), Color(water_color, 0.12 + rain_intensity * 0.035))
	var line_count := floori((viewport_size.y - river_top) / (pixel * 3.0))
	for row in range(line_count):
		var y := river_top + float(row) * pixel * 3.0
		var perspective := float(row) / float(maxi(line_count - 1, 1))
		var flow := elapsed * (9.0 + perspective * 28.0)
		var offset := fposmod(flow - camera_x * 0.35 + float(row * 31), pixel * 18.0)
		var alpha := 0.07 + perspective * 0.09 + rain_intensity * 0.06
		for segment in range(ceili(viewport_size.x / (pixel * 18.0)) + 1):
			var x := float(segment) * pixel * 18.0 + offset - pixel * 18.0
			var length := pixel * (5.0 + float((row + segment) % 6))
			draw_rect(Rect2(x, snappedf(y, pixel), length, pixel), Color(0.42, 0.76, 0.89, alpha))
	draw_reflections(river_top)
	pass


func draw_reflections(river_top: float) -> void:
	if not should_draw_reflections():
		return
	for index in range(20):
		var x := fposmod(PixelCity.stable_random(index, 79) * viewport_size.x - camera_x * 0.24, viewport_size.x)
		var width := pixel * (1.0 + float(index % 3))
		var height := pixel * (5.0 + PixelCity.stable_random(index, 83) * 19.0)
		var color := Color(1.0, 0.66, 0.26, (1.0 - daylight * 0.62) * 0.15)
		draw_rect(Rect2(x, river_top + pixel * 2.0, width, height), color)
	pass


func should_draw_reflections() -> bool:
	return ThemeColor.is_dark_theme()
