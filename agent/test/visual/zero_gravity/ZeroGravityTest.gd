const ZERO_GRAVITY_SCRIPT := preload("res://agent/ui/visuals/zero_gravity/ZeroGravity.gd")


static func visual_script_instantiates_test() -> void:
	var effect: Variant = ZERO_GRAVITY_SCRIPT.new()
	assert(effect.get_script() == ZERO_GRAVITY_SCRIPT)
	effect.free()
	pass


static func energy_composition_deepens_without_overflow_test() -> void:
	assert(is_equal_approx(ZERO_GRAVITY_SCRIPT.combine_energy(0.0, 0.5), 0.5))
	assert(ZERO_GRAVITY_SCRIPT.combine_energy(0.6, 0.5) > 0.6)
	assert(ZERO_GRAVITY_SCRIPT.combine_energy(0.6, 0.5) < 1.0)
	assert(ZERO_GRAVITY_SCRIPT.combine_energy(1.0, 1.0) == 1.0)
	pass


static func streamed_chunks_keep_pressure_restrained_test() -> void:
	assert(is_equal_approx(ZERO_GRAVITY_SCRIPT.stream_energy_for_length(1), 0.003))
	assert(is_equal_approx(ZERO_GRAVITY_SCRIPT.stream_energy_for_length(1000), 0.042))
	pass


static func field_center_stays_inside_effective_viewport_test() -> void:
	assert(ZERO_GRAVITY_SCRIPT.clamp_field_center(Vector2(-1.0, 2.0)).is_equal_approx(Vector2(0.08, 0.90)))
	assert(ZERO_GRAVITY_SCRIPT.clamp_field_center(Vector2(0.5, 0.5)).is_equal_approx(Vector2(0.5, 0.5)))
	pass


static func body_effect_covers_full_viewport_test() -> void:
	assert(ZERO_GRAVITY_SCRIPT.body_effect_rect(Vector2(1920.0, 1080.0), 0.0).is_equal_approx(Vector4(0.0, 0.0, 1.0, 1.0)))
	assert(ZERO_GRAVITY_SCRIPT.body_effect_rect(Vector2.ZERO, 48.0) == Vector4.ZERO)
	pass


static func semantic_mass_makes_thinking_light_and_tools_heavy_test() -> void:
	var thinking_mass: float = ZERO_GRAVITY_SCRIPT.semantic_mass_for_path("ThinkingBubble.gd", 92.0)
	var agent_mass: float = ZERO_GRAVITY_SCRIPT.semantic_mass_for_path("AgentBubble.gd", 92.0)
	var tool_mass: float = ZERO_GRAVITY_SCRIPT.semantic_mass_for_path("ToolBubble.gd", 92.0)
	assert(thinking_mass < agent_mass)
	assert(tool_mass > agent_mass)
	assert(ZERO_GRAVITY_SCRIPT.semantic_mass_for_path("AgentBubble.gd", 300.0) > agent_mass)
	pass


static func field_contact_is_strongest_near_center_test() -> void:
	assert(ZERO_GRAVITY_SCRIPT.ellipse_contact(Vector2.ZERO, Vector2.ZERO, 100.0, 0.72) > 0.99)
	assert(ZERO_GRAVITY_SCRIPT.ellipse_contact(Vector2(200.0, 0.0), Vector2.ZERO, 100.0, 0.72) < 0.01)
	pass


static func sidebar_uses_a_broad_vertical_field_test() -> void:
	assert(ZERO_GRAVITY_SCRIPT.axis_contact(500.0, 500.0, 200.0) > 0.99)
	assert(ZERO_GRAVITY_SCRIPT.axis_contact(900.0, 500.0, 200.0) < 0.01)
	assert(ZERO_GRAVITY_SCRIPT.SIDEBAR_MOTION_SCALE < 1.0)
	assert(ZERO_GRAVITY_SCRIPT.SIDEBAR_MASS_SCALE < 1.0)
	assert(ZERO_GRAVITY_SCRIPT.MAX_BODY_COUNT == 22)
	pass


static func sidebar_reevaluation_runs_only_during_active_motion_test() -> void:
	var interval: float = ZERO_GRAVITY_SCRIPT.SIDEBAR_REEVALUATE_SECONDS
	assert(not ZERO_GRAVITY_SCRIPT.should_reevaluate_sidebar(0.0, 0.0, interval * 2.0))
	assert(not ZERO_GRAVITY_SCRIPT.should_reevaluate_sidebar(1.0, 1.0, interval * 0.5))
	assert(ZERO_GRAVITY_SCRIPT.should_reevaluate_sidebar(0.2, 0.0, interval))
	assert(ZERO_GRAVITY_SCRIPT.should_reevaluate_sidebar(0.0, 0.2, interval))
	pass


func retiring_sidebar_body_waits_until_it_has_settled_test() -> void:
	var effect: Variant = ZERO_GRAVITY_SCRIPT.new()
	var control := Control.new()
	var body: Variant = ZERO_GRAVITY_SCRIPT.FloatingBodyState.new(control, 1.0, 0.5, true, ZERO_GRAVITY_SCRIPT.SIDEBAR_MOTION_SCALE)
	body.target_participation = 0.0
	body.participation = 0.5
	effect.bodies.append(body)
	effect.retire_settled_sidebar_bodies()
	assert(effect.bodies.size() == 1)
	body.participation = 0.0
	effect.retire_settled_sidebar_bodies()
	assert(effect.bodies.is_empty())
	control.free()
	effect.free()
	pass


func field_spring_arrives_and_heals_test() -> void:
	var effect: Variant = ZERO_GRAVITY_SCRIPT.new()
	effect.field_energy = 1.0
	for _index in range(16):
		effect.step_field(1.0 / 60.0)
	assert(effect.field_strength > 0.0)
	assert(effect.field_energy < 1.0)
	effect.field_energy = 0.0
	for _index in range(220):
		effect.step_field(1.0 / 60.0)
	assert(effect.field_strength < 0.01)
	effect.free()
	pass


func inertial_momentum_outlives_force_test() -> void:
	var effect: Variant = ZERO_GRAVITY_SCRIPT.new()
	effect.pulse(1.0)
	for _index in range(120):
		effect.step_field(1.0 / 60.0)
	assert(effect.drift_momentum > effect.field_energy)
	assert(effect.drift_momentum > 0.0)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = ZERO_GRAVITY_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.zero_gravity_material != null)
	assert(effect.zero_gravity_material.shader != null)
	var control := Control.new()
	var body: Variant = ZERO_GRAVITY_SCRIPT.FloatingBodyState.new(control, 1.0, 0.5)
	body.rect = Rect2(100.0, 120.0, 640.0, 96.0)
	body.offset = Vector2(24.0, -18.0)
	effect.bodies.append(body)
	effect.size = Vector2(1920.0, 1080.0)
	effect.apply_shader_state()
	assert(effect.zero_gravity_material.get_shader_parameter("body_count") == 1)
	var packed_rects: PackedVector4Array = effect.zero_gravity_material.get_shader_parameter("body_rects")
	var packed_motions: PackedVector4Array = effect.zero_gravity_material.get_shader_parameter("body_motions")
	assert(packed_rects.size() == ZERO_GRAVITY_SCRIPT.MAX_BODY_COUNT)
	assert(packed_motions.size() == ZERO_GRAVITY_SCRIPT.MAX_BODY_COUNT)
	control.free()
	effect.queue_free()
	await scene_tree.process_frame
	pass
