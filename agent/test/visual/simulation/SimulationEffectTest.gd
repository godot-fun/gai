static func create_simulation_effects() -> Array[SimulationEffect]:
	return [RippleSurface.new(), TuringBloom.new(), ThermalTrace.new(), InkFluid.new(), GlassRain.new(), ChladniPlate.new()]


static func every_effect_chains_at_least_two_passes_test() -> void:
	for effect: SimulationEffect in create_simulation_effects():
		assert(effect.pass_kinds().size() >= 2)
		assert(effect.field_downscale() >= 1.0)
		effect.free()
	pass


static func energy_composition_is_additive_without_overflow_test() -> void:
	assert(is_equal_approx(SimulationEffect.combine_energy(0.0, 0.4), 0.4))
	assert(SimulationEffect.combine_energy(0.6, 0.5) > 0.6)
	assert(SimulationEffect.combine_energy(1.0, 1.0) == 1.0)
	pass


static func field_size_follows_downscale_with_floor_test() -> void:
	assert(SimulationEffect.field_size_for_screen(Vector2(2560, 1440), 4.0) == Vector2i(640, 360))
	assert(SimulationEffect.field_size_for_screen(Vector2(10, 10), 4.0) == Vector2i(16, 16))
	pass


static func tool_anchor_is_stable_and_inside_body_test() -> void:
	var anchor := SimulationEffect.tool_anchor("grep")
	assert(anchor == SimulationEffect.tool_anchor("grep"))
	assert(anchor.x > 0.1 and anchor.x < 0.9)
	assert(anchor.y > 0.2 and anchor.y < 0.8)
	pass


func impulse_queue_caps_per_frame_test() -> void:
	var effect := RippleSurface.new()
	for index in range(SimulationEffect.MAX_IMPULSES + 4):
		effect.queue_impulse(Vector2(0.5, 0.5), 0.01, 1.0)
	assert(effect.impulse_shapes.size() == SimulationEffect.MAX_IMPULSES)
	assert(effect.impulse_vectors.size() == SimulationEffect.MAX_IMPULSES)
	effect.free()
	pass


func activity_holds_during_run_and_decays_after_end_test() -> void:
	var effect := InkFluid.new()
	effect.on_agent_start(1)
	for _index in range(120):
		effect.step_activity(1.0 / 60.0)
	assert(is_equal_approx(effect.activity, 1.0))
	await effect.on_agent_end(1, "")
	for _index in range(240):
		effect.step_activity(1.0 / 60.0)
	assert(effect.activity == 0.0)
	effect.free()
	pass


func chain_builds_one_viewport_per_pass_in_tree_test() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	for effect: SimulationEffect in create_simulation_effects():
		scene_tree.root.add_child.call_deferred(effect)
		await scene_tree.process_frame
		assert(effect.chain.pass_count() == effect.pass_kinds().size())
		assert(effect.display_material.shader != null)
		assert(not effect.chain.running)
		effect.on_agent_start(1)
		effect.set_visual_visible(true, false)
		await scene_tree.process_frame
		await scene_tree.process_frame
		assert(effect.chain.running)
		effect.queue_free()
	await scene_tree.process_frame
	pass
