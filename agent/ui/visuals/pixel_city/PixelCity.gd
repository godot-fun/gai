class_name PixelCity
extends VisualEffect

## Node-based pixel city coordinator. Every independently moving visual element is a
## child node; this root only maps agent events into camera, weather, and city state.

const HORIZON_RATIO := 0.56
## Near skyline and water share one shoreline so no empty band shows between them.
const RIVER_TOP_RATIO := HORIZON_RATIO
const BRIDGE_TOP_RATIO := 0.70
const MAX_VEHICLES := 10
const MIN_PIXEL_SIZE := 3.0
const MAX_PIXEL_SIZE := 8.0
const CRUISE_SPEED := 12.0
const AMBIENT_WEATHER_SECONDS := 48.0
const RIVER_SURFACE_SHADER: Shader = preload("res://agent/ui/visuals/pixel_city/PixelRiverSurface.gdshader")

enum VehicleResult { RUNNING, SUCCESS, FAILED }

var vehicles: Array[PixelVehicle] = []
var elapsed: float = 0.0
var time_of_day: float = 0.5
var camera_x: float = 0.0
var camera_speed: float = 0.0
var target_camera_speed: float = 0.0
var reasoning_energy: float = 0.0
var city_energy: float = 0.0
var rain_intensity: float = 0.0
var rain_target: float = 0.0
var active_tool_count: int = 0
var turn_serial: int = 0
var completing: bool = false
var ended_with_error: bool = false

var sky_background: PixelSkyBackground
var star_field: PixelStarField
var sun: PixelCelestialBody
var moon: PixelCelestialBody
var cloud_layer: PixelCloudLayer
var far_city_layer: PixelCityLayer
var near_city_layer: PixelCityLayer
var river: PixelRiver
var bridge_layer: PixelBridgeLayer
var vehicle_layer: Node2D
var weather: PixelWeather


func _init() -> void:
	build_layer_nodes()
	pass


func _ready() -> void:
	super._ready()
	bind_scene_nodes()
	pass


func build_layer_nodes() -> void:
	if has_node("SkyBackground"):
		return
	var sky := PixelSkyBackground.new()
	sky.name = "SkyBackground"
	add_child(sky)
	var stars := PixelStarField.new()
	stars.name = "StarField"
	add_child(stars)
	var sun_body := PixelCelestialBody.new()
	sun_body.name = "Sun"
	add_child(sun_body)
	var moon_body := PixelCelestialBody.new()
	moon_body.name = "Moon"
	moon_body.is_moon = true
	add_child(moon_body)
	var clouds := PixelCloudLayer.new()
	clouds.name = "CloudLayer"
	add_child(clouds)
	var far_city := PixelCityLayer.new()
	far_city.name = "FarCityLayer"
	far_city.parallax_factor = 0.12
	far_city.horizon_ratio = 0.52
	far_city.distant = true
	add_child(far_city)
	var near_city := PixelCityLayer.new()
	near_city.name = "NearCityLayer"
	add_child(near_city)
	var river_material := ShaderMaterial.new()
	river_material.resource_local_to_scene = true
	river_material.shader = RIVER_SURFACE_SHADER
	var river_node := PixelRiver.new()
	river_node.name = "River"
	river_node.material = river_material
	add_child(river_node)
	var bridge := PixelBridgeLayer.new()
	bridge.name = "BridgeLayer"
	add_child(bridge)
	var vehicles := Node2D.new()
	vehicles.name = "VehicleLayer"
	add_child(vehicles)
	var weather_node := PixelWeather.new()
	weather_node.name = "Weather"
	add_child(weather_node)
	pass


func bind_scene_nodes() -> void:
	if sky_background != null:
		return
	build_layer_nodes()
	sky_background = get_node_or_null("SkyBackground") as PixelSkyBackground
	star_field = get_node_or_null("StarField") as PixelStarField
	sun = get_node_or_null("Sun") as PixelCelestialBody
	moon = get_node_or_null("Moon") as PixelCelestialBody
	cloud_layer = get_node_or_null("CloudLayer") as PixelCloudLayer
	far_city_layer = get_node_or_null("FarCityLayer") as PixelCityLayer
	near_city_layer = get_node_or_null("NearCityLayer") as PixelCityLayer
	river = get_node_or_null("River") as PixelRiver
	bridge_layer = get_node_or_null("BridgeLayer") as PixelBridgeLayer
	vehicle_layer = get_node_or_null("VehicleLayer") as Node2D
	weather = get_node_or_null("Weather") as PixelWeather
	pass


func fade_in_seconds() -> float:
	return 0.7


func fade_out_seconds() -> float:
	return 0.8


func on_agent_start(_session_id: int) -> void:
	bind_scene_nodes()
	var clock := Time.get_time_dict_from_system()
	var hour := float(clock.get("hour", 12))
	var minute := float(clock.get("minute", 0))
	time_of_day = fposmod((hour + minute / 60.0) / 24.0, 1.0)
	reasoning_energy = 0.22
	city_energy = 0.3
	target_camera_speed = CRUISE_SPEED
	update_child_nodes()
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	completing = true
	ended_with_error = StringUtils.is_not_blank(error_message)
	target_camera_speed = 0.0
	for vehicle: PixelVehicle in vehicles:
		vehicle.exiting = true
		vehicle.speed = maxf(vehicle.speed, 0.42)
	pass


func on_turn_start(_session_id: int) -> void:
	turn_serial += 1
	pass


func on_turn_end(_session_id: int) -> void:
	pass


func on_message_update(_session_id: int, _chunk: String, _stream_kind: String) -> void:
	# Streaming content must not perturb the environment timeline. Only bridge
	# vehicles visualize agent events, keeping the background motion continuous.
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	bind_scene_nodes()
	active_tool_count += 1
	spawn_vehicle(tool_call_id, tool_name)
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	active_tool_count = maxi(active_tool_count - 1, 0)
	for vehicle: PixelVehicle in vehicles:
		if vehicle.tool_call_id != tool_call_id or vehicle.result != VehicleResult.RUNNING:
			continue
		vehicle.result = VehicleResult.FAILED if result.is_error else VehicleResult.SUCCESS
		vehicle.exiting = true
		vehicle.speed = maxf(vehicle.speed, 0.28)
		vehicle.queue_redraw()
		break
	pass


func spawn_vehicle(tool_call_id: String, tool_name: String) -> void:
	if vehicle_layer == null:
		return
	if vehicles.size() >= MAX_VEHICLES:
		var oldest: PixelVehicle = vehicles.pop_front()
		oldest.queue_free()
	var vehicle := PixelVehicle.new()
	vehicle.name = "Vehicle_%d" % absi(tool_call_id.hash())
	vehicle.tool_call_id = tool_call_id
	vehicle.seed = absi((tool_name + tool_call_id).hash())
	vehicle.lane = vehicle.seed % 2
	vehicle.progress = -0.08 - float(vehicles.size() % 3) * 0.06
	vehicle.speed = 0.09 + stable_random(vehicle.seed, 3) * 0.055
	vehicle_layer.add_child(vehicle)
	vehicles.append(vehicle)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	var acceleration := 18.0 if target_camera_speed > camera_speed else 10.0
	camera_speed = move_toward(camera_speed, target_camera_speed, delta * acceleration)
	camera_x += camera_speed * delta
	var time_speed := 0.0012 + reasoning_energy * 0.0022
	time_of_day = fposmod(time_of_day + delta * time_speed, 1.0)
	if not completing:
		rain_target = ambient_rain_at(elapsed)
	rain_intensity = move_toward(rain_intensity, rain_target, delta * (0.75 if rain_target > rain_intensity else 0.34))
	update_vehicles(delta)
	update_child_nodes()
	pass


func update_vehicles(delta: float) -> void:
	for index in range(vehicles.size() - 1, -1, -1):
		var vehicle := vehicles[index]
		vehicle.progress += vehicle.speed * delta
		vehicle.update_layout(size, pixel_size())
		if vehicle.progress <= 1.12:
			continue
		vehicles.remove_at(index)
		vehicle.queue_free()
	pass


func update_child_nodes() -> void:
	bind_scene_nodes()
	var pixel := pixel_size()
	# Appearance follows the app surface: light theme owns the daytime palette and
	# sun, while dark theme owns the nighttime palette and moon. System clock no
	# longer makes a light UI unexpectedly show a night scene (or vice versa).
	var daylight := 0.0 if ThemeColor.is_dark_theme() else 1.0
	if sky_background != null:
		sky_background.update_visual(size, daylight, rain_intensity)
	if star_field != null:
		star_field.update_visual(size, pixel, elapsed, daylight, rain_intensity, camera_x)
	if sun != null:
		sun.update_visual(size, pixel, time_of_day, daylight, rain_intensity, false)
	if moon != null:
		moon.update_visual(size, pixel, time_of_day, daylight, rain_intensity, true)
	if cloud_layer != null:
		cloud_layer.update_visual(size, pixel, camera_x, elapsed, daylight, rain_intensity, reasoning_energy)
	if near_city_layer != null:
		near_city_layer.update_visual(size, pixel, camera_x, elapsed, daylight, city_energy, rain_intensity)
	if far_city_layer != null:
		var foreground_rectangles: Array[Rect2] = near_city_layer.body_occlusion_rectangles() if near_city_layer != null else []
		far_city_layer.set_occlusion_rectangles(foreground_rectangles)
		far_city_layer.update_visual(size, pixel, camera_x, elapsed, daylight, city_energy, rain_intensity)
	if river != null:
		river.update_visual(size, pixel, camera_x, elapsed, daylight, rain_intensity, reasoning_energy)
	if bridge_layer != null:
		bridge_layer.update_visual(size, pixel, camera_x, elapsed)
	if weather != null:
		weather.update_visual(size, pixel, elapsed, rain_intensity)
	pass


func pixel_size() -> float:
	return clampf(floorf(minf(size.x / 320.0, size.y / 180.0) * 3.0), MIN_PIXEL_SIZE, MAX_PIXEL_SIZE)


func reading_safe_rect() -> Rect2:
	return Rect2(size.x * 0.22, size.y * 0.16, size.x * 0.56, size.y * 0.50)


static func daylight_at(day_time: float) -> float:
	var elevation := sin(fposmod(day_time, 1.0) * TAU - PI * 0.5)
	return smoothstep(-0.18, 0.24, elevation)


static func ambient_rain_at(environment_seconds: float) -> float:
	var phase := fposmod(environment_seconds, AMBIENT_WEATHER_SECONDS)
	if phase < 24.0:
		return 0.0
	if phase < 30.0:
		return smoothstep(24.0, 30.0, phase) * 0.62
	if phase < 38.0:
		return 0.62
	return (1.0 - smoothstep(38.0, AMBIENT_WEATHER_SECONDS, phase)) * 0.62


static func stable_random(seed: int, salt: int) -> float:
	return fposmod(sin(float(seed * 92821 + salt * 68917)) * 43758.5453, 1.0)
