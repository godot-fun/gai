extends RefCounted


static func visual_type_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY)
	assert(effect is PixelCity)
	assert(effect.get_node("FarCityLayer") is PixelCityLayer)
	assert(effect.get_node("NearCityLayer") is PixelCityLayer)
	assert(effect.get_node("BridgeLayer") is PixelBridgeLayer)
	effect.free()
	pass


static func daylight_cycle_distinguishes_day_and_night_test() -> void:
	assert(PixelCity.daylight_at(0.5) > 0.95)
	assert(PixelCity.daylight_at(0.0) < 0.05)
	pass


func theme_selects_sun_or_moon_test() -> void:
	var original := ThemeColor.current_theme
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY) as PixelCity
	effect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	effect.size = Vector2(1280.0, 720.0)
	ThemeColor.current_theme = ThemeColor.ThemeEnum.LIGHT
	effect.update_child_nodes()
	assert(effect.sun.visible)
	assert(not effect.moon.visible)
	ThemeColor.current_theme = ThemeColor.ThemeEnum.DARK
	effect.update_child_nodes()
	assert(not effect.sun.visible)
	assert(effect.moon.visible)
	ThemeColor.current_theme = original
	effect.free()
	pass


func celestial_body_keeps_fractional_motion_test() -> void:
	var original := ThemeColor.current_theme
	ThemeColor.current_theme = ThemeColor.ThemeEnum.LIGHT
	var body := PixelCelestialBody.new()
	body.update_visual(Vector2(1280.0, 720.0), 8.0, 0.451, 1.0, 0.0, false)
	assert(not is_equal_approx(body.position.x, snappedf(body.position.x, 8.0)))
	ThemeColor.current_theme = original
	body.free()
	pass


func moon_uses_pixel_crescent_cutout_test() -> void:
	var moon_body := PixelCelestialBody.new()
	moon_body.is_moon = true
	moon_body.pixel = 8.0
	moon_body.radius = 32.0
	assert(not moon_body.should_draw_cell(Vector2.ZERO))
	assert(not moon_body.should_draw_cell(Vector2(24.0, 0.0)))
	assert(moon_body.should_draw_cell(Vector2(-24.0, 0.0)))
	assert(not moon_body.should_draw_cell(Vector2(-40.0, 0.0)))
	moon_body.free()
	pass


func river_reflections_only_show_in_dark_theme_test() -> void:
	var original := ThemeColor.current_theme
	var river := PixelRiver.new()
	ThemeColor.current_theme = ThemeColor.ThemeEnum.LIGHT
	assert(not river.should_draw_reflections())
	ThemeColor.current_theme = ThemeColor.ThemeEnum.DARK
	assert(river.should_draw_reflections())
	ThemeColor.current_theme = original
	river.free()
	pass


func river_uses_local_surface_shader_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY) as PixelCity
	var river_node := effect.get_node("River") as PixelRiver
	var river_material := river_node.material as ShaderMaterial
	assert(river_material != null)
	assert(river_material.resource_local_to_scene)
	assert(river_material.shader != null)
	effect.free()
	pass


static func window_breathing_is_sparse_and_bounded_test() -> void:
	var building := PixelBuilding.new()
	building.elapsed = 1.7
	var breathing_count := 0
	for seed in range(1000):
		var pulse := building.window_light_pulse(seed)
		assert(pulse >= 0.78 and pulse <= 1.0)
		if pulse < 0.999:
			breathing_count += 1
	assert(breathing_count >= 40 and breathing_count <= 100)
	building.free()
	pass


static func building_shapes_are_varied_and_deterministic_test() -> void:
	var building := PixelBuilding.new()
	var shapes: Dictionary[int, bool] = {}
	for index in range(80):
		building.world_index = index
		var first := building.building_shape()
		assert(building.building_shape() == first)
		shapes[first] = true
	assert(shapes.size() == PixelBuilding.Shape.size())
	building.free()
	pass


static func skyline_uses_clustered_height_rhythm_test() -> void:
	var cluster_average_a := 0.0
	var cluster_average_b := 0.0
	for index in range(PixelCityLayer.CLUSTER_SIZE):
		cluster_average_a += PixelCityLayer.cluster_height_mix(index, false)
		cluster_average_b += PixelCityLayer.cluster_height_mix(index + PixelCityLayer.CLUSTER_SIZE, false)
	cluster_average_a /= float(PixelCityLayer.CLUSTER_SIZE)
	cluster_average_b /= float(PixelCityLayer.CLUSTER_SIZE)
	assert(not is_equal_approx(cluster_average_a, cluster_average_b))
	pass


static func stars_stay_above_city_roofs_test() -> void:
	for index in range(38):
		var y_ratio := PixelStarField.star_y_ratio(index)
		assert(y_ratio >= PixelStarField.STAR_TOP_RATIO)
		assert(y_ratio <= PixelStarField.STAR_BOTTOM_RATIO)
	# The tallest near building begins at 0.27 of the viewport before its antenna,
	# leaving a clear buffer below the star field.
	assert(PixelStarField.STAR_BOTTOM_RATIO < PixelCity.HORIZON_RATIO - 0.29)
	pass


func tool_execution_only_changes_bridge_vehicle_state_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY) as PixelCity
	effect.on_agent_start(1)
	var initial_speed := effect.target_camera_speed
	var initial_rain := effect.rain_target
	var initial_reasoning := effect.reasoning_energy
	var initial_city_energy := effect.city_energy
	effect.on_tool_execution_start(1, "tool-1", "read_file", {})
	assert(effect.active_tool_count == 1)
	assert(effect.vehicles.size() == 1)
	assert(effect.vehicles[0].result == PixelCity.VehicleResult.RUNNING)
	assert(effect.target_camera_speed == initial_speed)
	assert(effect.rain_target == initial_rain)
	assert(effect.reasoning_energy == initial_reasoning)
	assert(effect.city_energy == initial_city_energy)
	effect.on_tool_execution_end(1, "tool-1", "read_file", AgentToolResult.ok("done"))
	assert(effect.active_tool_count == 0)
	assert(effect.vehicles[0].result == PixelCity.VehicleResult.SUCCESS)
	assert(effect.vehicles[0].exiting)
	assert(effect.target_camera_speed == initial_speed)
	assert(effect.rain_target == initial_rain)
	effect.free()
	pass


func streaming_events_do_not_change_environment_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY) as PixelCity
	effect.target_camera_speed = PixelCity.CRUISE_SPEED
	effect.reasoning_energy = 0.22
	effect.city_energy = 0.3
	effect.on_turn_start(1)
	effect.on_message_update(1, "reasoning tokens", OpenAiClient.STREAM_KIND_REASONING)
	effect.on_turn_end(1)
	assert(effect.target_camera_speed == PixelCity.CRUISE_SPEED)
	assert(is_equal_approx(effect.reasoning_energy, 0.22))
	assert(is_equal_approx(effect.city_energy, 0.3))
	effect.free()
	pass


static func ambient_weather_is_independent_test() -> void:
	assert(PixelCity.ambient_rain_at(0.0) == 0.0)
	assert(PixelCity.ambient_rain_at(34.0) > 0.6)
	assert(PixelCity.ambient_rain_at(47.9) < 0.01)
	pass


func failed_tool_marks_vehicle_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY) as PixelCity
	effect.on_tool_execution_start(1, "tool-error", "write_file", {})
	effect.on_tool_execution_end(1, "tool-error", "write_file", AgentToolResult.error("failed"))
	assert(effect.vehicles[0].result == PixelCity.VehicleResult.FAILED)
	effect.free()
	pass


func layout_keeps_bridge_below_reading_area_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY) as PixelCity
	effect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	effect.size = Vector2(1280.0, 720.0)
	var safe := effect.reading_safe_rect()
	assert(safe.end.y <= effect.size.y * PixelCity.BRIDGE_TOP_RATIO)
	assert(PixelCity.RIVER_TOP_RATIO >= PixelCity.HORIZON_RATIO)
	effect.free()
	pass


func vehicle_count_is_bounded_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY) as PixelCity
	for index in range(PixelCity.MAX_VEHICLES + 6):
		effect.on_tool_execution_start(1, "tool-%d" % index, "read_file", {})
	assert(effect.vehicles.size() == PixelCity.MAX_VEHICLES)
	effect.free()
	pass


func render_smoke_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY) as PixelCity
	effect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	effect.size = Vector2(1280.0, 720.0)
	Engine.get_main_loop().root.add_child.call_deferred(effect)
	await Engine.get_main_loop().process_frame
	effect.visible = true
	effect.on_agent_start(1)
	effect.on_turn_start(1)
	effect.on_message_update(1, "Inspect the city layers.", OpenAiClient.STREAM_KIND_REASONING)
	effect.on_tool_execution_start(1, "render-tool", "read_file", {})
	effect._process(0.25)
	assert(effect.pixel_size() >= PixelCity.MIN_PIXEL_SIZE)
	assert(effect.rain_intensity == 0.0)
	assert(effect.vehicles[0].progress > -0.08)
	assert(effect.vehicles[0] is PixelVehicle)
	assert(not effect.near_city_layer.buildings.is_empty())
	assert(effect.near_city_layer.buildings[0] is PixelBuilding)
	assert(not effect.bridge_layer.segments.is_empty())
	assert(effect.bridge_layer.segments[0] is PixelBridgeSegment)
	effect.get_parent().remove_child(effect)
	effect.free()
	pass


func parallax_layers_move_at_different_rates_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY) as PixelCity
	effect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	effect.size = Vector2(1280.0, 720.0)
	Engine.get_main_loop().root.add_child.call_deferred(effect)
	await Engine.get_main_loop().process_frame
	effect.visible = true
	effect.camera_x = 0.0
	effect.update_child_nodes()
	var city_start := effect.near_city_layer.buildings[1].position.x
	var bridge_start := effect.bridge_layer.segments[1].position.x
	effect.camera_x = 160.0
	effect.update_child_nodes()
	var city_delta := absf(effect.near_city_layer.buildings[1].position.x - city_start)
	var bridge_delta := absf(effect.bridge_layer.segments[1].position.x - bridge_start)
	assert(city_delta > 0.0)
	assert(bridge_delta > city_delta)
	effect.get_parent().remove_child(effect)
	effect.free()
	pass


func slow_parallax_keeps_fractional_node_motion_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY) as PixelCity
	effect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	effect.size = Vector2(1280.0, 720.0)
	Engine.get_main_loop().root.add_child.call_deferred(effect)
	await Engine.get_main_loop().process_frame
	effect.camera_x = 1.0
	effect.update_child_nodes()
	var building_x := effect.near_city_layer.buildings[1].position.x
	var pixel := effect.pixel_size()
	assert(not is_equal_approx(building_x, snappedf(building_x, pixel)))
	effect.get_parent().remove_child(effect)
	effect.free()
	pass


func only_foreground_buildings_emit_window_light_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY) as PixelCity
	effect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	effect.size = Vector2(1280.0, 720.0)
	Engine.get_main_loop().root.add_child.call_deferred(effect)
	await Engine.get_main_loop().process_frame
	effect.update_child_nodes()
	var far_building := effect.far_city_layer.buildings[2]
	var near_building := effect.near_city_layer.buildings[2]
	assert(far_building.distant)
	assert(not near_building.distant)
	assert(not far_building.emits_window_light())
	assert(near_building.emits_window_light())
	assert(near_building.body_opacity > far_building.body_opacity * 2.0)
	assert(far_building.body_rects().size() <= 2)
	effect.get_parent().remove_child(effect)
	effect.free()
	pass


func building_silhouettes_stay_translucent_in_both_themes_test() -> void:
	var original := ThemeColor.current_theme
	var building := PixelBuilding.new()
	building.daylight = 1.0
	building.body_opacity = 0.22
	ThemeColor.current_theme = ThemeColor.ThemeEnum.LIGHT
	var light_color := building.building_body_color()
	assert(is_equal_approx(light_color.a, building.body_opacity))
	assert(light_color.a < 0.3)
	ThemeColor.current_theme = ThemeColor.ThemeEnum.DARK
	var dark_color := building.building_body_color()
	assert(is_equal_approx(dark_color.a, building.body_opacity))
	ThemeColor.current_theme = original
	building.free()
	pass
