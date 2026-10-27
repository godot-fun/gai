class_name PixelBridgeLayer
extends Node2D

const PARALLAX_FACTOR := 0.65

var segments: Array[PixelBridgeSegment] = []


func update_visual(viewport_size: Vector2, pixel: float, camera_x: float, elapsed: float) -> void:
	var segment_width := pixel * 20.0
	var desired_count := ceili(viewport_size.x / segment_width) + 3
	ensure_segments(desired_count)
	var layer_camera := camera_x * PARALLAX_FACTOR
	var first_world_index := floori(layer_camera / segment_width) - 1
	var offset := fposmod(layer_camera, segment_width)
	var road_y := snappedf(viewport_size.y * PixelCity.BRIDGE_TOP_RATIO + pixel * 7.0, pixel)
	var bottom := snappedf(viewport_size.y * 0.92, pixel)
	var bridge_color := VisualColor.appearance_color(ThemeColor.accent_theme_color(), -0.04, 0.72, 0.82)
	for pool_index in range(segments.size()):
		var segment := segments[pool_index]
		var world_index := first_world_index + pool_index
		segment.position = Vector2(float(pool_index - 1) * segment_width - offset, road_y)
		segment.configure(pixel, segment_width, bottom - road_y, bridge_color, elapsed, world_index)
	pass


func ensure_segments(count: int) -> void:
	while segments.size() < count:
		var segment := PixelBridgeSegment.new()
		segment.name = "BridgeSegment_%02d" % segments.size()
		add_child(segment)
		segments.append(segment)
	while segments.size() > count:
		var segment: PixelBridgeSegment = segments.pop_back()
		segment.queue_free()
	pass
