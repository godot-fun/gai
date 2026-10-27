class_name PixelStarField
extends Node2D

const STAR_TOP_RATIO := 0.035
const STAR_BOTTOM_RATIO := 0.22

var viewport_size := Vector2.ZERO
var pixel: float = 4.0
var elapsed: float = 0.0
var daylight: float = 0.0
var rain_intensity: float = 0.0
var camera_x: float = 0.0


func update_visual(new_size: Vector2, new_pixel: float, new_elapsed: float, new_daylight: float, new_rain: float, new_camera_x: float) -> void:
	viewport_size = new_size
	pixel = new_pixel
	elapsed = new_elapsed
	daylight = new_daylight
	rain_intensity = new_rain
	camera_x = new_camera_x
	queue_redraw()
	pass


func _draw() -> void:
	var alpha := (1.0 - daylight) * (1.0 - rain_intensity) * 0.55
	if alpha <= 0.01:
		return
	for index in range(38):
		var x := fposmod(PixelCity.stable_random(index, 11) * viewport_size.x - camera_x * 0.02, viewport_size.x)
		# Stars stay above the tallest near-city roofline. Buildings remain
		# translucent for chat readability, so allowing stars lower than this would
		# make them appear painted over the building facades.
		var y := star_y_ratio(index) * viewport_size.y
		var pulse := 0.55 + 0.45 * sin(elapsed * (1.2 + PixelCity.stable_random(index, 19)) + float(index))
		var star_size := pixel if index % 7 else pixel * 2.0
		draw_rect(Rect2(x, snappedf(y, pixel), star_size, star_size), Color(0.80, 0.90, 1.0, alpha * pulse))
	pass


static func star_y_ratio(index: int) -> float:
	return lerpf(STAR_TOP_RATIO, STAR_BOTTOM_RATIO, PixelCity.stable_random(index, 17))
