func running_tool_scorches_and_success_mends_test() -> void:
	var effect := Disintegrate.new()
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.burns.size() == 1)
	assert(effect.burns[0].radius == Disintegrate.SCORCH_RADIUS)
	for _index in range(60):
		effect.step_burns(1.0 / 60.0)
	assert(effect.burns[0].progress == Disintegrate.SCORCH_PROGRESS)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("fine"))
	for _index in range(60):
		effect.step_burns(1.0 / 60.0)
	assert(effect.burns.is_empty())
	effect.free()
	pass


func failed_tool_burns_a_hole_that_keeps_its_scorch_test() -> void:
	var effect := Disintegrate.new()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	for _index in range(60):
		effect.step_burns(1.0 / 60.0)
	var scorched_extent: float = effect.burns[0].progress * effect.burns[0].radius
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	var burn: Variant = effect.burns[0]
	assert(burn.radius == Disintegrate.BURN_RADIUS)
	assert(is_equal_approx(burn.progress * burn.radius, scorched_extent))
	assert(burn.target == Disintegrate.FULL_PROGRESS)
	for _index in range(120):
		effect.step_burns(1.0 / 60.0)
	assert(burn.progress == Disintegrate.FULL_PROGRESS)
	effect.free()
	pass


func turn_end_reassembles_every_burn_test() -> void:
	var effect := Disintegrate.new()
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	effect.on_tool_execution_end(1, "t2", "read_file", AgentToolResult.error("boom"))
	for _index in range(30):
		effect.step_burns(1.0 / 60.0)
	effect.on_turn_end(1)
	for burn: Variant in effect.burns:
		assert(burn.target == 0.0)
	for _index in range(150):
		effect.step_burns(1.0 / 60.0)
	assert(effect.burns.is_empty())
	effect.free()
	pass


func burns_are_capped_test() -> void:
	var effect := Disintegrate.new()
	for index in range(Disintegrate.MAX_BURNS + 2):
		effect.on_tool_execution_start(1, "t%d" % index, "grep", {} as Dictionary[String, Variant])
	assert(effect.burns.size() == Disintegrate.MAX_BURNS)
	assert(effect.burns[0].key == "t2")
	effect.free()
	pass


func stream_lifts_embers_that_settle_test() -> void:
	var effect := Disintegrate.new()
	effect.on_agent_start(1)
	for _index in range(10):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.embers > Disintegrate.RUN_EMBERS)
	for _index in range(300):
		effect.step_burns(1.0 / 60.0)
	assert(effect.embers == Disintegrate.RUN_EMBERS)
	effect.free()
	pass


func error_end_mends_without_tree_test() -> void:
	var effect := Disintegrate.new()
	await effect.on_agent_end(1, "network error")
	assert(effect.burns.size() == 1)
	assert(effect.burns[0].target == 0.0)
	assert(effect.ember_floor == 0.0)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect := Disintegrate.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.burn_material != null)
	assert(effect.burn_material.shader != null)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	effect.apply_shader_state()
	assert(effect.burn_material.get_shader_parameter("burn_count") == 1)
	effect.queue_free()
	await scene_tree.process_frame
	pass
