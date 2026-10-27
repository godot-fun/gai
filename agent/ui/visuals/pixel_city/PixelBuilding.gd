class_name PixelBuilding
extends Node2D

const BuildingProfile = preload("res://agent/ui/visuals/pixel_city/PixelBuildingProfile.gd")

var world_index: int = -2147483648
var pixel: float = 4.0
var building_width: float = 48.0
var building_height: float = 180.0
var elapsed: float = 0.0
var daylight: float = 0.0
var city_energy: float = 0.0
var body_opacity: float = 0.2
var distant: bool = false
var profile: BuildingProfile
var occlusion_rectangles: Array[Rect2] = []


func configure(new_profile: BuildingProfile, new_pixel: float, width: float, height: float, new_elapsed: float, new_daylight: float, new_energy: float, opacity: float) -> void:
	profile = new_profile
	world_index = profile.world_index
	pixel = new_pixel
	building_width = width
	building_height = height
	elapsed = new_elapsed
	daylight = new_daylight
	city_energy = new_energy
	body_opacity = opacity
	distant = profile.distant
	queue_redraw()
	pass


func _draw() -> void:
	var body_color := building_body_color()
	var body_rectangles := visible_body_rects()
	for body_rect: Rect2 in body_rectangles:
		draw_rect(body_rect, body_color)
	if not distant:
		draw_facade_depth(body_rectangles, body_color)
		draw_rooftop(body_color)
	draw_windows()
	pass


func set_occlusion_rectangles(new_rectangles: Array[Rect2]) -> void:
	occlusion_rectangles = new_rectangles
	queue_redraw()
	pass


## Buildings cover a broad portion of the chat overlay, so their authored color
## remains genuinely translucent instead of baking in a specific app background.
func building_body_color() -> Color:
	# Distant silhouettes must recede in dark mode. A brighter distant tint leaks
	# through foreground gaps as pale vertical bands against the near skyline.
	var night_tint := Color("0b1422") if distant else Color("101b2d")
	var daylight_tint := Color("38556a") if distant else Color("304c63")
	var day_tint := night_tint.lerp(daylight_tint, daylight * 0.58)
	if profile != null:
		match profile.tint_variant:
			1:
				day_tint = day_tint.lightened(0.06)
			2:
				day_tint = day_tint.lerp(Color("45617a"), 0.12)
			3:
				day_tint = day_tint.lerp(Color("625845"), 0.08)
	return Color(day_tint, body_opacity)


func body_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var shape := profile.shape if profile != null else BuildingProfile.Shape.SLAB
	var alignment := float((profile.setback_variant if profile != null else 1) - 1)
	match shape:
		BuildingProfile.Shape.STEPPED:
			var upper_width := building_width * 0.68
			var upper_x := (building_width - upper_width) * (0.5 + alignment * 0.34)
			result.append(pixel_rect(0.0, -building_height * 0.72, building_width, building_height * 0.72))
			result.append(pixel_rect(upper_x, -building_height, upper_width, building_height * 0.28))
		BuildingProfile.Shape.TWIN:
			var left_height := 0.84 + alignment * 0.05
			var right_height := 1.0 - alignment * 0.05
			result.append(pixel_rect(0.0, -building_height * 0.34, building_width, building_height * 0.34))
			result.append(pixel_rect(0.0, -building_height * left_height, building_width * 0.43, building_height * (left_height - 0.34)))
			result.append(pixel_rect(building_width * 0.57, -building_height * right_height, building_width * 0.43, building_height * (right_height - 0.34)))
		BuildingProfile.Shape.CROWN:
			result.append(pixel_rect(0.0, -building_height * 0.92, building_width, building_height * 0.92))
			result.append(pixel_rect(building_width * 0.12, -building_height, building_width * 0.76, building_height * 0.08))
		BuildingProfile.Shape.TOWER:
			var tower_width := 0.54 + float(profile.setback_variant) * 0.07
			result.append(pixel_rect(0.0, -building_height * 0.68, building_width, building_height * 0.68))
			result.append(pixel_rect(building_width * (1.0 - tower_width) * 0.5, -building_height, building_width * tower_width, building_height * 0.32))
		BuildingProfile.Shape.TERRACED:
			var direction := -1.0 if profile.setback_variant == 0 else 1.0 if profile.setback_variant == 2 else 0.0
			result.append(pixel_rect(0.0, -building_height * 0.48, building_width, building_height * 0.48))
			result.append(pixel_rect(building_width * (0.10 + direction * 0.06), -building_height * 0.76, building_width * 0.80, building_height * 0.28))
			result.append(pixel_rect(building_width * (0.22 + direction * 0.10), -building_height, building_width * 0.56, building_height * 0.24))
		BuildingProfile.Shape.NOTCHED:
			var notch_width := building_width * (0.18 + float(profile.setback_variant) * 0.05)
			result.append(pixel_rect(0.0, -building_height * 0.78, building_width, building_height * 0.78))
			result.append(pixel_rect(0.0, -building_height, (building_width - notch_width) * 0.5, building_height * 0.22))
			result.append(pixel_rect((building_width + notch_width) * 0.5, -building_height, (building_width - notch_width) * 0.5, building_height * 0.22))
		_:
			result.append(pixel_rect(0.0, -building_height, building_width, building_height))
	return result


## Foreground silhouettes cut matching regions out of distant buildings. This
## keeps transparent city layers from accumulating into dark overlap bands.
func visible_body_rects() -> Array[Rect2]:
	var result := body_rects()
	if not distant or occlusion_rectangles.is_empty():
		return result
	for layer_occluder: Rect2 in occlusion_rectangles:
		var local_occluder := Rect2(layer_occluder.position - position, layer_occluder.size)
		var remaining: Array[Rect2] = []
		for body_rect: Rect2 in result:
			remaining.append_array(subtract_rect(body_rect, local_occluder))
		result = remaining
		if result.is_empty():
			break
	return result


static func subtract_rect(source: Rect2, cut: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if not source.intersects(cut):
		result.append(source)
		return result
	var overlap := source.intersection(cut)
	if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
		result.append(source)
		return result
	append_rect_if_visible(result, Rect2(source.position, Vector2(source.size.x, overlap.position.y - source.position.y)))
	append_rect_if_visible(result, Rect2(Vector2(source.position.x, overlap.end.y), Vector2(source.size.x, source.end.y - overlap.end.y)))
	append_rect_if_visible(result, Rect2(Vector2(source.position.x, overlap.position.y), Vector2(overlap.position.x - source.position.x, overlap.size.y)))
	append_rect_if_visible(result, Rect2(Vector2(overlap.end.x, overlap.position.y), Vector2(source.end.x - overlap.end.x, overlap.size.y)))
	return result


static func append_rect_if_visible(rectangles: Array[Rect2], rectangle: Rect2) -> void:
	if rectangle.size.x > 0.0 and rectangle.size.y > 0.0:
		rectangles.append(rectangle)
	pass


func pixel_rect(x: float, y: float, width: float, height: float) -> Rect2:
	var left := snappedf(x, pixel)
	var top := snappedf(y, pixel)
	var right := snappedf(x + width, pixel)
	var bottom := snappedf(y + height, pixel)
	return Rect2(left, top, maxf(pixel, right - left), maxf(pixel, bottom - top))


func draw_facade_depth(body_rectangles: Array[Rect2], body_color: Color) -> void:
	# A dark translucent side laid over a translucent building compounds its alpha
	# wherever two buildings overlap. Use a highlight edge instead, so light mode
	# never produces an opaque-looking black stripe while silhouettes still separate.
	var edge_color := facade_edge_color(body_color)
	if edge_color.a <= 0.0:
		return
	var top_color := Color(edge_color, edge_color.a * 0.72)
	for body_rect: Rect2 in body_rectangles:
		var edge_x := body_rect.position.x if profile != null and profile.shadow_side == BuildingProfile.ShadowSide.LEFT else body_rect.end.x - pixel
		draw_rect(Rect2(edge_x, body_rect.position.y, pixel, body_rect.size.y), edge_color)
		draw_rect(Rect2(body_rect.position, Vector2(body_rect.size.x, pixel)), top_color)
	if profile != null and profile.facade == BuildingProfile.Facade.NARROW_COLUMNS:
		var divider_color := Color(edge_color, edge_color.a * 0.28)
		for column in range(1, 3):
			var x := snappedf(building_width * float(column) / 3.0, pixel)
			draw_rect(Rect2(x, -building_height * 0.68, pixel, building_height * 0.68), divider_color)
	pass


func facade_edge_color(body_color: Color) -> Color:
	if ThemeColor.is_dark_theme():
		return Color(body_color, 0.0)
	return Color(body_color.lightened(0.72), body_color.a * 0.10)


func draw_rooftop(color: Color) -> void:
	var top := snappedf(-building_height, pixel)
	var roof := profile.roof if profile != null else BuildingProfile.Roof.NONE
	match roof:
		BuildingProfile.Roof.CAP:
			draw_rect(pixel_rect(building_width * 0.24, top - pixel, building_width * 0.52, pixel), color.lightened(0.04))
		BuildingProfile.Roof.ANTENNA:
			draw_rect(pixel_rect(building_width * 0.5 - pixel * 0.5, top - pixel * 5.0, pixel, pixel * 5.0), color)
		BuildingProfile.Roof.WATER_TANK:
			draw_rect(pixel_rect(building_width * 0.32, top - pixel * 3.0, building_width * 0.36, pixel * 2.0), color)
			draw_rect(pixel_rect(building_width * 0.38, top - pixel, pixel, pixel), color)
			draw_rect(pixel_rect(building_width * 0.62 - pixel, top - pixel, pixel, pixel), color)
		BuildingProfile.Roof.TWIN_MAST:
			draw_rect(pixel_rect(building_width * 0.28, top - pixel * 3.0, pixel, pixel * 3.0), color)
			draw_rect(pixel_rect(building_width * 0.70, top - pixel * 2.0, pixel, pixel * 2.0), color)
	pass


func draw_windows() -> void:
	if not emits_window_light():
		return
	var facade := profile.facade if profile != null else BuildingProfile.Facade.GRID
	var column_step := pixel * (4.0 if facade == BuildingProfile.Facade.WIDE_BANDS else 3.0)
	var row_step := pixel * (5.0 if facade == BuildingProfile.Facade.NARROW_COLUMNS else 4.0)
	var phase := Vector2(pixel * 1.5, pixel * 1.5)
	var columns := maxi(1, floori((building_width - phase.x - pixel) / column_step))
	var rows := maxi(1, floori((building_height - phase.y - pixel) / row_step))
	var night_light := 1.0 - daylight * 0.78
	for row in range(rows):
		if profile != null and posmod(row, profile.dark_floor_period()) == profile.dark_floor_phase():
			continue
		for column in range(columns):
			var seed := world_index * 101 + row * 17 + column
			if PixelCity.stable_random(seed, 71) > window_lit_ratio():
				continue
			var alpha := 0.16 + night_light * 0.42 + city_energy * 0.16
			alpha *= clampf(body_opacity / 0.22, 0.55, 1.0)
			var row_offset := pixel * 1.5 if facade == BuildingProfile.Facade.OFFSET_GRID and row % 2 == 1 else 0.0
			var window_position := Vector2(phase.x + row_offset + float(column) * column_step, -building_height + phase.y + float(row) * row_step)
			var window_size := Vector2(pixel * 2.0, pixel) if facade == BuildingProfile.Facade.WIDE_BANDS else Vector2(pixel, pixel * 1.5)
			var window_rect := Rect2(window_position, window_size)
			if not body_contains(window_rect):
				continue
			alpha *= window_light_pulse(seed)
			var window_color := window_light_color()
			window_color.a = minf(alpha, 0.82)
			draw_rect(window_rect, window_color)
	pass


func window_light_color() -> Color:
	var variant := profile.tint_variant if profile != null else 0
	match variant:
		1:
			return Color("ffd07a")
		2:
			return Color("f0bd63")
		3:
			return Color("ffdca0")
	return Color("ffba4d")


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
