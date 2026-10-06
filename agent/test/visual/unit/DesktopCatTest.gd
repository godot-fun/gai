extends RefCounted


static func visual_type_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.DESKTOP_CAT))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.DESKTOP_CAT)
	assert(effect != null)
	assert(effect.get_visual_type() == VisualType.Type.DESKTOP_CAT)
	effect.free()
	control.free()
	pass


func lifecycle_state_test() -> void:
	var cat := DesktopCat.new()
	cat.on_agent_start(7)
	assert(cat.state == DesktopCat.CatState.THINKING)
	cat.on_turn_end()
	assert(cat.state == DesktopCat.CatState.IDLE)
	assert(is_equal_approx(cat.on_agent_end(""), DesktopCat.END_HOLD_SECONDS))
	assert(cat.state == DesktopCat.CatState.SUCCESS)
	cat.reset_visual()
	assert(cat.state == DesktopCat.CatState.IDLE)
	cat.free()
	pass


func tool_state_test() -> void:
	var cat := DesktopCat.new()
	cat.on_tool_execution_start("read-1", "read_file", {})
	assert(cat.state == DesktopCat.CatState.TOOL_START)
	assert(cat.active_tools.has("read-1"))
	cat.active_tools["read-1"]["seconds"] = DesktopCat.TOOL_WAIT_SECONDS
	cat._process(0.01)
	assert(cat.state == DesktopCat.CatState.TOOL_WAITING)
	cat.on_tool_execution_end("read-1", "read_file", AgentToolResult.ok("done"))
	assert(cat.state == DesktopCat.CatState.TOOL_SUCCESS)
	assert(cat.active_tools.is_empty())
	cat.free()
	pass


func failure_and_cancel_state_test() -> void:
	var cat := DesktopCat.new()
	cat.on_tool_execution_start("bad", "write_file", {})
	cat.on_tool_execution_end("bad", "write_file", AgentToolResult.error("denied"))
	assert(cat.state == DesktopCat.CatState.TOOL_FAILED)
	cat.on_agent_end("network failed")
	assert(cat.state == DesktopCat.CatState.FAILED)
	cat.on_agent_end("Stop.")
	assert(cat.state == DesktopCat.CatState.CANCELLED)
	cat.free()
	pass
