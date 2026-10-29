func pool_fills_on_start_and_drains_at_end_test() -> void:
	var effect := Ferrofluid.new()
	effect.on_agent_start(1)
	for _index in range(60):
		effect.step_fluid(1.0 / 60.0)
	assert(effect.pool == 1.0)
	assert(effect.spike >= Ferrofluid.RUN_SPIKE)
	await effect.on_agent_end(1, "")
	for _index in range(120):
		effect.step_fluid(1.0 / 60.0)
	assert(effect.fluid_is_drained())
	effect.free()
	pass


func stream_raises_spikes_and_moves_magnet_test() -> void:
	var effect := Ferrofluid.new()
	effect.on_agent_start(1)
	var start_caret := effect.caret_x
	for _index in range(10):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.spike > Ferrofluid.RUN_SPIKE)
	assert(effect.caret_x != start_caret)
	effect.free()
	pass


func tool_tendril_reaches_and_success_splashes_test() -> void:
	var effect := Ferrofluid.new()
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	for _index in range(90):
		effect.step_fluid(1.0 / 60.0)
	assert(effect.tendril > 0.9)
	assert(absf(effect.magnet_x - SimulationEffect.tool_anchor("grep").x) < 0.05)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("fine"))
	assert(effect.tendril_goal == 0.0)
	assert(effect.droplets.size() == Ferrofluid.SPLASH_DROPLETS)
	effect.free()
	pass


func tool_error_snaps_tendril_and_flings_droplets_test() -> void:
	var effect := Ferrofluid.new()
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	for _index in range(60):
		effect.step_fluid(1.0 / 60.0)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.chaos == 1.0)
	assert(effect.tendril == 0.0)
	assert(effect.droplets.size() == Ferrofluid.FLING_DROPLETS)
	for _index in range(240):
		effect.step_fluid(1.0 / 60.0)
	assert(effect.droplets.is_empty())
	effect.free()
	pass


func droplets_are_capped_test() -> void:
	var effect := Ferrofluid.new()
	for _index in range(3):
		effect.fling(Vector2(0.5, 0.5))
	assert(effect.droplets.size() == Ferrofluid.MAX_DROPLETS)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect := Ferrofluid.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.fluid_material != null)
	assert(effect.fluid_material.shader != null)
	effect.on_agent_start(1)
	effect.step_fluid(1.0 / 60.0)
	effect.apply_shader_state()
	assert(effect.fluid_material.get_shader_parameter("pool_px") > 0.0)
	effect.queue_free()
	await scene_tree.process_frame
	pass
