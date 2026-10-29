static func spring_overshoots_then_settles_test() -> void:
	var state := Vector2(1.0, 0.0)
	var lowest := 1.0
	for _index in range(120):
		state = Kintsugi.step_spring(state.x, state.y, 0.0, 1.0 / 60.0)
		lowest = minf(lowest, state.x)
	assert(lowest < 0.0)
	assert(absf(state.x) < 0.01)
	pass


func failed_tool_shatters_into_shards_test() -> void:
	var effect := Kintsugi.new()
	effect.on_tool_execution_end(1, "t1", "read_file", AgentToolResult.error("boom"))
	assert(effect.cracks.size() == 1)
	var crack: Variant = effect.cracks[0]
	assert(crack.shard_count >= Kintsugi.SHARD_COUNT_MIN and crack.shard_count <= Kintsugi.SHARD_COUNT_MAX)
	for _index in range(12):
		effect.step_cracks(1.0 / 60.0)
	assert(crack.open > 0.5)
	assert(crack.flow == 0.0)
	effect.free()
	pass


func break_impact_and_shake_fade_out_test() -> void:
	var effect := Kintsugi.new()
	effect.on_tool_execution_end(1, "t1", "read_file", AgentToolResult.error("boom"))
	assert(effect.cracks[0].impact == 1.0)
	assert(effect.shake == 1.0)
	effect.step_cracks(1.0 / 60.0)
	assert(effect.shake_offset.length() > 0.0)
	for _index in range(60):
		effect.step_cracks(1.0 / 60.0)
	assert(effect.cracks[0].impact == 0.0)
	assert(effect.shake == 0.0)
	assert(effect.shake_offset == Vector2.ZERO)
	effect.free()
	pass


func success_snaps_shards_home_and_keeps_gold_test() -> void:
	var effect := Kintsugi.new()
	effect.on_tool_execution_end(1, "t1", "read_file", AgentToolResult.error("boom"))
	for _index in range(30):
		effect.step_cracks(1.0 / 60.0)
	effect.on_tool_execution_end(1, "t2", "read_file", AgentToolResult.ok("fine"))
	for _index in range(180):
		effect.step_cracks(1.0 / 60.0)
	var crack: Variant = effect.cracks[0]
	assert(crack.open == 0.0)
	assert(crack.flow == 1.0)
	assert(crack.vermilion == Kintsugi.GOLD)
	assert(effect.cracks_are_idle())
	effect.free()
	pass


func clean_turn_leaves_hairline_test() -> void:
	var effect := Kintsugi.new()
	var args: Dictionary[String, Variant] = {}
	effect.on_turn_start(1)
	effect.on_tool_execution_start(1, "t1", "read_file", args)
	assert(effect.crackle > 0.0)
	effect.on_tool_execution_end(1, "t1", "read_file", AgentToolResult.ok("fine"))
	assert(effect.cracks.is_empty())
	effect.on_turn_end(1)
	assert(effect.cracks.size() == 1)
	assert(effect.cracks[0].shard_count == Kintsugi.HAIRLINE_SHARD_COUNT)
	assert(effect.cracks[0].flowing)
	effect.free()
	pass


func repaired_turn_skips_hairline_test() -> void:
	var effect := Kintsugi.new()
	effect.on_turn_start(1)
	effect.on_tool_execution_end(1, "t1", "read_file", AgentToolResult.error("boom"))
	effect.on_turn_end(1)
	assert(effect.cracks.size() == 1)
	assert(effect.cracks[0].open_target == 0.0)
	assert(effect.cracks[0].shard_count > Kintsugi.HAIRLINE_SHARD_COUNT)
	effect.free()
	pass


func crack_slots_are_capped_test() -> void:
	var effect := Kintsugi.new()
	effect.on_turn_end(1)
	for index in range(12):
		effect.on_tool_execution_end(1, "t%d" % index, "read_file", AgentToolResult.error("boom"))
	assert(effect.cracks.size() == Kintsugi.MAX_CRACKS)
	for crack: Variant in effect.cracks:
		assert(crack.shard_count > Kintsugi.HAIRLINE_SHARD_COUNT)
	effect.heal_open_cracks(Kintsugi.GOLD)
	assert(effect.add_hairline("full") == null)
	effect.free()
	pass


func error_run_seals_open_cracks_in_vermilion_test() -> void:
	var effect := Kintsugi.new()
	effect.on_tool_execution_end(1, "t1", "read_file", AgentToolResult.error("boom"))
	await effect.on_agent_end(1, "Stop.")
	assert(effect.cracks[0].open_target == 0.0)
	assert(effect.cracks[0].vermilion == Kintsugi.VERMILION)
	effect.free()
	pass


func error_run_without_open_crack_adds_vermilion_repair_test() -> void:
	var effect := Kintsugi.new()
	await effect.on_agent_end(1, "network error")
	assert(effect.cracks.size() == 1)
	assert(effect.cracks[0].vermilion == Kintsugi.VERMILION)
	assert(effect.cracks[0].flowing)
	effect.free()
	pass


func agent_start_clears_cracks_test() -> void:
	var effect := Kintsugi.new()
	effect.on_tool_execution_end(1, "t1", "read_file", AgentToolResult.error("boom"))
	effect.on_agent_start(2)
	assert(effect.cracks.is_empty())
	assert(effect.cracks_are_idle())
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect := Kintsugi.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.kintsugi_material != null)
	assert(effect.kintsugi_material.shader != null)
	effect.on_tool_execution_end(1, "t1", "read_file", AgentToolResult.error("boom"))
	effect.apply_shader_state()
	assert(effect.kintsugi_material.get_shader_parameter("crack_count") == 1)
	effect.queue_free()
	await scene_tree.process_frame
	pass
