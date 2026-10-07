extends RefCounted


static func visual_type_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.TOOL_CONSTELLATION))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.TOOL_CONSTELLATION)
	assert(effect != null)
	assert(effect.get_visual_type() == VisualType.Type.TOOL_CONSTELLATION)
	effect.free()
	control.free()
	pass


static func node_and_labels_test() -> void:
	var node := ToolConstellation.make_node("call-1", "web_search", {"query": "Godot"}, 0, 2)
	assert(node["id"] == "call-1")
	assert(node["arg_count"] == 1)
	assert(node["turn"] == 2)
	assert(node["orbit"] == 0.0)
	assert(int(node["family"]) == ToolConstellation.ToolFamily.WEB)
	assert(ToolConstellation.tool_family("audio_to_text") == ToolConstellation.ToolFamily.AUDIO)
	assert(VisualToolFormatter.title_name("web_search") == "Web Search")
	assert(VisualToolFormatter.glyph("shell") == ">_")
	assert(ToolConstellation.short_argument("a very long argument value") == "a very long argume...")
	assert(ToolConstellation.terminal_text("abc") == "abc")
	var terminal_lines := ToolConstellation.terminal_display_lines("first line\nsecond line", 12, 2)
	assert(terminal_lines.size() == 2)
	assert(terminal_lines[0] == "first line s")
	assert(terminal_lines[1] == "econd line")
	pass


func retro_terminal_stream_and_command_test() -> void:
	var effect := ToolConstellation.new()
	effect.on_message_update("streamed terminal content", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.stream_buffer == "streamed terminal content")
	assert(effect.stream_kind == OpenAiClient.STREAM_KIND_REASONING)
	effect.on_tool_execution_start("shell-1", "exec_command", {"cmd": "godot --headless"})
	assert(effect.current_command_line().begins_with("exec_command --cmd="))
	assert(effect.current_tool_name() == "EXEC_COMMAND")
	assert(effect.current_tool_status() == "RUN")
	assert(effect.current_command_arguments().begins_with("cmd: godot --headless"))
	effect.on_tool_execution_end("shell-1", "exec_command", AgentToolResult.error("failed"))
	effect.advance_tool_queue(ToolConstellation.MIN_TOOL_PLAY_SECONDS)
	assert(effect.crt_glitch > 0.0)
	assert(effect.current_tool_status() == "ERR")
	effect.free()
	pass


func lifecycle_test() -> void:
	var effect := ToolConstellation.new()
	effect.on_turn_start()
	effect.on_tool_execution_start("read-1", "read", {"path": "res://file.gd"})
	assert(effect.nodes.size() == 1)
	assert(effect.active_calls.has("read-1"))
	effect.on_tool_execution_end("read-1", "read", AgentToolResult.ok("done"))
	effect.advance_tool_queue(ToolConstellation.MIN_TOOL_PLAY_SECONDS)
	assert(effect.nodes[0]["state"] == ToolConstellation.ExecutionState.SUCCESS)
	assert(not effect.active_calls.has("read-1"))
	effect.free()
	pass


func fast_tools_play_in_order_test() -> void:
	var effect := ToolConstellation.new()
	effect.on_tool_execution_start("first", "read", {})
	effect.on_tool_execution_start("second", "write", {})
	effect.on_tool_execution_end("first", "read", AgentToolResult.ok("done"))
	effect.on_tool_execution_end("second", "write", AgentToolResult.ok("done"))
	assert(effect.nodes.size() == 1)
	assert(effect.pending_calls.size() == 1)
	effect.advance_tool_queue(ToolConstellation.MIN_TOOL_PLAY_SECONDS)
	assert(effect.nodes[0]["state"] == ToolConstellation.ExecutionState.SUCCESS)
	assert(effect.nodes.size() == 1)
	effect.advance_tool_queue(ToolConstellation.RESULT_HOLD_SECONDS)
	assert(effect.nodes.size() == 2)
	assert(effect.nodes[1]["state"] == ToolConstellation.ExecutionState.RUNNING)
	effect.advance_tool_queue(ToolConstellation.MIN_TOOL_PLAY_SECONDS)
	assert(effect.nodes[1]["state"] == ToolConstellation.ExecutionState.SUCCESS)
	effect.free()
	pass


func field_spread_expands_then_collapses_test() -> void:
	var effect := ToolConstellation.new()
	effect.visible = true
	effect.on_agent_start(1)
	assert(is_equal_approx(effect.field_spread, 0.0))
	effect._process(ToolConstellation.RING_EXPAND_SECONDS * 0.5)
	assert(effect.field_spread > 0.4 and effect.field_spread < 0.7)
	effect._process(ToolConstellation.RING_EXPAND_SECONDS)
	assert(is_equal_approx(effect.field_spread, 1.0))
	effect.completing = true
	effect.completion = 0.0
	effect._process(ToolConstellation.COMPLETE_SECONDS * 0.5)
	assert(effect.field_spread > 0.4 and effect.field_spread < 0.7)
	effect._process(ToolConstellation.COMPLETE_SECONDS)
	assert(is_equal_approx(effect.field_spread, 0.0))
	effect.free()
	pass


func rings_expand_one_layer_at_a_time_test() -> void:
	var effect := ToolConstellation.new()
	# Mid expand: an inner ring should already be open while an outer ring is still closed.
	effect.field_spread = 0.28
	effect.completing = false
	assert(effect.layer_spread(1, ToolConstellation.RING_LAYER_COUNT) > 0.85)
	assert(effect.layer_spread(ToolConstellation.RING_LAYER_COUNT, ToolConstellation.RING_LAYER_COUNT) < 0.05)
	# Mid collapse: the outer ring retracts before the inner ring.
	effect.completing = true
	effect.field_spread = 0.72
	assert(effect.layer_spread(ToolConstellation.RING_LAYER_COUNT, ToolConstellation.RING_LAYER_COUNT) < 0.2)
	assert(effect.layer_spread(1, ToolConstellation.RING_LAYER_COUNT) > 0.85)
	effect.free()
	pass


func full_constellation_replaces_oldest_slot_test() -> void:
	var effect := ToolConstellation.new()
	for index in range(ToolConstellation.MAX_NODES):
		var call_id := "call-%d" % index
		effect.on_tool_execution_start(call_id, "read", {})
		effect.on_tool_execution_end(call_id, "read", AgentToolResult.ok("done"))
		effect.advance_tool_queue(ToolConstellation.MIN_TOOL_PLAY_SECONDS)
		effect.advance_tool_queue(ToolConstellation.RESULT_HOLD_SECONDS)
	assert(effect.nodes.size() == ToolConstellation.MAX_NODES)
	var preserved_id := String(effect.nodes[1]["id"])
	effect.on_tool_execution_start("call-new", "write", {})
	assert(effect.nodes.size() == ToolConstellation.MAX_NODES)
	assert(String(effect.nodes[0]["id"]) == "call-new")
	assert(int(effect.nodes[0]["state"]) == ToolConstellation.ExecutionState.RUNNING)
	assert(String(effect.nodes[1]["id"]) == preserved_id)
	assert(effect.active_calls["call-new"] == 0)
	effect.free()
	pass
