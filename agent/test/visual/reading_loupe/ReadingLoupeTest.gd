const READING_LOUPE_SCRIPT := preload("res://agent/ui/visuals/reading_loupe/ReadingLoupe.gd")


static func visual_type_is_registered_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.READING_LOUPE)
	assert(effect != null)
	assert(effect.get_script() == READING_LOUPE_SCRIPT)
	effect.free()
	pass


static func visual_script_instantiates_test() -> void:
	var effect: Variant = READING_LOUPE_SCRIPT.new()
	assert(effect.get_script() == READING_LOUPE_SCRIPT)
	effect.free()
	pass


static func rest_sample_is_the_original_pixel_test() -> void:
	var uv := Vector2(0.31, 0.74)
	assert(READING_LOUPE_SCRIPT.sample_uv(uv, Vector2(0.8, 0.2), Vector2.ZERO, 1.0).is_equal_approx(uv))
	assert(READING_LOUPE_SCRIPT.view_center_uv(Vector2(0.9, 0.1), Vector2.ZERO, 1.0).is_equal_approx(Vector2(0.5, 0.5)))
	pass


static func zoom_grows_only_with_approach_test() -> void:
	assert(is_equal_approx(READING_LOUPE_SCRIPT.zoom_for_approach(0.0, 1.8), 1.0))
	assert(READING_LOUPE_SCRIPT.zoom_for_approach(0.4, 1.8) > 1.0)
	assert(READING_LOUPE_SCRIPT.zoom_for_approach(0.8, 1.8) > READING_LOUPE_SCRIPT.zoom_for_approach(0.4, 1.8))
	assert(is_equal_approx(READING_LOUPE_SCRIPT.zoom_for_approach(1.0, 1.8), 1.8))
	assert(is_equal_approx(READING_LOUPE_SCRIPT.zoom_for_approach(1.0, 8.0), READING_LOUPE_SCRIPT.MAX_ZOOM))
	pass


static func energy_composition_never_overflows_test() -> void:
	assert(is_equal_approx(READING_LOUPE_SCRIPT.combine_energy(0.0, 0.4), 0.4))
	assert(READING_LOUPE_SCRIPT.combine_energy(0.6, 0.5) > 0.6)
	assert(READING_LOUPE_SCRIPT.combine_energy(0.6, 0.5) < 1.0)
	assert(READING_LOUPE_SCRIPT.combine_energy(1.0, 1.0) == 1.0)
	pass


static func streamed_chunks_keep_approach_restrained_test() -> void:
	assert(is_equal_approx(READING_LOUPE_SCRIPT.stream_energy_for_length(1), 0.003))
	assert(is_equal_approx(READING_LOUPE_SCRIPT.stream_energy_for_length(1000), 0.040))
	pass


static func fit_zoom_fills_the_short_bubble_on_screen_test() -> void:
	var bubble := Rect2(200.0, 500.0, 800.0, 180.0)
	var viewport := Vector2(1600.0, 900.0)
	var zoom: float = READING_LOUPE_SCRIPT.fit_zoom_for_rect(bubble, viewport)
	assert(is_equal_approx(zoom, READING_LOUPE_SCRIPT.MAX_ZOOM))
	assert(zoom > READING_LOUPE_SCRIPT.MIN_FRAME_ZOOM)
	pass


static func fit_zoom_keeps_a_visible_punch_on_large_bubbles_test() -> void:
	var zoom: float = READING_LOUPE_SCRIPT.fit_zoom_for_rect(Rect2(80.0, 40.0, 1400.0, 800.0), Vector2(1600.0, 900.0))
	assert(is_equal_approx(zoom, READING_LOUPE_SCRIPT.MIN_FRAME_ZOOM))
	pass


static func fit_zoom_never_exceeds_the_cap_test() -> void:
	var zoom: float = READING_LOUPE_SCRIPT.fit_zoom_for_rect(Rect2(10.0, 10.0, 40.0, 20.0), Vector2(1600.0, 900.0))
	assert(is_equal_approx(zoom, READING_LOUPE_SCRIPT.MAX_ZOOM))
	pass


static func scan_ping_pongs_left_then_right_test() -> void:
	var forward: Vector2 = READING_LOUPE_SCRIPT.scan_step(0.0, 1.0, 0.5, 1.0)
	assert(is_equal_approx(forward.x, 0.5))
	assert(is_equal_approx(forward.y, 1.0))
	var hit_right: Vector2 = READING_LOUPE_SCRIPT.scan_step(0.9, 1.0, 0.5, 1.0)
	assert(is_equal_approx(hit_right.x, 1.0))
	assert(is_equal_approx(hit_right.y, -1.0))
	var backward: Vector2 = READING_LOUPE_SCRIPT.scan_step(1.0, -1.0, 0.5, 1.0)
	assert(is_equal_approx(backward.x, 0.5))
	assert(is_equal_approx(backward.y, -1.0))
	var hit_left: Vector2 = READING_LOUPE_SCRIPT.scan_step(0.1, -1.0, 0.5, 1.0)
	assert(is_equal_approx(hit_left.x, 0.0))
	assert(is_equal_approx(hit_left.y, 1.0))
	pass


static func scan_resets_only_for_a_new_entry_test() -> void:
	assert(READING_LOUPE_SCRIPT.scan_should_reset(0, 12))
	assert(READING_LOUPE_SCRIPT.scan_should_reset(12, 34))
	assert(not READING_LOUPE_SCRIPT.scan_should_reset(12, 12))
	assert(not READING_LOUPE_SCRIPT.scan_should_reset(12, 0))
	pass


static func scan_focus_travels_across_the_bubble_test() -> void:
	var bubble := Rect2(200.0, 400.0, 800.0, 200.0)
	var viewport := Vector2(1600.0, 900.0)
	var left: Vector2 = READING_LOUPE_SCRIPT.scan_focus_uv(bubble, viewport, 3.0, 0.0)
	var right: Vector2 = READING_LOUPE_SCRIPT.scan_focus_uv(bubble, viewport, 3.0, 1.0)
	assert(left.x < right.x)
	assert(is_equal_approx(left.y, right.y))
	assert(left.x > bubble.position.x / viewport.x)
	assert(right.x < bubble.end.x / viewport.x)
	pass


static func focus_moves_at_constant_speed_test() -> void:
	var start := Vector2(0.20, 0.30)
	var target := Vector2(0.80, 0.70)
	var first: Vector2 = READING_LOUPE_SCRIPT.step_focus(start, target, 0.25)
	var second: Vector2 = READING_LOUPE_SCRIPT.step_focus(first, target, 0.25)
	var expected := READING_LOUPE_SCRIPT.FOCUS_SPEED * 0.25
	assert(is_equal_approx(start.distance_to(first), expected))
	assert(is_equal_approx(first.distance_to(second), expected))
	pass


static func focus_speed_does_not_depend_on_distance_test() -> void:
	var start := Vector2(0.20, 0.40)
	var far := Vector2(0.90, 0.80)
	var near := start + (far - start).normalized() * 0.05
	var far_step: Vector2 = READING_LOUPE_SCRIPT.step_focus(start, far, 0.10)
	var near_step: Vector2 = READING_LOUPE_SCRIPT.step_focus(start, near, 0.10)
	assert(is_equal_approx(start.distance_to(far_step), start.distance_to(near_step)))
	assert(is_equal_approx(start.distance_to(far_step), READING_LOUPE_SCRIPT.FOCUS_SPEED * 0.10))
	pass


static func focus_holds_scan_until_the_lens_arrives_test() -> void:
	assert(READING_LOUPE_SCRIPT.focus_is_traveling(Vector2(0.2, 0.2), Vector2(0.8, 0.7)))
	assert(not READING_LOUPE_SCRIPT.focus_is_traveling(Vector2(0.5, 0.5), Vector2(0.501, 0.500)))
	pass


func retarget_holds_scan_until_the_lens_arrives_test() -> void:
	var effect: Variant = READING_LOUPE_SCRIPT.new()
	effect.retargeting = true
	effect.scan_t = 0.0
	effect.scan_direction = 1.0
	effect.focus_uv = Vector2(0.10, 0.20)
	effect.target_focus_uv = Vector2(0.80, 0.70)
	var start := effect.focus_uv as Vector2
	for _index in range(12):
		effect.step_shot(1.0 / 60.0)
	assert(effect.retargeting)
	assert(is_equal_approx(effect.scan_t, 0.0))
	assert(is_equal_approx(start.distance_to(effect.focus_uv), READING_LOUPE_SCRIPT.FOCUS_SPEED * 12.0 / 60.0))
	effect.free()
	pass


func approach_never_retreats_during_the_shot_test() -> void:
	var effect: Variant = READING_LOUPE_SCRIPT.new()
	effect.add_approach(0.35)
	effect.step_shot(1.0 / 60.0)
	var after_first: float = effect.approach
	assert(after_first > 0.0)
	effect.reasoning_rate = 0.0
	for _index in range(12):
		effect.step_shot(1.0 / 60.0)
		assert(effect.approach + 0.00001 >= after_first)
		after_first = effect.approach
	effect.free()
	pass


func reasoning_advances_faster_than_silence_test() -> void:
	var quiet: Variant = READING_LOUPE_SCRIPT.new()
	var thinking: Variant = READING_LOUPE_SCRIPT.new()
	thinking.reasoning_rate = 1.0
	for _index in range(24):
		quiet.step_shot(1.0 / 60.0)
		thinking.step_shot(1.0 / 60.0)
	assert(thinking.approach > quiet.approach)
	quiet.free()
	thinking.free()
	pass


func scan_reverses_after_reaching_the_right_edge_test() -> void:
	var effect: Variant = READING_LOUPE_SCRIPT.new()
	effect.scan_t = 0.98
	effect.scan_direction = 1.0
	effect.step_scan(0.2)
	assert(is_equal_approx(effect.scan_t, 1.0))
	assert(is_equal_approx(effect.scan_direction, -1.0))
	effect.free()
	pass


func pullback_is_the_only_way_out_test() -> void:
	var effect: Variant = READING_LOUPE_SCRIPT.new()
	effect.approach = 0.72
	effect.target_approach = 0.72
	effect.begin_pullback()
	assert(effect.releasing)
	for _index in range(120):
		effect.step_shot(1.0 / 60.0)
	assert(effect.approach < 0.05)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = READING_LOUPE_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.loupe_material != null)
	assert(effect.loupe_material.shader != null)
	effect.queue_free()
	await scene_tree.process_frame
	pass
