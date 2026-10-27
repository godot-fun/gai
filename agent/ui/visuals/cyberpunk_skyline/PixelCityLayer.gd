class_name PixelCityLayer
extends Node2D

@export var parallax_factor: float = 0.24
@export var horizon_ratio: float = 0.56
@export var distant: bool = false

var buildings: Array[PixelBuilding] = []


func update_visual(viewport_size: Vector2, pixel: float, camera_x: float, daylight: float, city_energy: float, rain_intensity: float) -> void:
	var spacing := pixel * (10.0 if distant else 8.0)
	var desired_count := ceili(viewport_size.x / spacing) + 3
	ensure_buildings(desired_count)
	var layer_camera := camera_x * parallax_factor
	var first_world_index := floori(layer_camera / spacing) - 1
	var offset := fposmod(layer_camera, spacing)
	for pool_index in range(buildings.size()):
		var building := buildings[pool_index]
		var world_index := first_world_index + pool_index
		var x := float(pool_index - 1) * spacing - offset
		var depth := PixelCity.stable_random(world_index, 59 + (100 if distant else 0))
		var min_height := 0.06 if distant else 0.09
		var max_height := 0.18 if distant else 0.29
		var height := viewport_size.y * lerpf(min_height, max_height, PixelCity.stable_random(world_index, 61))
		var width := spacing + pixel * floorf(PixelCity.stable_random(world_index, 67) * (3.0 if distant else 5.0))
		# Foreground silhouettes intentionally carry enough opacity to suppress the
		# cool distant windows beneath them. The central reading band reduces this
		# without returning to the former see-through double-window appearance.
		var alpha := lerpf(0.08, 0.14, depth) if distant else lerpf(0.38, 0.52, depth)
		alpha *= 0.86 + rain_intensity * 0.14
		if x + width > viewport_size.x * 0.22 and x < viewport_size.x * 0.78:
			alpha *= 0.55 if not distant else 0.62
		# Keep the authored geometry on the pixel grid, but let the node transform move
		# continuously. Quantizing this x position made slow parallax jump a full pixel
		# block at a time (up to eight screen pixels on large windows).
		building.position = Vector2(x, snappedf(viewport_size.y * horizon_ratio, pixel))
		building.configure(world_index, pixel, width, height, daylight, city_energy, alpha, 1000 if distant else 0, distant)
	pass


func ensure_buildings(count: int) -> void:
	while buildings.size() < count:
		var building := PixelBuilding.new()
		building.name = "Building_%02d" % buildings.size()
		add_child(building)
		buildings.append(building)
	while buildings.size() > count:
		var building: PixelBuilding = buildings.pop_back()
		building.queue_free()
	pass
