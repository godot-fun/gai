extends RefCounted


static func firefly_has_translations_test() -> void:
	for locale_path: String in ["res://agent/config/locale/en.json", "res://agent/config/locale/zh.json"]:
		assert(FileAccess.get_file_as_string(locale_path).contains("\"visual_firefly_sync\""))
	pass


static func flash_peaks_at_zero_phase_test() -> void:
	assert(is_equal_approx(FireflySync.flash_amount(0.0), 1.0))
	assert(is_equal_approx(FireflySync.flash_amount(TAU), 1.0))
	assert(FireflySync.flash_amount(PI) < 0.001)
	assert(FireflySync.flash_amount(0.2) > FireflySync.flash_amount(0.6))
	assert(FireflySync.flash_amount(TAU - 0.5) > 0.0)
	assert(FireflySync.flash_amount(0.5) < 1.0)
	assert(FireflySync.flash_amount(1.5) > FireflySync.flash_amount(TAU - 1.5))
	pass


func start_hatches_scattered_swarm_below_toolbar_test() -> void:
	var effect := FireflySync.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.rng.seed = 7
	effect.on_agent_start(1)
	assert(effect.positions.size() == FireflySync.START_FLIES)
	assert(effect.phases.size() == effect.positions.size() and effect.frequencies.size() == effect.positions.size())
	assert(effect.size_scales.size() == effect.positions.size())
	assert(effect.coupling == FireflySync.START_COUPLING)
	var has_small := false
	var has_large := false
	for size_scale: float in effect.size_scales:
		assert(size_scale >= FireflySync.MIN_SIZE_SCALE and size_scale <= FireflySync.MAX_SIZE_SCALE)
		has_small = has_small or size_scale < 0.85
		has_large = has_large or size_scale > 1.15
	assert(has_small and has_large)
	for position: Vector2 in effect.positions:
		assert(position.y > float(AgentLayout.TOOLBAR_HEIGHT))
	assert(effect.coherence() < 0.5)
	effect.free()
	pass


func strong_coupling_locks_neighbors_in_unison_test() -> void:
	var effect := FireflySync.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.rng.seed = 7
	for index in range(60):
		effect.hatch(Vector2(600.0 + float(index % 8) * 10.0, 400.0 + float(index / 8) * 10.0), effect.rng.randf() * TAU)
	effect.coupling = FireflySync.MAX_COUPLING
	for _index in range(600):
		effect.step_swarm(1.0 / 60.0)
	assert(effect.coherence() > 0.9)
	effect.free()
	pass


func stream_hatches_newcomers_and_answers_raise_coupling_test() -> void:
	var effect := FireflySync.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.coupling == FireflySync.START_COUPLING)
	for _index in range(400):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.coupling > FireflySync.START_COUPLING and effect.coupling <= FireflySync.MAX_COUPLING)
	effect.step_swarm(1.0 / 60.0)
	assert(effect.positions.size() == FireflySync.MAX_FLIES)
	assert(effect.reds.size() == effect.positions.size() and effect.hues.size() == effect.positions.size())
	effect.free()
	pass


func tool_lantern_paces_then_success_strengthens_coupling_test() -> void:
	var effect := FireflySync.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.lanterns.size() == 1)
	var center := SimulationEffect.tool_anchor("grep") * effect.size
	assert(effect.lanterns[0].center.is_equal_approx(center))
	effect.hatch(center + Vector2(200.0, 0.0), 0.0)
	assert(effect.lantern_force(effect.positions.size() - 1).x < 0.0)
	var before := effect.coupling
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(effect.lanterns.is_empty())
	assert(effect.bursts.size() == 1 and effect.bursts[0].w == 0.0)
	assert(is_equal_approx(effect.coupling, before + FireflySync.SUCCESS_COUPLING_STEP))
	effect.free()
	pass


func failed_tool_scatters_nearby_phases_in_red_test() -> void:
	var effect := FireflySync.new()
	effect.size = Vector2(1280.0, 720.0)
	var center := SimulationEffect.tool_anchor("shell") * effect.size
	effect.hatch(center + Vector2(20.0, 0.0), 0.0)
	effect.hatch(center + Vector2(FireflySync.ERROR_RADIUS + 50.0, 0.0), 0.0)
	effect.coupling = 2.0
	effect.on_tool_execution_end(1, "t2", "shell", AgentToolResult.error("boom"))
	assert(effect.reds[0] == 1.0 and effect.reds[1] == 0.0)
	assert(effect.velocities[0].x > 0.0)
	assert(is_equal_approx(effect.coupling, 2.0 * FireflySync.ERROR_COUPLING_SCALE))
	assert(effect.failure_tint == 1.0)
	assert(effect.bursts[0].w == 1.0)
	effect.free()
	pass


func successful_end_flashes_the_whole_swarm_in_unison_test() -> void:
	var effect := FireflySync.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	await effect.on_agent_end(1, "")
	assert(effect.finale and not effect.running and effect.lanterns.is_empty())
	for _index in range(360):
		effect.step_swarm(1.0 / 60.0)
		if effect.finale_flashes > 0:
			break
	assert(effect.finale_flashes > 0)
	assert(effect.coherence() >= FireflySync.FINALE_COHERENCE)
	effect.free()
	pass


func failed_end_scatters_everyone_test() -> void:
	var effect := FireflySync.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	await effect.on_agent_end(1, "Stop.")
	assert(not effect.finale)
	for red: float in effect.reds:
		assert(red == 1.0)
	effect.free()
	pass


func firefly_survives_a_full_event_sequence_in_tree_test() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var effect := FireflySync.new()
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.set_visual_visible(true, false)
	effect.on_turn_start(1)
	effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	for _frame in range(3):
		await scene_tree.process_frame
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	effect.on_message_complete(1, null)
	effect.on_turn_end(1)
	for _frame in range(3):
		await scene_tree.process_frame
	effect.queue_free()
	await scene_tree.process_frame
	pass
