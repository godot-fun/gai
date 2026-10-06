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
