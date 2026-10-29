func start_sweeps_and_raises_sheen_test() -> void:
	var effect := HoloFoil.new()
	effect.on_agent_start(1)
	assert(effect.sweep == 0.0)
	assert(effect.presence_target == 1.0)
	for _index in range(120):
		effect.step_foil(1.0 / 60.0)
	assert(effect.sweep == -1.0)
	assert(effect.presence == 1.0)
	assert(effect.sheen >= HoloFoil.RUN_SHEEN)
	effect.free()
	pass


func stream_brightens_sheen_test() -> void:
	var effect := HoloFoil.new()
	effect.on_agent_start(1)
	for _index in range(10):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.sheen > HoloFoil.RUN_SHEEN)
	assert(effect.sheen <= HoloFoil.MAX_SHEEN)
	effect.free()
	pass


func tool_stamps_seal_and_error_cracks_it_test() -> void:
	var effect := HoloFoil.new()
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t2", "grep", {} as Dictionary[String, Variant])
	assert(effect.seals.size() == 1)
	assert(effect.seals[0].center.is_equal_approx(SimulationEffect.tool_anchor("grep")))
	effect.on_tool_execution_end(1, "t2", "grep", AgentToolResult.error("boom"))
	assert(effect.seals[0].error == 1.0)
	assert(effect.failure_tint == 1.0)
	effect.free()
	pass


func seals_cap_at_max_test() -> void:
	var effect := HoloFoil.new()
	for index in range(HoloFoil.MAX_SEALS + 3):
		effect.stamp_seal("t%d" % index, Vector2(0.1 + index * 0.05, 0.5))
	assert(effect.seals.size() == HoloFoil.MAX_SEALS)
	assert(effect.find_seal("t0") == null)
	effect.free()
	pass


func end_fades_presence_out_test() -> void:
	var effect := HoloFoil.new()
	effect.on_agent_start(1)
	await effect.on_agent_end(1, "")
	assert(effect.presence_target == 0.0)
	assert(effect.sheen_floor == 0.0)
	effect.free()
	pass
