const TEMPORAL_PRISM_SCRIPT := preload("res://agent/ui/visuals/temporal_prism/TemporalPrism.gd")


static func visual_script_instantiates_test() -> void:
	var effect: Variant = TEMPORAL_PRISM_SCRIPT.new()
	assert(effect.get_script() == TEMPORAL_PRISM_SCRIPT)
	effect.free()
	pass


static func energy_composition_is_additive_without_overflow_test() -> void:
	assert(is_equal_approx(TEMPORAL_PRISM_SCRIPT.combine_energy(0.0, 0.4), 0.4))
	assert(TEMPORAL_PRISM_SCRIPT.combine_energy(0.6, 0.5) > 0.6)
	assert(TEMPORAL_PRISM_SCRIPT.combine_energy(0.6, 0.5) < 1.0)
	assert(TEMPORAL_PRISM_SCRIPT.combine_energy(1.0, 1.0) == 1.0)
	pass


static func streamed_chunks_have_restrained_energy_test() -> void:
	var short_energy: float = TEMPORAL_PRISM_SCRIPT.stream_energy_for_length(1)
	var long_energy: float = TEMPORAL_PRISM_SCRIPT.stream_energy_for_length(1000)
	assert(short_energy > 0.0)
	assert(long_energy > short_energy)
	assert(is_equal_approx(long_energy, 0.045))
	pass


static func slice_count_adapts_to_viewport_width_test() -> void:
	assert(TEMPORAL_PRISM_SCRIPT.slice_count_for_width(0.0) == 28.0)
	assert(TEMPORAL_PRISM_SCRIPT.slice_count_for_width(800.0) == 28.0)
	assert(TEMPORAL_PRISM_SCRIPT.slice_count_for_width(1920.0) == 51.0)
	assert(TEMPORAL_PRISM_SCRIPT.slice_count_for_width(2560.0) == 67.0)
	assert(TEMPORAL_PRISM_SCRIPT.slice_count_for_width(3840.0) == 96.0)
	pass


func active_events_add_energy_without_replacing_phase_test() -> void:
	var effect: Variant = TEMPORAL_PRISM_SCRIPT.new()
	effect.temporal_energy = 0.5
	effect.temporal_phase = 2.4
	effect.temporal_direction = -1.0
	effect.pulse(0.5)
	assert(effect.temporal_energy > 0.5)
	assert(is_equal_approx(effect.temporal_phase, 2.4))
	assert(is_equal_approx(effect.temporal_direction, -1.0))
	effect.free()
	pass


func temporal_field_decays_to_original_frame_test() -> void:
	var effect: Variant = TEMPORAL_PRISM_SCRIPT.new()
	effect.temporal_energy = 0.8
	effect.step_temporal_field(1.0 / 60.0)
	assert(effect.temporal_energy < 0.8)
	assert(effect.temporal_phase > 0.0)
	effect.temporal_energy = 0.0001
	effect.step_temporal_field(1.0 / 60.0)
	assert(effect.temporal_energy == 0.0)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = TEMPORAL_PRISM_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.prism_material != null)
	assert(effect.prism_material.shader != null)
	effect.queue_free()
	await scene_tree.process_frame
	pass
