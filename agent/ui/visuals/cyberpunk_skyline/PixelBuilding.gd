class_name PixelBuilding
extends Node2D

enum Shape { SLAB, STEPPED, TWIN, CROWN, TOWER }

var world_index: int = -2147483648
var pixel: float = 4.0
var building_width: float = 48.0
var building_height: float = 180.0
var elapsed: float = 0.0
var daylight: float = 0.0
var city_energy: float = 0.0
var body_opacity: float = 0.2
var distant: bool = false


func configure(index: int, new_pixel: float, width: float, height: float, new_elapsed: float, new_daylight: float, new_energy: float, opacity: float, is_distant: bool) -> void:
	world_index = index
	pixel = new_pixel
	building_width = width
	building_height = height
	elapsed = new_elapsed
	daylight = new_daylight
	city_energy = new_energy
	body_opacity = opacity
	distant = is_distant
	queue_redraw()
	pass


func _draw() -> void:
	var body_color := building_body_color()
	var body_rectangles := body_rects()
	for body_rect: Rect2 in body_rectangles:
		draw_rect(body_rect, body_color)
	if not distant:
		draw_facade_depth(body_rectangles, body_color)
		draw_rooftop(body_color)
	draw_windows()
	pass


## Buildings cover a broad portion of the chat overlay, so their authored color
## remains genuinely translucent instead of baking in a specific app background.
func building_body_color() -> Color:
	var night_tint := Color("1b2b3d") if distant else Color("101b2d")
	var daylight_tint := Color("38556a") if distant else Color("304c63")
	var day_tint := night_tint.lerp(daylight_tint, daylight * 0.58)
	return Color(day_tint, body_opacity)


func building_shape() -> Shape:
	var selector := PixelCity.stable_random(world_index, 149)
	if distant:
		return Shape.STEPPED if selector > 0.72 else Shape.SLAB
	if selector < 0.34:
		return Shape.SLAB
	if selector < 0.59:
		return Shape.STEPPED
	if selector < 0.74:
		return Shape.TWIN
	if selector < 0.90:
		return Shape.CROWN
	return Shape.TOWER


func body_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	match building_shape():
		Shape.STEPPED:
			result.append(pixel_rect(0.0, -building_height * 0.72, building_width, building_height * 0.72))
			result.append(pixel_rect(building_width * 0.16, -building_height, building_width * 0.68, building_height * 0.28))
		Shape.TWIN:
			result.append(pixel_rect(0.0, -building_height * 0.34, building_width, building_height * 0.34))
			result.append(pixel_rect(0.0, -building_height * 0.84, building_width * 0.43, building_height * 0.50))
			result.append(pixel_rect(building_width * 0.57, -building_height, building_width * 0.43, building_height * 0.66))
		Shape.CROWN:
			result.append(pixel_rect(0.0, -building_height * 0.92, building_width, building_height * 0.92))
			result.append(pixel_rect(building_width * 0.12, -building_height, building_width * 0.76, building_height * 0.08))
		Shape.TOWER:
			result.append(pixel_rect(0.0, -building_height * 0.68, building_width, building_height * 0.68))
			result.append(pixel_rect(building_width * 0.20, -building_height, building_width * 0.60, building_height * 0.32))
		_:
			result.append(pixel_rect(0.0, -building_height, building_width, building_height))
	return result


func pixel_rect(x: float, y: float, width: float, height: float) -> Rect2:
	var left := snappedf(x, pixel)
	var top := snappedf(y, pixel)
	var right := snappedf(x + width, pixel)
	var bottom := snappedf(y + height, pixel)
	return Rect2(left, top, maxf(pixel, right - left), maxf(pixel, bottom - top))


func draw_facade_depth(body_rectangles: Array[Rect2], body_color: Color) -> void:
	var shadow_color := Color(body_color.darkened(0.09 if ThemeColor.is_dark_theme() else 0.07), body_color.a * 0.42)
	var edge_color := Color(body_color.lightened(0.08 if ThemeColor.is_dark_theme() else 0.045), body_color.a * 0.32)
	for body_rect: Rect2 in body_rectangles:
		var shadow_width := maxf(pixel, snappedf(body_rect.size.x * 0.16, pixel))
		draw_rect(Rect2(body_rect.end.x - shadow_width, body_rect.position.y, shadow_width, body_rect.size.y), shadow_color)
		draw_rect(Rect2(body_rect.position, Vector2(maxf(pixel, body_rect.size.x - shadow_width), pixel)), edge_color)
	pass


func draw_rooftop(color: Color) -> void:
	var top := snappedf(-building_height, pixel)
	match building_shape():
		Shape.CROWN:
			draw_rect(pixel_rect(building_width * 0.24, top - pixel, building_width * 0.52, pixel), color.lightened(0.04))
		Shape.TOWER:
			draw_rect(pixel_rect(building_width * 0.5 - pixel * 0.5, top - pixel * 5.0, pixel, pixel * 5.0), color)
		_:
			if world_index % 5 == 0:
				draw_rect(pixel_rect(building_width * 0.5, top - pixel * 3.0, pixel, pixel * 3.0), color)
	pass


func draw_windows() -> void:
	if not emits_window_light():
		return
	var window_style := floori(PixelCity.stable_random(world_index, 157) * 3.0)
	var column_step := pixel * (4.0 if window_style == 0 else 3.0)
	var row_step := pixel * (5.0 if window_style == 1 else 4.0)
	var phase := Vector2(pixel * 1.5, pixel * 1.5)
	var columns := maxi(1, floori((building_width - phase.x - pixel) / column_step))
	var rows := maxi(1, floori((building_height - phase.y - pixel) / row_step))
	var night_light := 1.0 - daylight * 0.78
	for row in range(rows):
		if PixelCity.stable_random(world_index * 31 + row, 163) < 0.18:
			continue
		for column in range(columns):
			var seed := world_index * 101 + row * 17 + column
			if PixelCity.stable_random(seed, 71) > window_lit_ratio():
				continue
			var alpha := 0.16 + night_light * 0.42 + city_energy * 0.16
			alpha *= clampf(body_opacity / 0.22, 0.55, 1.0)
			var window_position := Vector2(phase.x + float(column) * column_step, -building_height + phase.y + float(row) * row_step)
			var window_size := Vector2(pixel * 2.0, pixel) if window_style == 2 else Vector2(pixel, pixel * 1.5)
			var window_rect := Rect2(window_position, window_size)
			if not body_contains(window_rect):
				continue
			alpha *= window_light_pulse(seed)
			var window_color := Color(1.0, 0.73, 0.30, minf(alpha, 0.82))
			draw_rect(window_rect, window_color)
	pass


func window_lit_ratio() -> float:
	return 0.28 + city_energy * 0.12


func body_contains(window_rect: Rect2) -> bool:
	for body_rect: Rect2 in body_rects():
		if body_rect.encloses(window_rect):
			return true
	return false


func emits_window_light() -> bool:
	return not distant


## Only a small deterministic subset breathes, so the skyline feels inhabited
## without turning every window into a synchronized signboard.
func window_light_pulse(seed: int) -> float:
	if PixelCity.stable_random(seed, 97) > 0.07:
		return 1.0
	var duration := lerpf(3.8, 6.4, PixelCity.stable_random(seed, 101))
	var phase := elapsed * TAU / duration + PixelCity.stable_random(seed, 103) * TAU
	return 0.78 + (0.5 + 0.5 * sin(phase)) * 0.22
