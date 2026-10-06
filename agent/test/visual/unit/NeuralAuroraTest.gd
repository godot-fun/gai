extends RefCounted


static func neural_aurora_factory_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.NEURAL_AURORA))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.NEURAL_AURORA)
	assert(effect is NeuralAurora)
	assert(effect.get_visual_type() == VisualType.Type.NEURAL_AURORA)
	effect.free()
	control.free()
	pass


static func neural_aurora_tool_label_test() -> void:
	assert(NeuralAurora.public_tool_name("web_search") == "WEB SEARCH")
	assert(NeuralAurora.public_tool_name("") == "TOOL")
	pass


static func fast_tool_waits_for_full_arc_test() -> void:
	var effect := NeuralAurora.new()
	effect.tool_label = Label.new()
	effect.on_tool_execution_start("fast", "read", {})
	effect.on_tool_execution_end("fast", "read", AgentToolResult.ok("ok"))
	effect.advance_tool_timeline(0.1)
	assert(effect.success_pulse == 0.0)
	assert(not effect.playing_tool.is_empty())
	effect.advance_tool_timeline(NeuralAurora.MIN_TOOL_PLAY_SECONDS)
	assert(effect.success_pulse == 1.0)
	assert(effect.tool_result_hold_seconds == NeuralAurora.TOOL_RESULT_HOLD_SECONDS)
	effect.tool_label.free()
	effect.free()
	pass


static func fast_tools_play_in_order_test() -> void:
	var effect := NeuralAurora.new()
	effect.tool_label = Label.new()
	effect.on_tool_execution_start("first", "read", {})
	effect.on_tool_execution_end("first", "read", AgentToolResult.ok("ok"))
	effect.on_tool_execution_start("second", "web_search", {})
	effect.on_tool_execution_end("second", "web_search", AgentToolResult.error("failed"))
	assert(String(effect.playing_tool["id"]) == "first")
	assert(effect.pending_tool_calls.size() == 1)
	effect.advance_tool_timeline(NeuralAurora.MIN_TOOL_PLAY_SECONDS)
	effect.advance_tool_timeline(NeuralAurora.TOOL_RESULT_HOLD_SECONDS)
	assert(String(effect.playing_tool["id"]) == "second")
	effect.tool_label.free()
	effect.free()
	pass


static func failure_cracks_reveal_over_time_test() -> void:
	var effect := NeuralAurora.new()
	effect.tool_label = Label.new()
	effect.on_tool_execution_start("failed", "grep", {})
	effect.on_tool_execution_end("failed", "grep", AgentToolResult.error("failed"))
	effect.advance_tool_timeline(NeuralAurora.MIN_TOOL_PLAY_SECONDS)
	assert(effect.failure_pulse == 1.0)
	assert(effect.failure_progress == 0.0)
	effect.advance_failure(NeuralAurora.FAILURE_REVEAL_SECONDS * 0.5)
	assert(effect.failure_progress > 0.0 and effect.failure_progress < 1.0)
	effect.advance_failure(NeuralAurora.FAILURE_REVEAL_SECONDS)
	assert(effect.failure_progress == 1.0)
	effect.tool_label.free()
	effect.free()
	pass
