const HEAT_MIRAGE_SCRIPT := preload("res://agent/ui/visuals/heat_mirage/HeatMirage.gd")


static func visual_type_is_registered_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.HEAT_MIRAGE)
	assert(effect != null)
	assert(effect.get_script() == HEAT_MIRAGE_SCRIPT)
	effect.free()
	pass


static func energy_composition_is_additive_without_overflow_test() -> void:
	assert(is_equal_approx(HEAT_MIRAGE_SCRIPT.combine_energy(0.0, 0.4), 0.4))
	assert(HEAT_MIRAGE_SCRIPT.combine_energy(0.6, 0.5) > 0.6)
	assert(HEAT_MIRAGE_SCRIPT.combine_energy(1.0, 1.0) == 1.0)
	pass


func reasoning_stream_targets_mirage_strength_test() -> void:
	var effect: Variant = HEAT_MIRAGE_SCRIPT.new()
	effect.on_message_update(1, "think", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.target_mirage > 0.0)
	effect.step_mirage_field(1.0 / 60.0)
	assert(effect.mirage_strength > 0.0)
	effect.free()
	pass


func flow_phase_rest_when_flow_is_idle_test() -> void:
	var effect: Variant = HEAT_MIRAGE_SCRIPT.new()
	effect.flow_phase = 1.1
	effect.flow_strength = 0.0
	effect.step_mirage_field(1.0 / 60.0)
	assert(is_equal_approx(effect.flow_phase, 1.1))
	effect.flow_strength = 0.8
	effect.step_mirage_field(1.0 / 60.0)
	assert(effect.flow_phase != 1.1)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = HEAT_MIRAGE_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.mirage_material != null)
	assert(effect.mirage_material.shader != null)
	effect.queue_free()
	await scene_tree.process_frame
	pass
