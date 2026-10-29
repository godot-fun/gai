extends RefCounted


func snap_tool_bites_then_reforms_test() -> void:
	var effect := SnapDissolve.new()
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.zones.size() == 1)
	var zone := effect.zones[0]
	assert(zone.center.distance_to(SimulationEffect.tool_anchor("grep")) <= SnapDissolve.ZONE_JITTER * 1.5)
	for _index in range(30):
		effect.step_snap(1.0 / 60.0)
	assert(zone.progress > 0.4)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(zone.target == 0.0)
	assert(zone.red == 0.0)
	for _index in range(120):
		effect.step_snap(1.0 / 60.0)
	assert(effect.zones.is_empty())
	assert(not effect.has_work())
	effect.free()
	pass


func snap_failed_tool_leaves_red_embers_test() -> void:
	var effect := SnapDissolve.new()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.zones[0].red == 1.0)
	effect.free()
	pass


func snap_zone_cap_evicts_a_healing_bite_test() -> void:
	var effect := SnapDissolve.new()
	for index in range(SnapDissolve.MAX_ZONES):
		effect.on_tool_execution_start(1, "t%d" % index, "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_end(1, "t3", "grep", AgentToolResult.ok("done"))
	effect.on_tool_execution_start(1, "extra", "grep", {} as Dictionary[String, Variant])
	assert(effect.zones.size() == SnapDissolve.MAX_ZONES)
	assert(effect.find_zone("t3") == null)
	assert(effect.find_zone("extra") != null)
	effect.free()
	pass


func snap_answers_peel_flakes_but_reasoning_does_not_test() -> void:
	var effect := SnapDissolve.new()
	effect.on_message_update(1, "thinking about it", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.flake_rate == 0.0)
	effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.flake_rate > 0.0)
	effect.free()
	pass


func snap_end_sweeps_the_window_and_heals_bites_test() -> void:
	var effect := SnapDissolve.new()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	await effect.on_agent_end(1, "Stop.")
	assert(effect.end_target == SnapDissolve.END_PROGRESS_MAX)
	assert(effect.end_red == 1.0)
	assert(effect.zones[0].target == 0.0)
	for _index in range(int(SnapDissolve.END_SNAP_SECONDS * 60.0) + 10):
		effect.step_snap(1.0 / 60.0)
	assert(is_equal_approx(effect.end_progress, SnapDissolve.END_PROGRESS_MAX))
	effect.free()
	pass
