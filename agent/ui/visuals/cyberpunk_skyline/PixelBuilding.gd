class_name PixelBuilding
extends Node2D

var world_index: int = -2147483648
var pixel: float = 4.0
var building_width: float = 48.0
var building_height: float = 180.0
var elapsed: float = 0.0
var daylight: float = 0.0
var city_energy: float = 0.0
var body_alpha: float = 0.2
var seed_offset: int = 0
var distant: bool = false


func configure(index: int, new_pixel: float, width: float, height: float, new_elapsed: float, new_daylight: float, new_energy: float, alpha: float, offset: int, is_distant: bool) -> void:
	world_index = index
	pixel = new_pixel
	building_width = width
	building_height = height
	elapsed = new_elapsed
	daylight = new_daylight
	city_energy = new_energy
	body_alpha = alpha
	seed_offset = offset
	distant = is_distant
	queue_redraw()
	pass


func _draw() -> void:
	var night_tint := Color("1b2b3d") if distant else Color("101b2d")
	var daylight_tint := Color("38556a") if distant else Color("304c63")
	var day_tint := night_tint.lerp(daylight_tint, daylight * 0.58)
	var body_color := Color(day_tint, body_alpha)
	draw_rect(Rect2(0.0, -building_height, building_width, building_height), body_color)
	draw_rooftop(body_color)
	draw_windows()
	pass


func draw_rooftop(color: Color) -> void:
	if world_index % 4 == 0:
		draw_rect(Rect2(building_width * 0.5, -building_height - pixel * 4.0, pixel, pixel * 4.0), color)
	elif world_index % 5 == 0:
		draw_rect(Rect2(pixel * 2.0, -building_height - pixel * 2.0, building_width - pixel * 4.0, pixel * 2.0), color)
	pass


func draw_windows() -> void:
	var column_step := pixel * (4.0 if distant else 3.0)
	var row_step := pixel * (5.0 if distant else 4.0)
	var phase := Vector2(pixel, pixel * 2.0) if distant else Vector2(pixel * 1.5, pixel * 1.5)
	var columns := maxi(1, floori((building_width - phase.x - pixel) / column_step))
	var rows := maxi(1, floori((building_height - phase.y - pixel) / row_step))
	var night_light := 1.0 - daylight * 0.78
	for row in range(rows):
		for column in range(columns):
			var seed := world_index * 101 + row * 17 + column + seed_offset
			if PixelCity.stable_random(seed, 71) > window_lit_threshold():
				continue
			var alpha := 0.06 + night_light * 0.13 if distant else 0.16 + night_light * 0.42 + city_energy * 0.16
			var alpha_reference := 0.10 if distant else 0.42
			alpha *= clampf(body_alpha / alpha_reference, 0.45, 1.0)
			var window_position := Vector2(phase.x + float(column) * column_step, -building_height + phase.y + float(row) * row_step)
			var window_size := Vector2(pixel, pixel) if distant else Vector2(pixel, pixel * 1.5)
			alpha *= window_light_pulse(seed)
			var window_color := Color(0.45, 0.68, 0.82, minf(alpha, 0.24)) if distant else Color(1.0, 0.73, 0.30, minf(alpha, 0.82))
			draw_rect(Rect2(window_position, window_size), window_color)
	pass


func window_lit_threshold() -> float:
	return 0.18 if distant else 0.42 + city_energy * 0.18


## Only a small deterministic subset breathes, so the skyline feels inhabited
## without turning every window into a synchronized signboard.
func window_light_pulse(seed: int) -> float:
	if PixelCity.stable_random(seed, 97) > 0.07:
		return 1.0
	var duration := lerpf(3.8, 6.4, PixelCity.stable_random(seed, 101))
	var phase := elapsed * TAU / duration + PixelCity.stable_random(seed, 103) * TAU
	return 0.78 + (0.5 + 0.5 * sin(phase)) * 0.22
