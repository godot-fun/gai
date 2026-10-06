extends RefCounted


static func semantic_black_hole_factory_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.SEMANTIC_BLACK_HOLE))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.SEMANTIC_BLACK_HOLE)
	assert(effect is SemanticBlackHole)
	assert(effect.get_visual_type() == VisualType.Type.SEMANTIC_BLACK_HOLE)
	effect.free()
	control.free()
	pass


static func semantic_black_hole_tool_mapping_test() -> void:
	assert(SemanticBlackHole.public_tool_name("web_search") == "WEB SEARCH")
	assert(SemanticBlackHole.public_tool_name("") == "TOOL")
	assert(SemanticBlackHole.angle_for_tool("read") == SemanticBlackHole.angle_for_tool("read"))
	pass


static func semantic_black_hole_follower_test() -> void:
	var first := SemanticBlackHole.follow(0.0, 1.0, 0.1, 3.0)
	var second := SemanticBlackHole.follow(first, 1.0, 0.1, 3.0)
	assert(first > 0.0 and first < 1.0)
	assert(second > first and second < 1.0)
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
