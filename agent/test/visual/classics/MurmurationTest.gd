extends RefCounted


func flock_tokens_hatch_birds_up_to_cap_test() -> void:
	var effect := Murmuration.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	assert(effect.positions.size() == Murmuration.START_BIRDS)
	for _index in range(400):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	effect.step_flock(1.0 / 60.0)
	assert(effect.positions.size() == Murmuration.MAX_BIRDS)
	assert(effect.velocities.size() == effect.positions.size())
	assert(effect.tags.size() == effect.positions.size())
	effect.free()
	pass


func flock_speeds_stay_in_bounds_test() -> void:
	var effect := Murmuration.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	for _index in range(120):
		effect.step_flock(1.0 / 60.0)
	for velocity: Vector2 in effect.velocities:
		assert(velocity.length() >= Murmuration.MIN_SPEED - 0.01)
		assert(velocity.length() <= Murmuration.STREAM_SPEED * 1.6 + 0.01)
	effect.free()
	pass


func flock_grid_finds_close_neighbors_test() -> void:
	var effect := Murmuration.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.hatch(Vector2(100.0, 100.0), Vector2.RIGHT * 100.0, 0.5)
	effect.hatch(Vector2(110.0, 100.0), Vector2.RIGHT * 100.0, 0.5)
	effect.hatch(Vector2(900.0, 600.0), Vector2.LEFT * 100.0, 0.5)
	effect.build_grid()
	assert(effect.flock_force(0, Murmuration.COHESION_WEIGHT).x < 0.0)
	assert(effect.flock_force(2, Murmuration.COHESION_WEIGHT) == Vector2.ZERO)
	effect.free()
	pass


func flock_roosts_on_running_tools_and_flees_hawks_test() -> void:
	var effect := Murmuration.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	var anchor := SimulationEffect.tool_anchor("grep") * effect.size
	effect.hatch(anchor + Vector2(300.0, 0.0), Vector2.ZERO, 0.5)
	assert(effect.roost_force(0).x < 0.0)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.roosts.is_empty())
	assert(effect.hawks.size() == 1 and effect.hawks[0].z == 1.0)
	effect.positions[0] = anchor + Vector2(50.0, 0.0)
	assert(effect.hawk_force(0).x > 0.0)
	effect.free()
	pass


func flock_leaves_the_window_at_the_end_test() -> void:
	var effect := Murmuration.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	await effect.on_agent_end(1, "")
	assert(effect.leaving)
	for _index in range(600):
		effect.step_flock(1.0 / 60.0)
	assert(effect.count_visible() == 0)
	effect.free()
	pass
