class_name PixelRiver
extends Node2D

const FLOW_LINE_TOP_INSET := 2.0

var viewport_size := Vector2.ZERO
var pixel: float = 4.0
var camera_x: float = 0.0
var elapsed: float = 0.0
var daylight: float = 0.0
var rain_intensity: float = 0.0
var reasoning_energy: float = 0.0

var synced_shader_pixel := 0.0
var synced_shader_wave := 0.0
var synced_shader_daylight := 0.0
var synced_shader_rain := 0.0


func update_visual(new_size: Vector2, new_pixel: float, new_camera_x: float, new_elapsed: float, new_daylight: float, new_rain: float, new_reasoning: float) -> void:
	viewport_size = new_size
	pixel = new_pixel
	camera_x = new_camera_x
	elapsed = new_elapsed
	daylight = new_daylight
	rain_intensity = new_rain
	reasoning_energy = new_reasoning
	sync_shader_uniforms()
	queue_redraw()
	pass


func sync_shader_uniforms() -> void:
	var river_material := material as ShaderMaterial
	if river_material == null:
		return
	var wave_strength := pixel * (0.18 + rain_intensity * 0.12 + reasoning_energy * 0.06)
	if is_equal_approx(pixel, synced_shader_pixel) and is_equal_approx(wave_strength, synced_shader_wave) and is_equal_approx(daylight, synced_shader_daylight) and is_equal_approx(rain_intensity, synced_shader_rain):
		return
	synced_shader_pixel = pixel
	synced_shader_wave = wave_strength
	synced_shader_daylight = daylight
	synced_shader_rain = rain_intensity
	river_material.set_shader_parameter("pixel_size", pixel)
	river_material.set_shader_parameter("wave_strength", wave_strength)
	river_material.set_shader_parameter("daylight", daylight)
	river_material.set_shader_parameter("rain_intensity", rain_intensity)
	pass


func _draw() -> void:
	var river_top := snappedf(viewport_size.y * PixelCity.RIVER_TOP_RATIO, pixel)
	var water_color := Color("12344d").lerp(Color("287895"), daylight * 0.55)
	var water_alpha := 0.12 + rain_intensity * 0.035
	draw_rect(Rect2(0.0, river_top, viewport_size.x, viewport_size.y - river_top), Color(water_color, water_alpha))
	draw_rect(Rect2(0.0, river_top, viewport_size.x, pixel), Color(water_color, minf(water_alpha * 1.35, 0.2)))
	var flow_top := river_top + pixel * FLOW_LINE_TOP_INSET
	var row_stride := pixel * 3.0
	var line_count := maxi(0, floori((viewport_size.y - flow_top) / row_stride))
	var period := pixel * 18.0
	for row in range(line_count):
		var y := flow_top + float(row) * row_stride
		var perspective := float(row) / float(maxi(line_count - 1, 1))
		var flow := elapsed * (9.0 + perspective * 28.0)
		var scroll := flow - camera_x * 0.35 + float(row * 31)
		var alpha := 0.07 + perspective * 0.09 + rain_intensity * 0.06
		var first_segment := int(floor((0.0 - scroll) / period)) - 1
		var last_segment := int(floor((viewport_size.x - scroll) / period)) + 1
		for segment in range(first_segment, last_segment + 1):
			var x := scroll + float(segment) * period
			var length := pixel * (5.0 + float(posmod(segment + row, 6)))
			if x + length < 0.0 or x > viewport_size.x:
				continue
			var line_y := maxf(snappedf(y, pixel), flow_top)
			draw_rect(Rect2(x, line_y, length, pixel), Color(0.42, 0.76, 0.89, alpha))
	draw_city_reflections(river_top)
	draw_bridge_reflections()
	pass


func draw_city_reflections(river_top: float) -> void:
	if not should_draw_reflections():
		return
	for index in range(20):
		var x := fposmod(PixelCity.stable_random(index, 79) * viewport_size.x - camera_x * 0.24, viewport_size.x)
		var height := pixel * (5.0 + PixelCity.stable_random(index, 83) * 19.0)
		var segment_count := floori(height / (pixel * 2.0))
		for segment in range(segment_count):
			if (segment + index) % 4 == 3:
				continue
			var depth := float(segment) / float(maxi(segment_count - 1, 1))
			var wave := sin(elapsed * 0.72 + float(segment) * 1.17 + float(index) * 0.61)
			var segment_x := x + wave * pixel * (0.18 + depth * 0.34)
			var width := pixel * (1.0 + float((index + segment) % 3))
			var alpha := (1.0 - daylight * 0.62) * lerpf(0.15, 0.035, depth)
			draw_rect(Rect2(segment_x, river_top + pixel * (2.0 + float(segment) * 2.0), width, pixel), Color(1.0, 0.66, 0.26, alpha))
	pass


func draw_bridge_reflections() -> void:
	if not should_draw_reflections():
		return
	var spacing := pixel * 20.0
	var layer_camera := camera_x * PixelBridgeLayer.PARALLAX_FACTOR
	var road_y := snappedf(viewport_size.y * PixelCity.BRIDGE_TOP_RATIO + pixel * 7.0, pixel)
	var reflection_rows := maxi(1, floori((viewport_size.y - road_y) / (pixel * 4.0)))
	var first_light := int(floor((0.0 - layer_camera) / spacing)) - 1
	var last_light := int(floor((viewport_size.x - layer_camera) / spacing)) + 1
	var reflection_color := VisualColor.appearance_color(ThemeColor.accent_theme_color(), 0.03, 0.82, 0.92)
	for index in range(first_light, last_light + 1):
		var x := layer_camera + float(index) * spacing
		for row in range(reflection_rows):
			if (row + index) % 3 == 2:
				continue
			var depth := float(row) / float(maxi(reflection_rows - 1, 1))
			var wave := sin(elapsed * 0.66 + float(row) * 0.91 + float(index) * 0.47)
			var width := pixel * (1.0 + depth * 1.4)
			var alpha := lerpf(0.13, 0.025, depth)
			var position := Vector2(x + wave * pixel * (0.2 + depth * 0.45), road_y + pixel * (2.0 + float(row) * 4.0))
			draw_rect(Rect2(position, Vector2(width, pixel)), Color(reflection_color, alpha))
	pass


func should_draw_reflections() -> bool:
	return ThemeColor.is_dark_theme()
