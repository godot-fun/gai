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
	assert(ToolConstellation.public_tool_name("web_search") == "Web Search")
	assert(ToolConstellation.tool_glyph("shell") == ">_")
	pass


func lifecycle_test() -> void:
	var effect := ToolConstellation.new()
	effect.on_turn_start()
	effect.on_tool_execution_start("read-1", "read", {"path": "res://file.gd"})
	assert(effect.nodes.size() == 1)
	assert(effect.active_calls.has("read-1"))
	effect.on_tool_execution_end("read-1", "read", AgentToolResult.ok("done"))
	assert(effect.nodes[0]["state"] == ToolConstellation.ExecutionState.SUCCESS)
	assert(not effect.active_calls.has("read-1"))
	effect.free()
	pass
