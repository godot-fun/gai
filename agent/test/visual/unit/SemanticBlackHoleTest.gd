extends RefCounted


static func semantic_black_hole_factory_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.SEMANTIC_BLACK_HOLE))
	var effect := VisualControl.create_effect(VisualType.Type.SEMANTIC_BLACK_HOLE)
	assert(effect is SemanticBlackHole)
	effect.free()
	control.free()
	pass


static func semantic_black_hole_tool_mapping_test() -> void:
	assert(ToolVisualDisplay.upper_name(WebSearchTool.NAME) == "WEB SEARCH")
	assert(ToolVisualDisplay.upper_name("") == "TOOL")
	assert(SemanticBlackHole.angle_for_tool("read") == SemanticBlackHole.angle_for_tool("read"))
	pass


static func semantic_black_hole_follower_test() -> void:
	var first := SemanticBlackHole.follow(0.0, 1.0, 0.1, 3.0)
	var second := SemanticBlackHole.follow(first, 1.0, 0.1, 3.0)
	assert(first > 0.0 and first < 1.0)
	assert(second > first and second < 1.0)
	pass


static func turn_start_deepens_whirlpool_without_reversal_test() -> void:
	var effect := SemanticBlackHole.new()
	effect.on_agent_start(1)
	var gravity_before := effect.target_gravity
	var disk_before := effect.target_disk_energy
	effect.on_turn_start(1)
	assert(effect.target_gravity > gravity_before)
	assert(effect.target_disk_energy > disk_before)
	effect.on_turn_start(1)
	assert(effect.target_gravity >= 0.9)
	assert(effect.target_disk_energy >= 0.72)
	effect.free()
	pass


static func success_return_reaches_horizon_before_fading_test() -> void:
	var effect := SemanticBlackHole.new()
	effect.success_return = 1.0
	for step in range(12):
		effect.advance_success_return(0.1)
	assert(effect.success_return_progress == 1.0)
	assert(effect.success_return == 1.0)
	effect.advance_success_return(SemanticBlackHole.SUCCESS_ABSORB_SECONDS)
	effect.advance_success_return(0.2)
	assert(effect.success_return < 1.0)
	effect.free()
	pass


static func tool_badge_follows_visual_lifecycle_test() -> void:
	var effect := SemanticBlackHole.new()
	effect.tool_badge = PanelContainer.new()
	effect.tool_name_label = Label.new()
	effect.tool_status_label = Label.new()
	effect.on_tool_execution_start(1, "call", "web_search", {})
	assert(effect.tool_name_label.text == "WEB SEARCH")
	assert(effect.tool_badge_state == SemanticBlackHole.ToolBadgeState.CONNECTING)
	assert(effect.target_tool_badge_alpha == 1.0)
	effect.on_tool_execution_end(1, "call", "web_search", AgentToolResult.ok("ok"))
	assert(effect.tool_badge_state == SemanticBlackHole.ToolBadgeState.RETURNING)
	effect.success_return_progress = 1.0
	effect.success_absorb_time = SemanticBlackHole.SUCCESS_ABSORB_SECONDS
	effect.advance_success_return(0.2)
	assert(effect.tool_badge_state == SemanticBlackHole.ToolBadgeState.COMPLETE)
	assert(effect.tool_badge_hold_seconds == SemanticBlackHole.COMPLETE_LABEL_SECONDS)
	effect.tool_badge.free()
	effect.tool_name_label.free()
	effect.tool_status_label.free()
	effect.free()
	pass
