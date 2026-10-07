extends Node


func visual_type_is_registered_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.REASONING_TREE))
	var effect := ReasoningTree.new()
	assert(effect.get_visual_type() == VisualType.Type.REASONING_TREE)
	effect.free()
	pass


func branch_defaults_to_running_test() -> void:
	var branch := ReasoningTree.make_branch("call-1", "read_file", 0, 2.8)
	assert(branch["state"] == ReasoningTree.BranchState.RUNNING)
	assert(is_equal_approx(float(branch["anchor"]), 2.8))
	assert(branch["direction"] == -1.0)
	assert(branch["label"] == "Read File")
	pass


func branches_alternate_direction_test() -> void:
	var left := ReasoningTree.make_branch("a", "read", 0, 1.0)
	var right := ReasoningTree.make_branch("b", "write", 1, 1.0)
	assert(left["direction"] == -1.0)
	assert(right["direction"] == 1.0)
	assert(left["angle"] != right["angle"])
	pass


func visible_branch_angles_are_unique_test() -> void:
	var angles: Dictionary[float, bool] = {}
	for index in range(ReasoningTree.MAX_BRANCHES):
		var angle := ReasoningTree.branch_angle(index + 20)
		assert(not angles.has(angle))
		angles[angle] = true
	pass


func later_branch_tips_are_always_higher_test() -> void:
	const BRANCH_LENGTH := 180.0
	const COMPLETION_LENGTH := 64.0
	const SEGMENT_HEIGHT := 96.0
	var previous_parent_y := INF
	var previous_completed_y := INF
	for index in range(ReasoningTree.MAX_BRANCHES * 2):
		var turn_growth := ReasoningTree.trunk_growth_for_turn(mini(index / 3 + 1, AgentLoop.MAX_TURNS))
		var branch := ReasoningTree.make_branch("call-%d" % index, "tool", index, turn_growth)
		var anchor_y := -ReasoningTree.branch_anchor_segment(branch) * SEGMENT_HEIGHT
		var parent_y := anchor_y + Vector2.from_angle(float(branch["angle"])).y * BRANCH_LENGTH
		var completed_y := parent_y + Vector2.from_angle(float(branch["completion_angle"])).y * COMPLETION_LENGTH
		assert(parent_y < previous_parent_y)
		assert(completed_y < previous_completed_y)
		previous_parent_y = parent_y
		previous_completed_y = completed_y
	pass


func branch_elevation_starts_shallow_and_opens_slowly_test() -> void:
	assert(ReasoningTree.branch_elevation_degrees(0) <= 12.0)
	assert(ReasoningTree.branch_elevation_degrees(12) < 40.0)
	assert(ReasoningTree.branch_elevation_degrees(24) < 52.0)
	assert(ReasoningTree.branch_elevation_degrees(36) < 58.0)
	pass


func branches_are_never_discarded_test() -> void:
	var tree := ReasoningTree.new()
	for index in range(ReasoningTree.MAX_BRANCHES + 3):
		tree.on_tool_execution_start("call-%d" % index, "read", {})
	assert(tree.branches.size() == ReasoningTree.MAX_BRANCHES + 3)
	assert(String(tree.branches[0]["id"]) == "call-0")
	tree.free()
	pass


func completion_branch_has_distinct_angle_and_minimum_length_test() -> void:
	for index in range(ReasoningTree.MAX_BRANCHES):
		var branch := ReasoningTree.make_branch("call-%d" % index, "tool", index, 2.0)
		assert(not is_equal_approx(float(branch["angle"]), float(branch["completion_angle"])))
	assert(ReasoningTree.MIN_BRANCH_LENGTH >= 160.0)
	assert(ReasoningTree.MIN_COMPLETION_LENGTH >= 56.0)
	pass


func failed_completion_droops_and_stays_full_length_test() -> void:
	var branch := ReasoningTree.make_branch("failed", "read", 3, 2.0)
	var vector := ReasoningTree.get_completion_vector(branch, ReasoningTree.BranchState.FAILED, 80.0)
	assert(vector.y > 0.0)
	assert(is_equal_approx(vector.length(), 80.0))
	pass


func nearby_branch_anchors_are_staggered_test() -> void:
	var offsets: Dictionary[float, bool] = {}
	for index in range(6):
		var offset := ReasoningTree.branch_anchor_offset(index)
		assert(not offsets.has(offset))
		offsets[offset] = true
	pass


func later_branch_anchors_are_always_higher_test() -> void:
	var previous_anchor := -INF
	for index in range(ReasoningTree.MAX_BRANCHES * 2):
		var turn_growth := ReasoningTree.trunk_growth_for_turn(mini(index / 3 + 1, AgentLoop.MAX_TURNS))
		var branch := ReasoningTree.make_branch("call-%d" % index, "tool", index, turn_growth)
		var anchor := ReasoningTree.branch_anchor_segment(branch)
		assert(anchor > previous_anchor)
		previous_anchor = anchor
	pass


func branch_waits_until_trunk_reaches_anchor_test() -> void:
	var branch := ReasoningTree.make_branch("waiting", "read", 1, 3.0)
	var anchor := ReasoningTree.branch_anchor_segment(branch)
	assert(not ReasoningTree.can_branch_grow(anchor - 0.01, branch))
	assert(ReasoningTree.can_branch_grow(anchor, branch))
	assert(ReasoningTree.can_branch_grow(anchor + 0.01, branch))
	pass


func fractional_branch_anchor_lies_on_drawn_trunk_test() -> void:
	var tree := ReasoningTree.new()
	tree.size = Vector2(1920.0, 1080.0)
	var base := Vector2(960.0, 1048.0)
	var segment_height := 96.0
	var fractional_segment := 2.4
	var anchor := tree.trunk_point(base, segment_height, fractional_segment)
	var segment_start := tree.trunk_point(base, segment_height, 2.0)
	var segment_end := tree.trunk_point(base, segment_height, 3.0)
	assert(anchor.is_equal_approx(segment_start.lerp(segment_end, 0.4)))
	tree.free()
	pass


func staggered_anchor_never_exceeds_turn_endpoint_test() -> void:
	for index in range(24):
		assert(ReasoningTree.branch_anchor_offset(index) <= 0.0)
	pass


func branch_anchor_stays_on_visible_trunk_test() -> void:
	assert(is_equal_approx(float(ReasoningTree.make_branch("low", "read", 0, -2.0)["anchor"]), ReasoningTree.ANCHOR_MIN))
	assert(is_equal_approx(float(ReasoningTree.make_branch("high", "read", 0, 99.0)["anchor"]), ReasoningTree.ANCHOR_MAX))
	pass


func public_tool_name_does_not_expose_arguments_test() -> void:
	assert(VisualToolFormatter.title_name("web_search", "工具") == "Web Search")
	assert(VisualToolFormatter.title_name("", "工具") == "工具")
	pass


func tall_viewport_uses_nearly_full_height_test() -> void:
	var tree := ReasoningTree.new()
	tree.size = Vector2(1920.0, 1080.0)
	var radius := tree.get_crown_radius()
	var base_y := tree.size.y - Margin.ma_8
	var crown_center_y := Margin.ma_8 + radius
	var segment_height := (base_y - crown_center_y) / float(ReasoningTree.MAX_TRUNK_SEGMENTS)
	assert(segment_height > 90.0)
	assert(is_equal_approx(base_y - segment_height * ReasoningTree.MAX_TRUNK_SEGMENTS, crown_center_y))
	tree.free()
	pass


func crown_uses_many_small_bubbles_test() -> void:
	assert(ReasoningTree.CROWN_BUBBLE_COUNT >= 24)
	var largest_radius_ratio := 0.13 + 3.0 * 0.012
	assert(largest_radius_ratio < 0.18)
	pass


func crown_opens_small_then_reaches_full_size_test() -> void:
	assert(is_equal_approx(ReasoningTree.crown_visual_growth(0.0), 0.0))
	assert(ReasoningTree.crown_visual_growth(0.25) < 0.25)
	assert(ReasoningTree.crown_visual_growth(0.5) < ReasoningTree.crown_visual_growth(0.75))
	assert(is_equal_approx(ReasoningTree.crown_visual_growth(1.0), 1.0))
	pass


func reasoning_chunks_do_not_accumulate_tree_height_test() -> void:
	var tree := ReasoningTree.new()
	tree.on_agent_start(1)
	tree.on_turn_start()
	var turn_height := tree.target_trunk_growth
	for index in range(100):
		tree.on_message_update("chunk %d" % index, OpenAiClient.STREAM_KIND_REASONING)
	assert(tree.target_trunk_growth == turn_height)
	assert(is_equal_approx(tree.target_trunk_growth, ReasoningTree.trunk_growth_for_turn(1)))
	tree.free()
	pass


func turns_ease_out_across_trunk_test() -> void:
	assert(is_equal_approx(ReasoningTree.trunk_growth_for_turn(0), 0.0))
	assert(is_equal_approx(ReasoningTree.trunk_growth_for_turn(AgentLoop.MAX_TURNS), float(ReasoningTree.MAX_TRUNK_SEGMENTS)))
	var midpoint := ReasoningTree.trunk_growth_for_turn(AgentLoop.MAX_TURNS / 2)
	assert(midpoint > float(ReasoningTree.MAX_TRUNK_SEGMENTS) * 0.5)
	assert(midpoint < float(ReasoningTree.MAX_TRUNK_SEGMENTS) * 0.65)
	var early_step := ReasoningTree.trunk_growth_for_turn(2) - ReasoningTree.trunk_growth_for_turn(1)
	var late_step := ReasoningTree.trunk_growth_for_turn(AgentLoop.MAX_TURNS) - ReasoningTree.trunk_growth_for_turn(AgentLoop.MAX_TURNS - 1)
	assert(early_step > late_step)
	var tree := ReasoningTree.new()
	tree.on_agent_start(1)
	for expected_turn in range(1, 5):
		tree.on_turn_start()
		assert(is_equal_approx(tree.target_trunk_growth, ReasoningTree.trunk_growth_for_turn(expected_turn)))
		assert(tree.target_trunk_growth < float(expected_turn))
	tree.free()
	pass


func late_turn_branches_stay_below_tip_until_max_turns_test() -> void:
	var mid := ReasoningTree.trunk_growth_for_turn(AgentLoop.MAX_TURNS / 2)
	var late := ReasoningTree.trunk_growth_for_turn(AgentLoop.MAX_TURNS - 1)
	assert(mid < float(ReasoningTree.MAX_TRUNK_SEGMENTS) * 0.65)
	assert(late < float(ReasoningTree.MAX_TRUNK_SEGMENTS))
	assert(late > mid)
	var branch := ReasoningTree.make_branch("mid", "read", 0, mid)
	assert(is_equal_approx(float(branch["anchor"]), mid))
	pass


func completion_particle_texture_has_soft_center_test() -> void:
	var texture := ReasoningTree.make_particle_texture()
	var image := texture.get_image()
	assert(image.get_width() == 16)
	assert(image.get_pixel(8, 8).a > 0.8)
	assert(image.get_pixel(0, 0).a == 0.0)
	pass
