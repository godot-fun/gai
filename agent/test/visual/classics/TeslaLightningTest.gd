extends RefCounted


func lightning_fork_path_keeps_endpoints_test() -> void:
	var effect := TeslaLightning.new()
	var path := effect.fork_path(Vector2(10.0, 20.0), Vector2(400.0, 300.0), 5)
	assert(path.size() == (1 << 5) + 1)
	assert(path[0] == Vector2(10.0, 20.0))
	assert(path[path.size() - 1] == Vector2(400.0, 300.0))
	effect.free()
	pass


func lightning_tool_arc_crackles_until_strike_test() -> void:
	var effect := TeslaLightning.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.arcs.has("t1"))
	var arc: Vector4 = effect.arcs["t1"]
	assert(Vector2(arc.z, arc.w).is_equal_approx(SimulationEffect.tool_anchor("grep") * effect.size))
	effect.step_lightning(TeslaLightning.ARC_REFORK_SECONDS * 1.01)
	assert(effect.bolts.size() == 1)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(not effect.arcs.has("t1"))
	var strike := effect.bolts[effect.bolts.size() - 1]
	assert(strike.impact_radius > 0.0)
	assert(effect.sparks.size() > 0)
	effect.free()
	pass


func lightning_failed_tool_explodes_red_test() -> void:
	var effect := TeslaLightning.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.bolts.size() == 6)
	for bolt: TeslaLightning.Bolt in effect.bolts:
		assert(bolt.color == Colors.error)
	effect.free()
	pass


func lightning_answers_crawl_as_static_test() -> void:
	var effect := TeslaLightning.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	var start_caret := effect.caret
	for _index in range(10):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	effect.step_lightning(1.0 / 60.0)
	assert(effect.bolts.size() > 0)
	assert(effect.caret != start_caret)
	effect.free()
	pass


func lightning_bolts_and_sparks_are_capped_and_expire_test() -> void:
	var effect := TeslaLightning.new()
	effect.size = Vector2(1280.0, 720.0)
	for _index in range(TeslaLightning.MAX_BOLTS + 10):
		effect.add_bolt(Vector2.ZERO, Vector2(100.0, 100.0), 0.1, 1.0, Color.WHITE)
	effect.burst_sparks(Vector2.ZERO, TeslaLightning.MAX_SPARKS + 30, Color.WHITE)
	assert(effect.bolts.size() == TeslaLightning.MAX_BOLTS)
	assert(effect.sparks.size() == TeslaLightning.MAX_SPARKS)
	for _index in range(60):
		effect.step_lightning(1.0 / 60.0)
	assert(effect.bolts.is_empty())
	assert(effect.sparks.is_empty())
	effect.free()
	pass


func lightning_edge_point_is_on_nearest_edge_test() -> void:
	var effect := TeslaLightning.new()
	effect.size = Vector2(1280.0, 720.0)
	assert(effect.edge_point_toward(Vector2(30.0, 400.0)).x == 0.0)
	assert(effect.edge_point_toward(Vector2(1250.0, 400.0)).x == 1280.0)
	assert(effect.edge_point_toward(Vector2(640.0, 700.0)).y == 720.0)
	assert(effect.edge_point_toward(Vector2(640.0, 10.0)).y == 0.0)
	effect.free()
	pass
