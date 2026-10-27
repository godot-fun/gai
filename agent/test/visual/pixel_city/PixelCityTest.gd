extends RefCounted


static func visual_type_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIXEL_CITY)
	assert(effect != null)
	effect.free()
	pass


static func daylight_cycle_distinguishes_day_and_night_test() -> void:
	assert(PixelCity.daylight_at(0.5) > 0.95)
	assert(PixelCity.daylight_at(0.0) < 0.05)
	pass


func tool_execution_starts_rain_and_bridge_vehicle_test() -> void:
	var effect := PixelCity.new()
	effect.on_tool_execution_start(1, "tool-1", "read_file", {})
	assert(effect.active_tool_count == 1)
	assert(effect.rain_target > 0.0)
	assert(effect.vehicles.size() == 1)
	assert(effect.vehicles[0].result == PixelCity.VehicleResult.RUNNING)
	effect.on_tool_execution_end(1, "tool-1", "read_file", AgentToolResult.ok("done"))
	assert(effect.active_tool_count == 0)
	assert(effect.rain_target == 0.0)
	assert(effect.vehicles[0].result == PixelCity.VehicleResult.SUCCESS)
	assert(effect.vehicles[0].exiting)
	effect.free()
	pass


func failed_tool_marks_vehicle_test() -> void:
	var effect := PixelCity.new()
	effect.on_tool_execution_start(1, "tool-error", "write_file", {})
	effect.on_tool_execution_end(1, "tool-error", "write_file", AgentToolResult.error("failed"))
	assert(effect.vehicles[0].result == PixelCity.VehicleResult.FAILED)
	effect.free()
	pass


func layout_keeps_bridge_below_reading_area_test() -> void:
	var effect := PixelCity.new()
	effect.size = Vector2(1280.0, 720.0)
	var safe := effect.reading_safe_rect()
	assert(safe.end.y <= effect.size.y * PixelCity.BRIDGE_TOP_RATIO)
	assert(PixelCity.RIVER_TOP_RATIO >= PixelCity.HORIZON_RATIO)
	effect.free()
	pass


func vehicle_count_is_bounded_test() -> void:
	var effect := PixelCity.new()
	for index in range(PixelCity.MAX_VEHICLES + 6):
		effect.on_tool_execution_start(1, "tool-%d" % index, "read_file", {})
	assert(effect.vehicles.size() == PixelCity.MAX_VEHICLES)
	effect.free()
	pass


func render_smoke_test() -> void:
	var effect := PixelCity.new()
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
	assert(effect.rain_intensity > 0.0)
	assert(effect.vehicles[0].progress > -0.08)
	effect.get_parent().remove_child(effect)
	effect.free()
	pass
