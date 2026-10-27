const RECURSIVE_INTERFACE_SCRIPT := preload("res://agent/ui/visuals/recursive_interface/RecursiveInterface.gd")


static func visual_script_instantiates_test() -> void:
	var effect: Variant = RECURSIVE_INTERFACE_SCRIPT.new()
	assert(effect.get_script() == RECURSIVE_INTERFACE_SCRIPT)
	effect.free()
	pass


static func energy_composition_deepens_without_overflow_test() -> void:
	assert(is_equal_approx(RECURSIVE_INTERFACE_SCRIPT.combine_energy(0.0, 0.5), 0.5))
	assert(RECURSIVE_INTERFACE_SCRIPT.combine_energy(0.6, 0.5) > 0.6)
	assert(RECURSIVE_INTERFACE_SCRIPT.combine_energy(0.6, 0.5) < 1.0)
	assert(RECURSIVE_INTERFACE_SCRIPT.combine_energy(1.0, 1.0) == 1.0)
	pass


static func streamed_chunks_keep_recursion_restrained_test() -> void:
	var short_energy: float = RECURSIVE_INTERFACE_SCRIPT.stream_energy_for_length(1)
	var long_energy: float = RECURSIVE_INTERFACE_SCRIPT.stream_energy_for_length(1000)
	assert(short_energy > 0.0)
	assert(long_energy > short_energy)
	assert(is_equal_approx(long_energy, 0.032))
	pass


static func portal_rect_normalizes_to_viewport_test() -> void:
	var normalized: Vector4 = RECURSIVE_INTERFACE_SCRIPT.normalized_rect(Rect2(200.0, 100.0, 400.0, 300.0), Vector2(1000.0, 500.0))
	assert(normalized.is_equal_approx(Vector4(0.2, 0.2, 0.4, 0.6)))
	assert(RECURSIVE_INTERFACE_SCRIPT.normalized_rect(Rect2(), Vector2.ZERO) == Vector4.ZERO)
	pass


static func portal_uses_eight_bubbles_before_latest_test() -> void:
	assert(RECURSIVE_INTERFACE_SCRIPT.portal_candidate_indices(1) == [])
	assert(RECURSIVE_INTERFACE_SCRIPT.portal_candidate_indices(2) == [0])
	assert(RECURSIVE_INTERFACE_SCRIPT.portal_candidate_indices(3) == [1, 0])
	assert(RECURSIVE_INTERFACE_SCRIPT.portal_candidate_indices(5) == [3, 2, 1, 0])
	assert(RECURSIVE_INTERFACE_SCRIPT.portal_candidate_indices(10) == [8, 7, 6, 5, 4, 3, 2, 1])
	pass


static func portal_strengths_decay_smoothly_across_eight_bubbles_test() -> void:
	assert(RECURSIVE_INTERFACE_SCRIPT.PORTAL_STRENGTHS_NEAR == Vector4(1.0, 0.86, 0.73, 0.61))
	assert(RECURSIVE_INTERFACE_SCRIPT.PORTAL_STRENGTHS_FAR == Vector4(0.50, 0.40, 0.31, 0.23))
	pass


func active_recursion_cannot_be_replaced_test() -> void:
	var effect: Variant = RECURSIVE_INTERFACE_SCRIPT.new()
	effect.recursion_energy = 0.5
	effect.recursion_phase = 1.7
	effect.recursion_direction = 1.0
	effect.pulse(0.8, -1.0)
	assert(effect.recursion_energy > 0.5)
	assert(is_equal_approx(effect.recursion_phase, 1.7))
	assert(is_equal_approx(effect.recursion_direction, 1.0))
	effect.free()
	pass


func recursion_settles_back_to_source_test() -> void:
	var effect: Variant = RECURSIVE_INTERFACE_SCRIPT.new()
	effect.recursion_energy = 0.8
	effect.step_recursion(1.0 / 60.0)
	assert(effect.recursion_energy < 0.8)
	assert(effect.recursion_phase > 0.0)
	effect.recursion_energy = 0.0001
	effect.step_recursion(1.0 / 60.0)
	assert(effect.recursion_energy == 0.0)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = RECURSIVE_INTERFACE_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.recursive_material != null)
	assert(effect.recursive_material.shader != null)
	effect.queue_free()
	await scene_tree.process_frame
	pass
