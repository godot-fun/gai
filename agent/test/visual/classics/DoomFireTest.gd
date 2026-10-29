extends RefCounted


static func doom_fire_keeps_the_interface_readable_test() -> void:
	assert(is_equal_approx(DoomFire.FIRE_OPACITY, 0.38))
	pass


func fire_stream_stokes_taller_flames_test() -> void:
	var effect := DoomFire.new()
	effect.on_agent_start(1)
	assert(effect.fuel == 1.0)
	var idle_target := effect.current_height_target()
	for _index in range(10):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.current_height_target() > idle_target)
	var start_decay := effect.current_decay()
	for _index in range(60):
		effect.step_field(1.0 / 60.0)
	assert(effect.current_decay() < start_decay)
	assert(effect.current_decay() >= DoomFire.HIGH_DECAY)
	effect.free()
	pass


func fire_tools_burn_flares_and_throw_fireballs_test() -> void:
	var effect := DoomFire.new()
	effect.on_agent_start(1)
	effect.impulse_shapes.clear()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.flares.has("t1"))
	assert(is_equal_approx(effect.flares["t1"].x, SimulationEffect.tool_anchor("grep").x))
	for _index in range(30):
		effect.step_field(1.0 / 60.0)
	assert(effect.flares["t1"].y == 1.0)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(not effect.flares.has("t1"))
	assert(effect.impulse_shapes.size() == 1)
	assert(is_equal_approx(effect.impulse_shapes[0].z, DoomFire.FIREBALL_RADIUS))
	effect.on_tool_execution_end(1, "t2", "shell", AgentToolResult.error("boom"))
	assert(effect.failure_tint == 1.0)
	assert(effect.height_boost == DoomFire.MAX_HEIGHT_BOOST)
	effect.free()
	pass


func fire_flare_cap_drops_oldest_test() -> void:
	var effect := DoomFire.new()
	for index in range(DoomFire.MAX_FLARES + 2):
		effect.on_tool_execution_start(1, "t%d" % index, "grep", {} as Dictionary[String, Variant])
	assert(effect.flares.size() == DoomFire.MAX_FLARES)
	assert(not effect.flares.has("t0"))
	effect.free()
	pass


func fire_end_cuts_the_fuel_test() -> void:
	var effect := DoomFire.new()
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	await effect.on_agent_end(1, "")
	assert(effect.fuel == 0.0)
	assert(effect.flares.is_empty())
	effect.free()
	pass


func fire_chain_runs_in_tree_test() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	for effect: SimulationEffect in [DoomFire.new(), GameOfLife.new()]:
		scene_tree.root.add_child.call_deferred(effect)
		await scene_tree.process_frame
		assert(effect.chain.pass_count() == effect.pass_kinds().size())
		assert(not effect.chain.running)
		effect.on_agent_start(1)
		effect.set_visual_visible(true, false)
		await scene_tree.process_frame
		await scene_tree.process_frame
		assert(effect.chain.running)
		effect.queue_free()
	await scene_tree.process_frame
	pass
