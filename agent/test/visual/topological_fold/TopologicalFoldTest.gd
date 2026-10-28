const TOPOLOGICAL_FOLD_SCRIPT := preload("res://agent/ui/visuals/topological_fold/TopologicalFold.gd")


static func visual_script_instantiates_test() -> void:
	var effect: Variant = TOPOLOGICAL_FOLD_SCRIPT.new()
	assert(effect.get_script() == TOPOLOGICAL_FOLD_SCRIPT)
	effect.free()
	pass


static func energy_composition_deepens_without_overflow_test() -> void:
	assert(is_equal_approx(TOPOLOGICAL_FOLD_SCRIPT.combine_energy(0.0, 0.5), 0.5))
	assert(TOPOLOGICAL_FOLD_SCRIPT.combine_energy(0.6, 0.5) > 0.6)
	assert(TOPOLOGICAL_FOLD_SCRIPT.combine_energy(0.6, 0.5) < 1.0)
	assert(TOPOLOGICAL_FOLD_SCRIPT.combine_energy(1.0, 1.0) == 1.0)
	pass


static func streamed_chunks_keep_fold_restrained_test() -> void:
	assert(is_equal_approx(TOPOLOGICAL_FOLD_SCRIPT.stream_energy_for_length(1), 0.003))
	assert(is_equal_approx(TOPOLOGICAL_FOLD_SCRIPT.stream_energy_for_length(1000), 0.036))
	pass


static func anchors_skip_latest_and_keep_distance_test() -> void:
	assert(TOPOLOGICAL_FOLD_SCRIPT.fold_candidate_indices(2) == Vector2i(-1, -1))
	assert(TOPOLOGICAL_FOLD_SCRIPT.fold_candidate_indices(3) == Vector2i(0, 1))
	assert(TOPOLOGICAL_FOLD_SCRIPT.fold_candidate_indices(6) == Vector2i(0, 4))
	assert(TOPOLOGICAL_FOLD_SCRIPT.fold_candidate_indices(10) == Vector2i(4, 8))
	pass


static func sidebar_anchors_keep_the_fold_local_test() -> void:
	assert(TOPOLOGICAL_FOLD_SCRIPT.sidebar_candidate_indices(1) == Vector2i(-1, -1))
	assert(TOPOLOGICAL_FOLD_SCRIPT.sidebar_candidate_indices(2) == Vector2i(0, 1))
	assert(TOPOLOGICAL_FOLD_SCRIPT.sidebar_candidate_indices(3) == Vector2i(0, 1))
	assert(TOPOLOGICAL_FOLD_SCRIPT.sidebar_candidate_indices(8) == Vector2i(2, 6))
	assert(is_equal_approx(TOPOLOGICAL_FOLD_SCRIPT.SIDEBAR_FOLD_STRENGTH, 0.62))
	pass


static func chat_viewport_fallback_always_has_separated_anchors_test() -> void:
	var anchors: Array[Rect2] = TOPOLOGICAL_FOLD_SCRIPT.fallback_chat_anchor_rects(Rect2(260.0, 40.0, 1740.0, 960.0))
	assert(anchors.size() == 2)
	assert(is_equal_approx(anchors[0].get_center().y, 328.0))
	assert(is_equal_approx(anchors[1].get_center().y, 712.0))
	assert(anchors[1].get_center().y - anchors[0].get_center().y > TOPOLOGICAL_FOLD_SCRIPT.MIN_ANCHOR_GAP_PX)
	pass


static func anchor_rect_normalizes_to_viewport_test() -> void:
	var normalized: Vector4 = TOPOLOGICAL_FOLD_SCRIPT.normalized_rect(Rect2(200.0, 100.0, 400.0, 300.0), Vector2(1000.0, 500.0))
	assert(normalized.is_equal_approx(Vector4(0.2, 0.2, 0.4, 0.6)))
	assert(TOPOLOGICAL_FOLD_SCRIPT.normalized_rect(Rect2(), Vector2.ZERO) == Vector4.ZERO)
	pass


func fold_spring_opens_and_returns_to_source_test() -> void:
	var effect: Variant = TOPOLOGICAL_FOLD_SCRIPT.new()
	effect.fold_energy = 1.0
	for _index in range(12):
		effect.step_fold(1.0 / 60.0)
	assert(effect.fold_amount > 0.0)
	assert(effect.fold_energy < 1.0)
	effect.fold_energy = 0.0
	for _index in range(180):
		effect.step_fold(1.0 / 60.0)
	assert(effect.fold_amount < 0.01)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = TOPOLOGICAL_FOLD_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.fold_material != null)
	assert(effect.fold_material.shader != null)
	effect.queue_free()
	await scene_tree.process_frame
	pass
