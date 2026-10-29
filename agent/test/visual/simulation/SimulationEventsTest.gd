func ripple_content_stream_drops_along_caret_test() -> void:
	var effect := RippleSurface.new()
	effect.on_agent_start(1)
	effect.impulse_shapes.clear()
	var start_caret := effect.caret
	for _index in range(20):
		effect.on_message_update(1, "answer chunk text", OpenAiClient.STREAM_KIND_CONTENT)
	effect.step_field(1.0 / 60.0)
	assert(effect.impulse_shapes.size() > 0)
	assert(effect.impulse_shapes.size() <= RippleSurface.MAX_DROPS_PER_FRAME)
	assert(effect.caret != start_caret)
	effect.free()
	pass


func ripple_tool_stone_lands_on_tool_anchor_test() -> void:
	var effect := RippleSurface.new()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	var shape: Vector4 = effect.impulse_shapes[0]
	assert(Vector2(shape.x, shape.y).is_equal_approx(SimulationEffect.tool_anchor("grep")))
	assert(shape.w < 0.0)
	effect.free()
	pass


func ripple_end_switches_to_settle_damping_test() -> void:
	var effect := RippleSurface.new()
	await effect.on_agent_end(1, "")
	assert(effect.damping < RippleSurface.RUN_DAMPING)
	effect.free()
	pass


static func turing_regime_moves_from_maze_to_coral_to_dissolve_test() -> void:
	assert(TuringBloom.regime_for(0.0, 0.0).is_equal_approx(TuringBloom.MAZE_REGIME))
	assert(TuringBloom.regime_for(1.0, 0.0).is_equal_approx(TuringBloom.CORAL_REGIME))
	assert(TuringBloom.regime_for(0.3, 1.0).is_equal_approx(TuringBloom.DISSOLVE_REGIME))
	pass


func turing_content_targets_coral_and_seeds_colonies_test() -> void:
	var effect := TuringBloom.new()
	effect.on_agent_start(1)
	effect.impulse_shapes.clear()
	for _index in range(12):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(is_equal_approx(effect.target_pattern_mix, 1.0))
	assert(effect.current_growth() > TuringBloom.IDLE_GROWTH)
	effect.step_field(1.0 / 60.0)
	assert(effect.impulse_shapes.size() > 0)
	effect.on_message_update(1, "thinking", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.target_pattern_mix == 0.0)
	effect.free()
	pass


func turing_end_starves_the_tissue_test() -> void:
	var effect := TuringBloom.new()
	await effect.on_agent_end(1, "")
	assert(effect.target_dissolve == 1.0)
	effect.free()
	pass


func thermal_stream_raises_sensitivity_test() -> void:
	var effect := ThermalTrace.new()
	assert(effect.reads_previous_frame())
	var idle_sensitivity := effect.current_sensitivity()
	effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.current_sensitivity() > idle_sensitivity)
	effect.free()
	pass


func thermal_tool_error_flares_heat_test() -> void:
	var effect := ThermalTrace.new()
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.failure_tint == 1.0)
	assert(effect.impulse_shapes[0].w > 1.0)
	effect.free()
	pass


func ink_pass_layout_is_advect_pressure_project_test() -> void:
	var effect := InkFluid.new()
	var kinds := effect.pass_kinds()
	assert(kinds[0] == 0)
	assert(kinds[kinds.size() - 1] == 2)
	assert(kinds.count(1) == InkFluid.PRESSURE_ITERATIONS)
	effect.free()
	pass


func ink_streams_pour_opposite_inks_test() -> void:
	var effect := InkFluid.new()
	for _index in range(10):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	effect.step_field(1.0 / 60.0)
	assert(effect.impulse_shapes[0].w > 0.0)
	assert(effect.impulse_vectors[0].y < 0.0)
	effect.impulse_shapes.clear()
	effect.impulse_vectors.clear()
	effect.content_pour = 0.0
	for _index in range(10):
		effect.on_message_update(1, "thinking about it", OpenAiClient.STREAM_KIND_REASONING)
	effect.step_field(1.0 / 60.0)
	assert(effect.impulse_shapes[0].w < 0.0)
	effect.free()
	pass


func glass_reasoning_fogs_and_answers_clear_test() -> void:
	var effect := GlassRain.new()
	effect.on_agent_start(1)
	for _index in range(30):
		effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
	var fogged := effect.fog_target
	assert(fogged > GlassRain.BASE_FOG)
	for _index in range(30):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.fog_target < fogged)
	assert(effect.rain_intensity > 0.25)
	effect.free()
	pass


func glass_tool_faucet_runs_then_closes_test() -> void:
	var effect := GlassRain.new()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.faucets.size() == 1)
	effect.step_field(1.0 / 60.0)
	assert(effect.impulse_shapes.size() >= 1)
	for _index in range(80):
		effect.step_field(1.0 / 60.0)
		effect.impulse_shapes.clear()
		effect.impulse_vectors.clear()
	assert(effect.faucets.is_empty())
	effect.free()
	pass


static func chladni_modes_are_stable_and_tools_skip_turn_modes_test() -> void:
	assert(ChladniPlate.mode_for("grep") == ChladniPlate.mode_for("grep"))
	for tool_name: String in ["grep", "read_file", "shell", "web_search"]:
		assert(ChladniPlate.MODES.find(ChladniPlate.mode_for(tool_name)) >= ChladniPlate.TURN_MODE_COUNT)
	assert(ChladniPlate.turn_mode(ChladniPlate.TURN_MODE_COUNT) == ChladniPlate.turn_mode(0))
	for mode: Vector3 in ChladniPlate.MODES:
		assert(mode.x != mode.y)
	pass


func chladni_tool_rings_its_mode_and_pours_sand_test() -> void:
	var effect := ChladniPlate.new()
	effect.on_agent_start(1)
	effect.impulse_shapes.clear()
	effect.impulse_vectors.clear()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.mode_b == ChladniPlate.mode_for("grep"))
	assert(effect.mode_a == ChladniPlate.MODES[0])
	assert(effect.mode_mix == 0.0)
	assert(effect.impulse_vectors[0].x > 0.0)
	effect.free()
	pass


func chladni_mid_sweep_keeps_dominant_mode_test() -> void:
	var effect := ChladniPlate.new()
	effect.on_agent_start(1)
	effect.ring_mode(ChladniPlate.MODES[3])
	effect.ring_mode(ChladniPlate.MODES[4])
	assert(effect.mode_a == ChladniPlate.MODES[0])
	assert(effect.mode_b == ChladniPlate.MODES[4])
	effect.free()
	pass


func chladni_stream_drives_and_end_stops_the_plate_test() -> void:
	var effect := ChladniPlate.new()
	effect.on_agent_start(1)
	var idle_target := effect.current_drive_target()
	effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.current_drive_target() > idle_target)
	for _index in range(60):
		effect.step_field(1.0 / 60.0)
	assert(effect.drive > 0.0)
	await effect.on_agent_end(1, "")
	assert(effect.current_drive_target() == 0.0)
	effect.free()
	pass


func chladni_tool_error_scatters_sand_test() -> void:
	var effect := ChladniPlate.new()
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.scatter == 1.0)
	assert(effect.failure_tint == 1.0)
	assert(effect.impulse_shapes[0].w > 0.0)
	effect.free()
	pass


func glass_tool_error_strikes_lightning_test() -> void:
	var effect := GlassRain.new()
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.lightning == 1.0)
	assert(effect.faucets.size() == 3)
	effect.free()
	pass
