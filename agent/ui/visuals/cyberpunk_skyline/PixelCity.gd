class_name PixelCity
extends VisualEffect

## Event-driven pixel city arranged as four overlapping depth layers: sky, skyline,
## river, and bridge. The scene uses a fixed logical pixel grid so it stays crisp
## under the project's canvas-items stretch mode without depending on bitmap assets.

const SKY_BOTTOM_RATIO := 0.58
const HORIZON_RATIO := 0.56
const RIVER_TOP_RATIO := 0.58
const BRIDGE_TOP_RATIO := 0.70
const BRIDGE_BOTTOM_RATIO := 0.92
const MAX_VEHICLES := 10
const MIN_PIXEL_SIZE := 3.0
const MAX_PIXEL_SIZE := 8.0

enum VehicleResult { RUNNING, SUCCESS, FAILED }


class VehicleState extends RefCounted:
	var id: String = ""
	var lane: int = 0
	var progress: float = 0.0
	var speed: float = 0.0
	var result: VehicleResult = VehicleResult.RUNNING
	var exiting: bool = false
	var seed: int = 0


var vehicles: Array[VehicleState] = []
var elapsed: float = 0.0
var time_of_day: float = 0.5
var reasoning_energy: float = 0.0
var city_energy: float = 0.0
var rain_intensity: float = 0.0
var rain_target: float = 0.0
var active_tool_count: int = 0
var turn_serial: int = 0
var completing: bool = false
var ended_with_error: bool = false


func fade_in_seconds() -> float:
	return 0.7


func fade_out_seconds() -> float:
	return 0.8


func on_agent_start(_session_id: int) -> void:
	var clock := Time.get_time_dict_from_system()
	var hour := float(clock.get("hour", 12))
	var minute := float(clock.get("minute", 0))
	time_of_day = fposmod((hour + minute / 60.0) / 24.0, 1.0)
	reasoning_energy = 0.22
	city_energy = 0.3
	queue_redraw()
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	completing = true
	ended_with_error = StringUtils.is_not_blank(error_message)
	rain_target = 0.0
	for vehicle: VehicleState in vehicles:
		vehicle.exiting = true
		vehicle.speed = maxf(vehicle.speed, 0.42)
	queue_redraw()
	pass


func on_turn_start(_session_id: int) -> void:
	turn_serial += 1
	reasoning_energy = maxf(reasoning_energy, 0.58)
	city_energy = minf(1.0, city_energy + 0.18)
	queue_redraw()
	pass


func on_turn_end(_session_id: int) -> void:
	reasoning_energy = minf(reasoning_energy, 0.34)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		reasoning_energy = minf(1.0, reasoning_energy + float(chunk.length()) / 260.0)
		city_energy = minf(1.0, city_energy + float(chunk.length()) / 520.0)
	else:
		city_energy = minf(1.0, city_energy + float(chunk.length()) / 760.0)
	queue_redraw()
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	active_tool_count += 1
	rain_target = clampf(0.48 + float(active_tool_count) * 0.12, 0.0, 0.92)
	spawn_vehicle(tool_call_id, tool_name)
	reasoning_energy = 1.0
	city_energy = 1.0
	queue_redraw()
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	active_tool_count = maxi(active_tool_count - 1, 0)
	rain_target = 0.22 if active_tool_count > 0 else 0.0
	for vehicle: VehicleState in vehicles:
		if vehicle.id != tool_call_id or vehicle.result != VehicleResult.RUNNING:
			continue
		vehicle.result = VehicleResult.FAILED if result.is_error else VehicleResult.SUCCESS
		vehicle.exiting = true
		vehicle.speed = maxf(vehicle.speed, 0.28)
		break
	queue_redraw()
	pass


func spawn_vehicle(tool_call_id: String, tool_name: String) -> void:
	if vehicles.size() >= MAX_VEHICLES:
		vehicles.remove_at(0)
	var vehicle := VehicleState.new()
	vehicle.id = tool_call_id
	vehicle.seed = absi((tool_name + tool_call_id).hash())
	vehicle.lane = vehicle.seed % 2
	vehicle.progress = -0.08 - float(vehicles.size() % 3) * 0.06
	vehicle.speed = 0.09 + stable_random(vehicle.seed, 3) * 0.055
	vehicles.append(vehicle)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	var time_speed := 0.0012 + reasoning_energy * 0.0022
	time_of_day = fposmod(time_of_day + delta * time_speed, 1.0)
	rain_intensity = move_toward(rain_intensity, rain_target, delta * (0.75 if rain_target > rain_intensity else 0.34))
	reasoning_energy = move_toward(reasoning_energy, 0.12, delta * 0.28)
	city_energy = move_toward(city_energy, 0.24, delta * 0.16)
	for index in range(vehicles.size() - 1, -1, -1):
		var vehicle := vehicles[index]
		vehicle.progress += vehicle.speed * delta
		if vehicle.progress > 1.12:
			vehicles.remove_at(index)
	queue_redraw()
	pass


func _draw() -> void:
	if size.x < 240.0 or size.y < 180.0:
		return
	var pixel := pixel_size()
	draw_sky_layer(pixel)
	draw_city_layer(pixel)
	draw_river_layer(pixel)
	draw_bridge_layer(pixel)
	pass


func pixel_size() -> float:
	return clampf(floorf(minf(size.x / 320.0, size.y / 180.0) * 3.0), MIN_PIXEL_SIZE, MAX_PIXEL_SIZE)


func reading_safe_rect() -> Rect2:
	return Rect2(size.x * 0.22, size.y * 0.16, size.x * 0.56, size.y * 0.50)


func draw_sky_layer(pixel: float) -> void:
	var daylight := daylight_at(time_of_day)
	var night_color := Color("101a35") if ThemeColor.is_dark_theme() else Color("72829d")
	var day_color := Color("5ba8d1") if ThemeColor.is_dark_theme() else Color("4b7894")
	var sky_color := night_color.lerp(day_color, daylight)
	var sky_bottom := size.y * SKY_BOTTOM_RATIO
	for band in range(8):
		var band_ratio := float(band) / 7.0
		var band_color := sky_color.lerp(Color("f09a72"), (1.0 - daylight) * band_ratio * 0.16)
		var band_top := floorf(sky_bottom * float(band) / 8.0)
		var band_bottom := floorf(sky_bottom * float(band + 1) / 8.0)
		var band_rect := Rect2(0.0, band_top, size.x, band_bottom - band_top)
		draw_rect(band_rect, Color(band_color, 0.055 + band_ratio * 0.025))
	draw_stars(pixel, daylight)
	draw_celestial_body(pixel, daylight)
	draw_clouds(pixel, daylight)
	draw_rain(pixel)
	pass


func draw_stars(pixel: float, daylight: float) -> void:
	var alpha := (1.0 - daylight) * (1.0 - rain_intensity) * 0.55
	if alpha <= 0.01:
		return
	for index in range(38):
		var x := stable_random(index, 11) * size.x
		var y := stable_random(index, 17) * size.y * 0.48
		var pulse := 0.55 + 0.45 * sin(elapsed * (1.2 + stable_random(index, 19)) + float(index))
		var star_size := pixel if index % 7 else pixel * 2.0
		draw_rect(Rect2(snappedf(x, pixel), snappedf(y, pixel), star_size, star_size), Color(0.80, 0.90, 1.0, alpha * pulse))
	pass


func draw_celestial_body(pixel: float, daylight: float) -> void:
	var sun_progress := clampf((time_of_day - 0.23) / 0.54, 0.0, 1.0)
	var moon_time := fposmod(time_of_day + 0.5, 1.0)
	var moon_progress := clampf((moon_time - 0.23) / 0.54, 0.0, 1.0)
	var sun_position := celestial_position(sun_progress)
	var moon_position := celestial_position(moon_progress)
	draw_pixel_disc(sun_position, pixel * 5.0, Color(1.0, 0.75, 0.28, daylight * (1.0 - rain_intensity * 0.75) * 0.75), pixel)
	draw_pixel_disc(moon_position, pixel * 4.0, Color(0.77, 0.88, 1.0, (1.0 - daylight) * (1.0 - rain_intensity * 0.55) * 0.70), pixel)
	pass


func celestial_position(progress: float) -> Vector2:
	var x := lerpf(size.x * 0.14, size.x * 0.86, progress)
	var arc := sin(progress * PI)
	return Vector2(x, size.y * (0.29 - arc * 0.18))


func draw_clouds(pixel: float, daylight: float) -> void:
	var safe := reading_safe_rect()
	for index in range(7):
		var speed := 4.0 + float(index % 3) * 2.0 + reasoning_energy * 8.0
		var x := fposmod(stable_random(index, 29) * (size.x + 240.0) + elapsed * speed, size.x + 240.0) - 120.0
		var y := size.y * (0.09 + stable_random(index, 31) * 0.34)
		var width := pixel * (11.0 + stable_random(index, 37) * 14.0)
		var cloud_alpha := (0.07 + rain_intensity * 0.13) * (0.7 + daylight * 0.3)
		if safe.has_point(Vector2(x, y)):
			cloud_alpha *= 0.35
		var cloud_color := Color(0.72, 0.79, 0.86, cloud_alpha)
		draw_rect(Rect2(snappedf(x, pixel), snappedf(y, pixel), snappedf(width, pixel), pixel * 3.0), cloud_color)
		draw_rect(Rect2(snappedf(x + width * 0.18, pixel), snappedf(y - pixel * 2.0, pixel), snappedf(width * 0.38, pixel), pixel * 2.0), cloud_color)
	pass


func draw_rain(pixel: float) -> void:
	if rain_intensity <= 0.01:
		return
	var safe := reading_safe_rect()
	var count := int(40.0 + rain_intensity * 72.0)
	for index in range(count):
		var x := fposmod(stable_random(index, 41) * size.x + elapsed * (92.0 + stable_random(index, 43) * 54.0), size.x)
		var y := fposmod(stable_random(index, 47) * size.y + elapsed * (190.0 + stable_random(index, 53) * 130.0), size.y)
		var alpha := rain_intensity * 0.34
		if safe.has_point(Vector2(x, y)):
			alpha *= 0.22
		var start := Vector2(snappedf(x, pixel), snappedf(y, pixel))
		draw_line(start, start + Vector2(-pixel, pixel * 3.0), Color(0.49, 0.76, 0.96, alpha), pixel, false)
	pass


func draw_city_layer(pixel: float) -> void:
	var daylight := daylight_at(time_of_day)
	var horizon := size.y * HORIZON_RATIO
	var building_width := pixel * 8.0
	var count := ceili(size.x / building_width) + 2
	for index in range(count):
		var x := float(index) * building_width - pixel * 4.0
		var depth := stable_random(index, 59)
		var height := size.y * lerpf(0.09, 0.29, stable_random(index, 61))
		var width := building_width + pixel * floorf(stable_random(index, 67) * 5.0)
		var top := snappedf(horizon - height, pixel)
		var body_alpha := lerpf(0.15, 0.25, depth) * (0.86 + rain_intensity * 0.14)
		if x + width > size.x * 0.22 and x < size.x * 0.78:
			body_alpha *= 0.62
		var building_color := Color(Color("17243c").lerp(Color("35536c"), daylight * 0.58), body_alpha)
		draw_rect(Rect2(x, top, width, horizon - top), building_color)
		draw_rooftop(index, Rect2(x, top, width, horizon - top), pixel, building_color)
		draw_windows(index, Rect2(x, top, width, horizon - top), pixel, daylight, body_alpha)
	pass


func draw_rooftop(index: int, building: Rect2, pixel: float, color: Color) -> void:
	if index % 4 == 0:
		draw_rect(Rect2(building.position.x + building.size.x * 0.5, building.position.y - pixel * 4.0, pixel, pixel * 4.0), color)
	elif index % 5 == 0:
		draw_rect(Rect2(building.position.x + pixel * 2.0, building.position.y - pixel * 2.0, building.size.x - pixel * 4.0, pixel * 2.0), color)
	pass


func draw_windows(index: int, building: Rect2, pixel: float, daylight: float, body_alpha: float) -> void:
	var columns := maxi(1, floori((building.size.x - pixel * 3.0) / (pixel * 3.0)))
	var rows := maxi(1, floori((building.size.y - pixel * 3.0) / (pixel * 4.0)))
	var night_light := 1.0 - daylight * 0.78
	for row in range(rows):
		for column in range(columns):
			var seed := index * 101 + row * 17 + column
			if stable_random(seed, 71) > 0.42 + city_energy * 0.18:
				continue
			var flicker := 0.72 + 0.28 * sin(elapsed * (1.0 + stable_random(seed, 73) * 2.0) + float(seed))
			var alpha := minf(0.82, (0.16 + night_light * 0.42 + city_energy * 0.16) * flicker)
			alpha *= clampf(body_alpha / 0.18, 0.45, 1.0)
			var position := building.position + Vector2(pixel * (1.5 + float(column) * 3.0), pixel * (1.5 + float(row) * 4.0))
			draw_rect(Rect2(position, Vector2(pixel, pixel * 1.5)), Color(1.0, 0.73, 0.30, alpha))
	pass


func draw_river_layer(pixel: float) -> void:
	var river_top := size.y * RIVER_TOP_RATIO
	var daylight := daylight_at(time_of_day)
	var water_color := Color("12344d").lerp(Color("287895"), daylight * 0.55)
	draw_rect(Rect2(0.0, river_top, size.x, size.y - river_top), Color(water_color, 0.12 + rain_intensity * 0.035))
	var line_count := floori((size.y - river_top) / (pixel * 3.0))
	for row in range(line_count):
		var y := river_top + float(row) * pixel * 3.0
		var perspective := float(row) / float(maxi(line_count - 1, 1))
		var speed := 9.0 + perspective * 28.0 + reasoning_energy * 12.0
		var offset := fposmod(elapsed * speed + float(row * 31), pixel * 18.0)
		var alpha := 0.07 + perspective * 0.09 + rain_intensity * 0.06
		for segment in range(ceili(size.x / (pixel * 18.0)) + 1):
			var x := float(segment) * pixel * 18.0 + offset - pixel * 18.0
			var length := pixel * (5.0 + float((row + segment) % 6))
			draw_rect(Rect2(snappedf(x, pixel), snappedf(y, pixel), length, pixel), Color(0.42, 0.76, 0.89, alpha))
	draw_city_reflections(pixel, river_top)
	pass


func draw_city_reflections(pixel: float, river_top: float) -> void:
	var daylight := daylight_at(time_of_day)
	for index in range(20):
		var x := stable_random(index, 79) * size.x
		var width := pixel * (1.0 + float(index % 3))
		var height := pixel * (5.0 + stable_random(index, 83) * 19.0)
		var wobble := sin(elapsed * 1.8 + float(index)) * pixel * 2.0
		var color := Color(1.0, 0.66, 0.26, (1.0 - daylight * 0.62) * 0.15)
		draw_rect(Rect2(snappedf(x + wobble, pixel), river_top + pixel * 2.0, width, height), color)
	pass


func draw_bridge_layer(pixel: float) -> void:
	var top := snappedf(size.y * BRIDGE_TOP_RATIO, pixel)
	var bottom := snappedf(size.y * BRIDGE_BOTTOM_RATIO, pixel)
	var bridge_color := VisualColor.appearance_color(ThemeColor.accent_theme_color(), -0.04, 0.72, 0.82)
	var bridge_alpha := 0.34 if ThemeColor.is_dark_theme() else 0.22
	var road_y := top + pixel * 7.0
	draw_rect(Rect2(0.0, road_y, size.x, pixel * 4.0), Color(bridge_color, bridge_alpha))
	draw_rect(Rect2(0.0, road_y + pixel * 5.0, size.x, pixel), Color(bridge_color, bridge_alpha * 0.74))
	var span := pixel * 20.0
	var span_count := ceili(size.x / span)
	for index in range(span_count + 1):
		var x := float(index) * span
		draw_line(Vector2(x, road_y), Vector2(x + span * 0.5, bottom), Color(bridge_color, bridge_alpha * 0.72), pixel, false)
		draw_line(Vector2(x + span * 0.5, bottom), Vector2(x + span, road_y), Color(bridge_color, bridge_alpha * 0.72), pixel, false)
		if index % 3 == 0:
			draw_rect(Rect2(x, road_y, pixel * 2.0, size.y - road_y), Color(bridge_color, bridge_alpha * 0.62))
	draw_bridge_lights(pixel, road_y, bridge_color)
	for vehicle: VehicleState in vehicles:
		draw_vehicle(vehicle, pixel, road_y)
	pass


func draw_bridge_lights(pixel: float, road_y: float, bridge_color: Color) -> void:
	var spacing := pixel * 16.0
	var count := ceili(size.x / spacing) + 1
	for index in range(count):
		var x := float(index) * spacing
		var pulse := 0.74 + 0.26 * sin(elapsed * 2.0 + float(index) * 0.7)
		draw_rect(Rect2(x, road_y - pixel * 3.0, pixel, pixel * 3.0), Color(bridge_color, 0.28))
		draw_rect(Rect2(x - pixel, road_y - pixel * 4.0, pixel * 3.0, pixel), Color(1.0, 0.76, 0.34, 0.48 * pulse))
	pass


func draw_vehicle(vehicle: VehicleState, pixel: float, road_y: float) -> void:
	var x := lerpf(-pixel * 14.0, size.x + pixel * 14.0, vehicle.progress)
	var lane_offset := pixel * (1.0 + float(vehicle.lane) * 2.0)
	var y := road_y - pixel * 2.0 + lane_offset
	var color := ThemeColor.accent_theme_color()
	if vehicle.result == VehicleResult.SUCCESS:
		color = Colors.success
	elif vehicle.result == VehicleResult.FAILED:
		color = Colors.error
	var length := pixel * (8.0 + float(vehicle.seed % 5))
	draw_rect(Rect2(snappedf(x, pixel), snappedf(y, pixel), length, pixel * 2.0), Color(color, 0.78))
	draw_rect(Rect2(snappedf(x + pixel * 2.0, pixel), snappedf(y - pixel, pixel), length * 0.48, pixel), Color(color, 0.50))
	draw_rect(Rect2(snappedf(x + length, pixel), snappedf(y, pixel), pixel * 2.0, pixel), Color(1.0, 0.82, 0.42, 0.68))
	pass


func draw_pixel_disc(center: Vector2, radius: float, color: Color, pixel: float) -> void:
	if color.a <= 0.01:
		return
	var cells := ceili(radius / pixel)
	for y_cell in range(-cells, cells + 1):
		for x_cell in range(-cells, cells + 1):
			var offset := Vector2(float(x_cell), float(y_cell)) * pixel
			if offset.length_squared() > radius * radius:
				continue
			var position := Vector2(snappedf(center.x + offset.x, pixel), snappedf(center.y + offset.y, pixel))
			draw_rect(Rect2(position, Vector2(pixel, pixel)), color)
	pass


static func daylight_at(day_time: float) -> float:
	var elevation := sin(fposmod(day_time, 1.0) * TAU - PI * 0.5)
	return smoothstep(-0.18, 0.24, elevation)


static func stable_random(seed: int, salt: int) -> float:
	return fposmod(sin(float(seed * 92821 + salt * 68917)) * 43758.5453, 1.0)
