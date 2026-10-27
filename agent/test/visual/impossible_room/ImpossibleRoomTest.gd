const IMPOSSIBLE_ROOM_SCRIPT := preload("res://agent/ui/visuals/impossible_room/ImpossibleRoom.gd")


static func visual_script_instantiates_test() -> void:
	var effect: Variant = IMPOSSIBLE_ROOM_SCRIPT.new()
	assert(effect.get_script() == IMPOSSIBLE_ROOM_SCRIPT)
	effect.free()
	pass


static func sentence_impulse_scales_and_clamps_test() -> void:
	var short_impulse: float = IMPOSSIBLE_ROOM_SCRIPT.impulse_for_sentence("Hi.")
	var medium_impulse: float = IMPOSSIBLE_ROOM_SCRIPT.impulse_for_sentence("A complete sentence with enough weight to move the room.")
	var huge_impulse: float = IMPOSSIBLE_ROOM_SCRIPT.impulse_for_sentence("x".repeat(1000))
	assert(short_impulse >= 360.0)
	assert(medium_impulse > short_impulse)
	assert(is_equal_approx(huge_impulse, 780.0))
	pass


static func anchor_rect_normalizes_to_viewport_test() -> void:
	var normalized: Vector4 = IMPOSSIBLE_ROOM_SCRIPT.normalized_anchor_rect(Rect2(200.0, 100.0, 400.0, 300.0), Vector2(1000.0, 500.0))
	assert(normalized.is_equal_approx(Vector4(0.2, 0.2, 0.4, 0.6)))
	assert(IMPOSSIBLE_ROOM_SCRIPT.normalized_anchor_rect(Rect2(), Vector2.ZERO) == Vector4.ZERO)
	pass


static func impossible_occlusion_crosses_anchor_test() -> void:
	var source := Rect2(80.0, 200.0, 120.0, 48.0)
	var anchor := Rect2(420.0, 180.0, 300.0, 120.0)
	var middle_offset: Vector2 = IMPOSSIBLE_ROOM_SCRIPT.occlusion_offset_px(source, anchor, 0.5, 1.0)
	var moved_center := source.get_center() + middle_offset
	assert(is_equal_approx(moved_center.x, anchor.get_center().x))
	assert(moved_center.y < anchor.get_center().y)
	assert(IMPOSSIBLE_ROOM_SCRIPT.occlusion_opacity(0.0) == 0.0)
	assert(IMPOSSIBLE_ROOM_SCRIPT.occlusion_opacity(0.5) > 0.99)
	assert(IMPOSSIBLE_ROOM_SCRIPT.occlusion_opacity(1.0) == 0.0)
	pass


func active_occlusion_cannot_be_restarted_test() -> void:
	var effect: Variant = IMPOSSIBLE_ROOM_SCRIPT.new()
	effect.size = Vector2(1000.0, 700.0)
	var anchor := Control.new()
	anchor.position = Vector2(420.0, 180.0)
	anchor.size = Vector2(300.0, 120.0)
	var occluder := Control.new()
	occluder.position = Vector2(80.0, 200.0)
	occluder.size = Vector2(120.0, 48.0)
	effect.add_child(anchor)
	effect.add_child(occluder)
	effect.anchor_control = anchor
	effect.occluder_control = occluder
	effect.kick(860.0, 1.0)
	assert(effect.occlusion_is_active())
	effect.occlusion_clock = 0.6
	var locked_source: Rect2 = effect.occlusion_source_rect
	var locked_target: Rect2 = effect.occlusion_anchor_rect
	effect.kick(1040.0, -1.0)
	assert(is_equal_approx(effect.occlusion_clock, 0.6))
	assert(effect.occlusion_source_rect == locked_source)
	assert(effect.occlusion_anchor_rect == locked_target)
	effect.free()
	pass


func inertia_controls_follow_at_different_rates_test() -> void:
	var effect: Variant = IMPOSSIBLE_ROOM_SCRIPT.new()
	effect.displacement_px = 100.0
	effect.step_inertia_controls(1.0 / 60.0)
	assert(effect.inertia_displacements[0] > effect.inertia_displacements[1])
	assert(effect.inertia_displacements[1] > effect.inertia_displacements[2])
	effect.free()
	pass


func spring_returns_toward_origin_test() -> void:
	var effect: Variant = IMPOSSIBLE_ROOM_SCRIPT.new()
	effect.displacement_px = 80.0
	effect.velocity_px = 0.0
	effect.step_motion(1.0 / 60.0)
	assert(effect.velocity_px < 0.0)
	assert(effect.displacement_px < 80.0)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = IMPOSSIBLE_ROOM_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.room_material != null)
	assert(effect.room_material.shader != null)
	effect.queue_free()
	await scene_tree.process_frame
	pass
