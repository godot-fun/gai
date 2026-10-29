extends RefCounted


func warp_content_stream_speeds_up_past_cruise_test() -> void:
	var effect := WarpSpeed.new()
	effect.on_agent_start(1)
	assert(is_equal_approx(effect.target_speed, WarpSpeed.CRUISE_SPEED))
	effect.on_message_update(1, "thinking", OpenAiClient.STREAM_KIND_REASONING)
	assert(is_equal_approx(effect.target_speed, WarpSpeed.REASONING_SPEED))
	for _index in range(20):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.target_speed > WarpSpeed.CRUISE_SPEED)
	assert(effect.target_speed <= WarpSpeed.CRUISE_SPEED + WarpSpeed.MAX_STREAM_BOOST + 0.0001)
	effect.free()
	pass


func warp_tool_jumps_to_hyperspace_and_drops_out_test() -> void:
	var effect := WarpSpeed.new()
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.target_speed == WarpSpeed.WARP_SPEED)
	assert(effect.jump_flash == 1.0)
	assert(effect.steer_target.is_equal_approx(SimulationEffect.tool_anchor("grep") - Vector2(0.5, 0.5)))
	for _index in range(90):
		effect.step_stars(1.0 / 60.0)
	assert(effect.warp_amount() > 0.5)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(effect.target_speed < WarpSpeed.WARP_SPEED)
	assert(effect.drop_flash == 1.0)
	assert(effect.steer_target == Vector2.ZERO)
	effect.free()
	pass


func warp_failed_tool_jolts_red_test() -> void:
	var effect := WarpSpeed.new()
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.failure_tint == 1.0)
	assert(effect.shake == 1.0)
	assert(effect.drop_color == Colors.error)
	effect.free()
	pass


func warp_stars_fly_closer_and_respawn_far_test() -> void:
	var effect := WarpSpeed.new()
	effect.on_agent_start(1)
	assert(effect.stars.size() == WarpSpeed.STAR_COUNT)
	var star := Vector3(0.1, 0.1, 0.5)
	effect.stars[0] = star
	effect.speed = 1.0
	effect.step_stars(0.1)
	assert(effect.stars[0].z < star.z)
	effect.stars[1] = Vector3(0.1, 0.1, WarpSpeed.NEAR_Z * 1.01)
	effect.step_stars(0.1)
	assert(effect.stars[1].z >= 0.75)
	assert(effect.stars.size() == WarpSpeed.STAR_COUNT)
	effect.free()
	pass


func warp_end_brakes_to_a_halt_test() -> void:
	var effect := WarpSpeed.new()
	effect.on_agent_start(1)
	effect.speed = WarpSpeed.WARP_SPEED
	await effect.on_agent_end(1, "")
	assert(effect.target_speed == 0.0)
	for _index in range(240):
		effect.step_stars(1.0 / 60.0)
	assert(effect.speed < WarpSpeed.END_STOP_SPEED)
	effect.free()
	pass
