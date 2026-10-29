func content_stream_lights_more_panes_up_to_cap_test() -> void:
	var effect := StainedGlass.new()
	effect.on_agent_start(1)
	assert(effect.fill_target == StainedGlass.START_FILL)
	for _index in range(400):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.fill_target == StainedGlass.RUN_FILL_CAP)
	effect.on_message_update(1, "thinking", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.cloud > 0.0)
	effect.free()
	pass


func tool_pane_glows_then_cracks_on_error_test() -> void:
	var effect := StainedGlass.new()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t2", "grep", {} as Dictionary[String, Variant])
	assert(effect.panes.size() == 1)
	var pane := effect.panes[0]
	assert(pane.center.is_equal_approx(SimulationEffect.tool_anchor("grep")))
	assert(pane.holding)
	effect.on_tool_execution_end(1, "t2", "grep", AgentToolResult.error("boom"))
	assert(not pane.holding)
	assert(pane.error == 1.0)
	assert(effect.failure_tint == 1.0)
	for _index in range(240):
		effect.step_glass(1.0 / 60.0)
	assert(pane.glow == StainedGlass.REST_GLOW)
	effect.free()
	pass


func panes_cap_at_max_test() -> void:
	var effect := StainedGlass.new()
	for index in range(StainedGlass.MAX_PANES + 3):
		effect.light_pane("t%d" % index, Vector2(0.1 + index * 0.05, 0.5))
	assert(effect.panes.size() == StainedGlass.MAX_PANES)
	assert(effect.find_pane("t0") == null)
	effect.free()
	pass


func end_lights_every_pane_and_fades_test() -> void:
	var effect := StainedGlass.new()
	effect.on_agent_start(1)
	await effect.on_agent_end(1, "")
	assert(effect.fill_target == 1.0)
	assert(effect.flare == 1.0)
	assert(effect.presence_target == 0.0)
	effect.free()
	pass
