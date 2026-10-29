extends RefCounted


func lava_start_fills_the_lamp_test() -> void:
	var effect := LavaLamp.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	assert(effect.blobs.size() == LavaLamp.START_BLOBS)
	assert(effect.heater_power() == LavaLamp.RUN_HEAT)
	effect.free()
	pass


func lava_hot_wax_rises_and_cold_wax_sinks_test() -> void:
	var effect := LavaLamp.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.running = true
	var hot := effect.add_blob("", Vector2(300.0, 400.0), LavaLamp.BASE_RADIUS, 0.5)
	hot.temperature = 1.0
	var cold := effect.add_blob("", Vector2(900.0, 300.0), LavaLamp.BASE_RADIUS, 0.5)
	cold.temperature = 0.0
	for _index in range(30):
		effect.step_lamp(1.0 / 60.0)
	assert(hot.position.y < 400.0)
	assert(cold.position.y > 300.0)
	effect.free()
	pass


func lava_stream_turns_up_the_heater_test() -> void:
	var effect := LavaLamp.new()
	effect.on_agent_start(1)
	effect.on_message_update(1, "thinking", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.heater_power() == LavaLamp.REASONING_HEAT)
	for _index in range(10):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.heater_power() > LavaLamp.RUN_HEAT)
	effect.free()
	pass


func lava_tool_blob_shoots_up_or_bursts_test() -> void:
	var effect := LavaLamp.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	var blob := effect.find_blob("t1")
	assert(blob != null)
	assert(blob.position.is_equal_approx(SimulationEffect.tool_anchor("grep") * effect.size))
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(blob.temperature == 1.0 and blob.glow == 1.0)
	assert(effect.find_blob("t1") == null)
	effect.on_tool_execution_start(1, "t2", "shell", {} as Dictionary[String, Variant])
	var count := effect.blobs.size()
	effect.on_tool_execution_end(1, "t2", "shell", AgentToolResult.error("boom"))
	assert(effect.blobs.size() == count + 2)
	assert(effect.blobs[effect.blobs.size() - 1].error == 1.0)
	effect.free()
	pass


func lava_blob_cap_keeps_running_tool_blobs_test() -> void:
	var effect := LavaLamp.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	for index in range(LavaLamp.MAX_BLOBS + 3):
		effect.on_tool_execution_start(1, "t%d" % index, "grep", {} as Dictionary[String, Variant])
	assert(effect.blobs.size() <= LavaLamp.MAX_BLOBS)
	assert(effect.find_blob("t%d" % (LavaLamp.MAX_BLOBS + 2)) != null)
	effect.free()
	pass


func lava_end_cools_and_drains_the_lamp_test() -> void:
	var effect := LavaLamp.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	await effect.on_agent_end(1, "")
	assert(effect.heater_power() == 0.0)
	for _index in range(150):
		effect.step_lamp(1.0 / 60.0)
	assert(effect.blobs.is_empty())
	effect.free()
	pass
