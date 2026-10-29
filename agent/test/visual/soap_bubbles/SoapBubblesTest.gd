func start_blows_rising_bubbles_test() -> void:
	var effect := SoapBubbles.new()
	effect.on_agent_start(1)
	assert(effect.bubbles.size() == 3)
	for bubble: SoapBubbles.Bubble in effect.bubbles:
		assert(bubble.velocity.y < 0.0)
	effect.free()
	pass


func stream_spawns_within_cap_test() -> void:
	var effect := SoapBubbles.new()
	effect.on_agent_start(1)
	for _index in range(200):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
		effect.step_bubbles(1.0 / 60.0)
	assert(effect.bubbles.size() > 3)
	assert(effect.bubbles.size() <= SoapBubbles.MAX_BUBBLES)
	effect.free()
	pass


func tool_bubble_inflates_and_pops_on_success_test() -> void:
	var effect := SoapBubbles.new()
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	var bubble := effect.find_bubble("t1")
	assert(bubble != null)
	assert(bubble.target_radius == SoapBubbles.TOOL_RADIUS)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("fine"))
	assert(bubble.pop >= 0.0)
	assert(effect.find_bubble("t1") == null)
	for _index in range(30):
		effect.step_bubbles(1.0 / 60.0)
	assert(not effect.bubbles.has(bubble))
	effect.free()
	pass


func tool_error_pops_every_bubble_red_test() -> void:
	var effect := SoapBubbles.new()
	effect.on_agent_start(1)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	for bubble: SoapBubbles.Bubble in effect.bubbles:
		assert(bubble.pop >= 0.0)
		assert(bubble.error == 1.0)
	effect.free()
	pass


func end_stops_spawning_and_staggers_pops_test() -> void:
	var effect := SoapBubbles.new()
	effect.on_agent_start(1)
	await effect.on_agent_end(1, "")
	assert(not effect.spawning)
	for _index in range(120):
		effect.step_bubbles(1.0 / 60.0)
	assert(effect.bubbles.is_empty())
	effect.free()
	pass
