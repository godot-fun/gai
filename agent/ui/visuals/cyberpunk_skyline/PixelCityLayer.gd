class_name PixelCityLayer
extends Node2D

const CLUSTER_SIZE := 6

@export var parallax_factor: float = 0.24
@export var horizon_ratio: float = 0.56
@export var distant: bool = false

var buildings: Array[PixelBuilding] = []


func update_visual(viewport_size: Vector2, pixel: float, camera_x: float, elapsed: float, daylight: float, city_energy: float, rain_intensity: float) -> void:
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
		var min_height := 0.055 if distant else 0.09
		var max_height := 0.16 if distant else 0.29
		var height := viewport_size.y * lerpf(min_height, max_height, cluster_height_mix(world_index, distant))
		var group_gap := pixel * 3.0 if posmod(world_index, CLUSTER_SIZE) == CLUSTER_SIZE - 1 else 0.0
		var width_variation := pixel * floorf(PixelCity.stable_random(world_index, 67) * 3.0)
		var width := spacing - pixel * 2.0 - width_variation * 0.5 if distant else spacing - pixel + width_variation
		width = maxf(pixel * 4.0, width - group_gap)
		# City visuals live above chat. Broad building fills therefore stay lighter
		# than compact overlay controls, while the distant layer recedes even further.
		var body_opacity := lerpf(0.045, 0.08, depth) if distant else lerpf(0.18, 0.26, depth)
		body_opacity *= 0.88 + rain_intensity * 0.12
		# Keep the authored geometry on the pixel grid, but let the node transform move
		# continuously. Quantizing this x position made slow parallax jump a full pixel
		# block at a time (up to eight screen pixels on large windows).
		building.position = Vector2(x, snappedf(viewport_size.y * horizon_ratio, pixel))
		building.configure(world_index, pixel, width, height, elapsed, daylight, city_energy, body_opacity, distant)
	pass


## Buildings share a group-scale height envelope with a smaller per-building
## variation. This produces readable districts instead of uniform random teeth.
static func cluster_height_mix(world_index: int, is_distant: bool) -> float:
	var cluster_index := floori(float(world_index) / float(CLUSTER_SIZE))
	var local_index := posmod(world_index, CLUSTER_SIZE)
	var cluster_base := PixelCity.stable_random(cluster_index, 131 + (40 if is_distant else 0))
	var center_emphasis := 1.0 - absf(float(local_index) - 2.5) / 3.5
	var local_variation := PixelCity.stable_random(world_index, 137 + (40 if is_distant else 0)) - 0.5
	return clampf(cluster_base * 0.68 + center_emphasis * 0.24 + local_variation * 0.20, 0.0, 1.0)


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
