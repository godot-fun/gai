const INTERFACE_DELAMINATION_SCRIPT := preload("res://agent/ui/visuals/interface_delamination/InterfaceDelamination.gd")


static func visual_script_instantiates_test() -> void:
	var effect: Variant = INTERFACE_DELAMINATION_SCRIPT.new()
	assert(effect.get_script() == INTERFACE_DELAMINATION_SCRIPT)
	effect.free()
	pass


static func energy_composition_deepens_without_overflow_test() -> void:
	assert(is_equal_approx(INTERFACE_DELAMINATION_SCRIPT.combine_energy(0.0, 0.5), 0.5))
	assert(INTERFACE_DELAMINATION_SCRIPT.combine_energy(0.6, 0.5) > 0.6)
	assert(INTERFACE_DELAMINATION_SCRIPT.combine_energy(0.6, 0.5) < 1.0)
	assert(INTERFACE_DELAMINATION_SCRIPT.combine_energy(1.0, 1.0) == 1.0)
	pass


static func streamed_chunks_keep_separation_restrained_test() -> void:
	assert(is_equal_approx(INTERFACE_DELAMINATION_SCRIPT.stream_energy_for_length(1), 0.003))
	assert(is_equal_approx(INTERFACE_DELAMINATION_SCRIPT.stream_energy_for_length(1000), 0.038))
	pass


static func latest_visible_control_becomes_focus_test() -> void:
	assert(INTERFACE_DELAMINATION_SCRIPT.latest_focus_candidate_index(0) == -1)
	assert(INTERFACE_DELAMINATION_SCRIPT.latest_focus_candidate_index(1) == 0)
	assert(INTERFACE_DELAMINATION_SCRIPT.latest_focus_candidate_index(8) == 7)
	pass


static func focus_rect_normalizes_to_viewport_test() -> void:
	var normalized: Vector4 = INTERFACE_DELAMINATION_SCRIPT.normalized_rect(Rect2(200.0, 100.0, 400.0, 300.0), Vector2(1000.0, 500.0))
	assert(normalized.is_equal_approx(Vector4(0.2, 0.2, 0.4, 0.6)))
	assert(INTERFACE_DELAMINATION_SCRIPT.normalized_rect(Rect2(), Vector2.ZERO) == Vector4.ZERO)
	pass


static func body_effect_covers_full_viewport_test() -> void:
	assert(INTERFACE_DELAMINATION_SCRIPT.body_effect_rect(Vector2(1920.0, 1080.0), 0.0).is_equal_approx(Vector4(0.0, 0.0, 1.0, 1.0)))
	assert(INTERFACE_DELAMINATION_SCRIPT.body_effect_rect(Vector2.ZERO, 48.0) == Vector4.ZERO)
	pass


func layer_spring_separates_and_reattaches_test() -> void:
	var effect: Variant = INTERFACE_DELAMINATION_SCRIPT.new()
	effect.delamination_energy = 1.0
	for _index in range(12):
		effect.step_delamination(1.0 / 60.0)
	assert(effect.layer_separation > 0.0)
	assert(effect.delamination_energy < 1.0)
	effect.delamination_energy = 0.0
	for _index in range(180):
		effect.step_delamination(1.0 / 60.0)
	assert(effect.layer_separation < 0.01)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = INTERFACE_DELAMINATION_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.delamination_material != null)
	assert(effect.delamination_material.shader != null)
	effect.queue_free()
	await scene_tree.process_frame
	pass
