class_name PixelCloudLayer
extends Node2D

const CLOUD_COUNT := 7
const PARALLAX_FACTOR := 0.08

var clouds: Array[PixelCloud] = []


func _ready() -> void:
	ensure_clouds()
	pass


func ensure_clouds() -> void:
	while clouds.size() < CLOUD_COUNT:
		var cloud := PixelCloud.new()
		cloud.name = "Cloud_%02d" % clouds.size()
		add_child(cloud)
		clouds.append(cloud)
	pass


func update_visual(viewport_size: Vector2, pixel: float, camera_x: float, elapsed: float, daylight: float, rain_intensity: float, _reasoning_energy: float) -> void:
	ensure_clouds()
	for index in range(clouds.size()):
		var cloud := clouds[index]
		var width := pixel * (11.0 + PixelCity.stable_random(index, 37) * 14.0)
		var world_span := viewport_size.x + width * 3.0
		var own_drift := elapsed * (4.0 + float(index % 3) * 2.0)
		var x := fposmod(PixelCity.stable_random(index, 29) * world_span - camera_x * PARALLAX_FACTOR + own_drift, world_span) - width
		var y := viewport_size.y * (0.09 + PixelCity.stable_random(index, 31) * 0.34)
		var opacity := (0.07 + rain_intensity * 0.13) * (0.7 + daylight * 0.3)
		if x > viewport_size.x * 0.22 and x < viewport_size.x * 0.78 and y > viewport_size.y * 0.16:
			opacity *= 0.35
		cloud.position = Vector2(x, snappedf(y, pixel))
		cloud.configure(pixel, width, opacity)
	pass
