const MIGRATING_VOID_SCRIPT := preload("res://agent/ui/visuals/migrating_void/MigratingVoid.gd")


static func visual_script_instantiates_test() -> void:
	var effect: Variant = MIGRATING_VOID_SCRIPT.new()
	assert(effect.get_script() == MIGRATING_VOID_SCRIPT)
	effect.free()
	pass


static func energy_composition_deepens_without_overflow_test() -> void:
	assert(is_equal_approx(MIGRATING_VOID_SCRIPT.combine_energy(0.0, 0.5), 0.5))
	assert(MIGRATING_VOID_SCRIPT.combine_energy(0.6, 0.5) > 0.6)
	assert(MIGRATING_VOID_SCRIPT.combine_energy(0.6, 0.5) < 1.0)
	pass


static func route_moves_out_and_returns_test() -> void:
	assert(is_equal_approx(MIGRATING_VOID_SCRIPT.route_progress(0.0), 0.0))
	assert(is_equal_approx(MIGRATING_VOID_SCRIPT.route_progress(1.0), 1.0))
	assert(is_equal_approx(MIGRATING_VOID_SCRIPT.route_progress(2.0), 0.0))
	pass


static func a_journey_only_finishes_at_its_destination_test() -> void:
	assert(not MIGRATING_VOID_SCRIPT.cycle_is_finished(0.999))
	assert(MIGRATING_VOID_SCRIPT.cycle_is_finished(1.0))
	assert(MIGRATING_VOID_SCRIPT.cycle_is_finished(1.4))
	pass


func next_bubble_waits_for_the_active_journey_test() -> void:
	var effect: Variant = MIGRATING_VOID_SCRIPT.new()
	var first := Control.new()
	var second := Control.new()
	effect.active_bubble = first
	effect.pending_bubbles.append(second)
	effect.route_phase = 1.0
	effect.void_amount = 0.4
	effect.step_void(1.0 / 60.0)
	assert(effect.active_bubble == first)
	assert(effect.is_handing_off)
	effect.void_amount = 0.0
	effect.void_velocity = 0.0
	effect.step_void(1.0 / 60.0)
	assert(effect.active_bubble == second)
	assert(not effect.is_handing_off)
	first.free()
	second.free()
	effect.free()
	pass


static func void_size_is_safe_for_any_viewport_test() -> void:
	var normalized := MIGRATING_VOID_SCRIPT.void_size_normalized(Vector2(1920.0, 1080.0), 248.0, 92.0)
	assert(normalized.x > 0.10 and normalized.x < 0.20)
	assert(normalized.y > 0.05 and normalized.y < 0.10)
	assert(MIGRATING_VOID_SCRIPT.void_size_normalized(Vector2.ZERO, 248.0, 92.0) == Vector2.ZERO)
	pass


static func route_stays_inside_the_interactive_surface_test() -> void:
	assert(MIGRATING_VOID_SCRIPT.clamp_route_point(Vector2(-1.0, 2.0)).is_equal_approx(Vector2(0.08, 0.90)))
	assert(MIGRATING_VOID_SCRIPT.effect_area_rect(Vector2(1920.0, 1080.0), 48.0).is_equal_approx(Vector4(0.0, 48.0 / 1080.0, 1.0, 1.0 - 48.0 / 1080.0)))
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = MIGRATING_VOID_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.void_material != null)
	assert(effect.void_material.shader != null)
	effect.size = Vector2(1920.0, 1080.0)
	var active_bubble := Control.new()
	effect.active_bubble = active_bubble
	effect.void_energy = 1.0
	for _index in range(12):
		effect.step_void(1.0 / 60.0)
	effect.apply_shader_state()
	var center: Vector2 = effect.void_material.get_shader_parameter("void_center")
	assert(center.x >= 0.08 and center.x <= 0.92)
	assert(effect.void_material.get_shader_parameter("void_amount") > 0.0)
	active_bubble.free()
	effect.queue_free()
	await scene_tree.process_frame
	pass
