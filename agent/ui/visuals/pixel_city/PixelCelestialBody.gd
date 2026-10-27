class_name PixelCelestialBody
extends Node2D

@export var is_moon: bool = false

const MOON_X_RATIO := 0.84
const MOON_Y_RATIO := 0.12

var pixel: float = 4.0
var radius: float = 20.0
var body_color := Color.WHITE


func update_visual(viewport_size: Vector2, new_pixel: float, time_of_day: float, _daylight: float, rain_intensity: float, moon_body: bool) -> void:
	is_moon = moon_body
	visible = is_moon == ThemeColor.is_dark_theme()
	if not visible:
		return
	pixel = new_pixel
	radius = pixel * (4.0 if is_moon else 5.0)
	if is_moon:
		position = Vector2(viewport_size.x * MOON_X_RATIO, viewport_size.y * MOON_Y_RATIO)
	else:
		var body_time := fposmod(time_of_day, 1.0)
		var progress := clampf((body_time - 0.23) / 0.54, 0.0, 1.0)
		var x := lerpf(viewport_size.x * 0.14, viewport_size.x * 0.86, progress)
		var arc := sin(progress * PI)
		# The body shape stays pixel-authored, while its node transform remains
		# continuous. Snapping this slow orbit to an 8-pixel grid caused visible jumps.
		position = Vector2(x, viewport_size.y * (0.29 - arc * 0.18))
	var alpha := 1.0
	alpha *= 1.0 - rain_intensity * (0.55 if is_moon else 0.75)
	body_color = Color(0.77, 0.88, 1.0, alpha * 0.70) if is_moon else Color(1.0, 0.75, 0.28, alpha * 0.75)
	queue_redraw()
	pass


func _draw() -> void:
	if body_color.a <= 0.01:
		return
	var cells := ceili(radius / pixel)
	for y_cell in range(-cells, cells + 1):
		for x_cell in range(-cells, cells + 1):
			var offset := Vector2(float(x_cell), float(y_cell)) * pixel
			if should_draw_cell(offset):
				draw_rect(Rect2(offset, Vector2(pixel, pixel)), body_color)
	pass


func should_draw_cell(offset: Vector2) -> bool:
	if offset.length_squared() > radius * radius:
		return false
	if not is_moon:
		return true
	# A displaced inner disc removes the upper-right body and leaves a crisp
	# left-facing pixel crescent without painting a theme-colored cover shape.
	var cutout_center := Vector2(pixel * 1.4, -pixel * 0.6)
	var cutout_radius := radius * 0.82
	return offset.distance_squared_to(cutout_center) > cutout_radius * cutout_radius
