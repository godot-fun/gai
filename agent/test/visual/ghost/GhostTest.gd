const GHOST_SCRIPT := preload("res://agent/ui/visuals/ghost/Ghost.gd")


static func visual_script_instantiates_test() -> void:
	var effect: Variant = GHOST_SCRIPT.new()
	assert(effect.get_script() == GHOST_SCRIPT)
	effect.free()
	pass


static func energy_composition_deepens_without_overflow_test() -> void:
	assert(is_equal_approx(GHOST_SCRIPT.combine_energy(0.0, 0.5), 0.5))
	assert(GHOST_SCRIPT.combine_energy(0.6, 0.5) > 0.6)
	assert(GHOST_SCRIPT.combine_energy(0.6, 0.5) < 1.0)
	assert(GHOST_SCRIPT.combine_energy(1.0, 1.0) == 1.0)
	pass


static func streamed_chunks_keep_pressure_restrained_test() -> void:
	assert(is_equal_approx(GHOST_SCRIPT.stream_energy_for_length(1), 0.003))
	assert(is_equal_approx(GHOST_SCRIPT.stream_energy_for_length(1000), 0.042))
	pass


static func presence_center_stays_inside_effective_viewport_test() -> void:
	assert(GHOST_SCRIPT.clamp_presence_center(Vector2(-1.0, 2.0)).is_equal_approx(Vector2(0.10, 0.88)))
	assert(GHOST_SCRIPT.clamp_presence_center(Vector2(0.5, 0.5)).is_equal_approx(Vector2(0.5, 0.5)))
	pass


static func body_effect_keeps_toolbar_stable_test() -> void:
	assert(GHOST_SCRIPT.body_effect_rect(Vector2(1920.0, 1080.0), 48.0).is_equal_approx(Vector4(0.0, 48.0 / 1080.0, 1.0, 1.0 - 48.0 / 1080.0)))
	assert(GHOST_SCRIPT.body_effect_rect(Vector2.ZERO, 48.0) == Vector4.ZERO)
	pass


func presence_spring_arrives_and_heals_test() -> void:
	var effect: Variant = GHOST_SCRIPT.new()
	effect.presence_energy = 1.0
	for _index in range(16):
		effect.step_presence(1.0 / 60.0)
	assert(effect.presence_strength > 0.0)
	assert(effect.presence_energy < 1.0)
	effect.presence_energy = 0.0
	for _index in range(220):
		effect.step_presence(1.0 / 60.0)
	assert(effect.presence_strength < 0.01)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = GHOST_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.presence_material != null)
	assert(effect.presence_material.shader != null)
	effect.queue_free()
	await scene_tree.process_frame
	pass
