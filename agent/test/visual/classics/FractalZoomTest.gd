extends RefCounted


## A dive target is useful only if the deepest view still straddles the set boundary; a target
## inside or far outside the set would zoom into a flat screen.
static func every_target_sits_on_the_set_boundary_test() -> void:
	for index in range(FractalZoom.target_count()):
		var cx := FractalZoom.TARGETS[index * 2]
		var cy := FractalZoom.TARGETS[index * 2 + 1]
		var inside := 0
		var low := 1 << 30
		var high := -1
		for y in range(-3, 4):
			for x in range(-3, 4):
				var iteration := FractalZoom.escape_iteration(cx + float(x) * FractalZoom.MIN_SCALE / 3.0, cy + float(y) * FractalZoom.MIN_SCALE / 3.0, 1500)
				if iteration < 0:
					inside += 1
				else:
					low = mini(low, iteration)
					high = maxi(high, iteration)
		assert(high >= 0, "target %d is fully inside the set" % index)
		assert(inside > 0 or high - low >= 12, "target %d has no detail at the deepest zoom" % index)
	pass


static func zoom_keeps_target_fixed_on_screen_test() -> void:
	var effect := FractalZoom.new()
	effect.target_index = 0
	effect.depth = 0.0
	assert(effect.current_center().is_equal_approx(FractalZoom.HOME))
	assert(is_equal_approx(effect.current_scale(), FractalZoom.HOME_SCALE))
	effect.depth = 1.0
	assert(is_equal_approx(effect.current_scale(), FractalZoom.MIN_SCALE))
	var target := Vector2(FractalZoom.TARGETS[0], FractalZoom.TARGETS[1])
	assert(effect.current_center().distance_to(target) < FractalZoom.MIN_SCALE)
	assert(effect.current_iterations() == FractalZoom.MAX_ITERATIONS)
	effect.free()
	pass


func zoom_stream_dives_faster_test() -> void:
	var effect := FractalZoom.new()
	effect.on_agent_start(1)
	var idle := effect.current_dive_speed()
	for _index in range(10):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.current_dive_speed() > idle)
	effect.step_zoom(0.5)
	assert(effect.depth > 0.0)
	effect.free()
	pass


func zoom_tool_surfaces_into_its_target_test() -> void:
	var effect := FractalZoom.new()
	effect.on_agent_start(1)
	var tool_name := "grep"
	effect.target_index = (FractalZoom.target_for(tool_name) + 1) % FractalZoom.target_count()
	effect.depth = 0.5
	effect.on_tool_execution_start(1, "t1", tool_name, {} as Dictionary[String, Variant])
	assert(effect.next_target_index == FractalZoom.target_for(tool_name))
	for _index in range(60):
		effect.step_zoom(1.0 / 60.0)
	assert(effect.target_index == FractalZoom.target_for(tool_name))
	assert(effect.next_target_index == -1)
	effect.on_tool_execution_end(1, "t1", tool_name, AgentToolResult.ok("done"))
	assert(effect.pulse == 1.0)
	effect.on_tool_execution_end(1, "t2", tool_name, AgentToolResult.error("boom"))
	assert(effect.failure_tint == 1.0)
	effect.free()
	pass


func zoom_end_surfaces_to_the_whole_set_test() -> void:
	var effect := FractalZoom.new()
	effect.on_agent_start(1)
	effect.depth = 0.8
	await effect.on_agent_end(1, "")
	for _index in range(70):
		effect.step_zoom(1.0 / 60.0)
	assert(effect.depth == 0.0)
	effect.free()
	pass
