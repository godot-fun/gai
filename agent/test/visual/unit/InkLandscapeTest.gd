func visual_type_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.INK_LANDSCAPE))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.INK_LANDSCAPE)
	assert(effect is InkLandscape)
	assert(effect.get_visual_type() == VisualType.Type.INK_LANDSCAPE)
	effect.free()
	control.free()
	pass


func ink_landscape_uses_slow_fade_out_test() -> void:
	var effect := InkLandscape.new()
	assert(effect.fade_out_seconds() > 0.0)
	effect.set_landscape_alpha(0.42)
	assert(is_equal_approx(effect.exit_alpha, 0.42))
	effect.free()
	pass


func reasoning_builds_mountain_test() -> void:
	var effect := InkLandscape.new()
	effect.on_message_update("Study the context, then compare the paths.", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.cloud_count == 1)
	assert(effect.mountains.is_empty())
	assert(effect.reasoning_ink > 0.0)
	effect.free()
	pass


func tool_bird_tracks_result_test() -> void:
	var effect := InkLandscape.new()
	var args: Dictionary[String, Variant] = {"path": "res://project.godot"}
	effect.on_tool_execution_start("tool-1", ReadTool.NAME, args)
	assert(effect.birds.size() == 1)
	assert(effect.active_birds.has("tool-1"))
	assert(int(effect.birds[0]["phase"]) == InkLandscape.BirdPhase.ENTERING)
	assert(int(effect.birds[0]["result"]) == InkLandscape.BirdResult.ACTIVE)
	effect.on_tool_execution_end("tool-1", ReadTool.NAME, AgentToolResult.ok("done"))
	assert(not effect.active_birds.has("tool-1"))
	assert(int(effect.birds[0]["result"]) == InkLandscape.BirdResult.SUCCESS)
	effect.free()
	pass


func repeated_tools_retire_old_birds_without_abrupt_removal_test() -> void:
	var effect := InkLandscape.new()
	effect.visible = true
	var args: Dictionary[String, Variant] = {}
	for index in range(24):
		effect.on_tool_execution_start("tool-%d" % index, ReadTool.NAME, args)
		effect._process(0.5)
	assert(effect.birds.size() >= InkLandscape.MAX_BIRDS)
	assert(effect.bird_serial == 24)
	var positions: Dictionary[Vector2, bool] = {}
	for bird: Dictionary in effect.birds:
		var position := InkLandscape.bird_position(int(bird["serial"]), float(bird["seed"]))
		positions[position] = true
	assert(positions.size() == effect.birds.size())
	assert(effect.birds.any(func(bird: Dictionary) -> bool: return int(bird["result"]) != InkLandscape.BirdResult.ACTIVE))
	effect.free()
	pass


func capacity_retirement_waits_for_entering_bird_test() -> void:
	var effect := InkLandscape.new()
	effect.visible = true
	var args: Dictionary[String, Variant] = {}
	for index in range(InkLandscape.MAX_BIRDS + 1):
		effect.on_tool_execution_start("capacity-%d" % index, ReadTool.NAME, args)
	var retiring_bird: Dictionary = effect.birds[0]
	assert(int(retiring_bird["result"]) == InkLandscape.BirdResult.SUCCESS)
	assert(int(retiring_bird["phase"]) == InkLandscape.BirdPhase.ENTERING)
	assert(float(retiring_bird["entry"]) < 1.0)
	effect._process(1.0)
	assert(float(retiring_bird["departure"]) == 0.0)
	effect.free()
	pass


func tool_birds_enter_from_both_screen_edges_test() -> void:
	var effect := InkLandscape.new()
	var args: Dictionary[String, Variant] = {}
	effect.on_tool_execution_start("top-bird", ReadTool.NAME, args)
	var target := InkLandscape.bird_exit_position(1, float(effect.birds[0]["seed"]))
	var spawn := InkLandscape.bird_spawn_position(target.x, 1)
	assert(spawn.y < 0.0)
	assert(target.y > 0.0 and target.y < 1.0)
	assert(spawn.x > target.x)
	effect.on_tool_execution_start("bottom-bird", ReadTool.NAME, args)
	var second_target := InkLandscape.bird_exit_position(2, float(effect.birds[1]["seed"]))
	var second_spawn := InkLandscape.bird_spawn_position(second_target.x, 2)
	assert(second_spawn.y > 1.0)
	assert(second_spawn.x < second_target.x)
	effect.visible = true
	effect._process(0.5)
	assert(float(effect.birds[0]["entry"]) > 0.0 and float(effect.birds[0]["entry"]) < 1.0)
	effect.free()
	pass


func descending_birds_stay_in_distant_sky_test() -> void:
	for serial in range(1, 12, 2):
		var target := InkLandscape.bird_exit_position(serial, 0.5)
		var spawn := InkLandscape.bird_spawn_position(target.x, serial)
		assert(InkLandscape.bird_flies_down(serial))
		assert(spawn.y < target.y)
		assert(target.y >= 0.08 and target.y <= 0.34)
		var normal_perspective := InkLandscape.bird_perspective(target.y)
		var distant_perspective := InkLandscape.bird_perspective(target.y, true)
		assert(distant_perspective.x < normal_perspective.x)
		assert(distant_perspective.y < normal_perspective.y)
	pass


func tool_bird_crosses_and_exits_screen_test() -> void:
	var effect := InkLandscape.new()
	var args: Dictionary[String, Variant] = {}
	effect.on_tool_execution_start("cross-screen", ReadTool.NAME, args)
	var bird: Dictionary = effect.birds[0]
	var target := InkLandscape.bird_exit_position(int(bird["serial"]), float(bird["seed"]))
	var spawn := InkLandscape.bird_spawn_position(target.x, int(bird["serial"]))
	var control := InkLandscape.bird_entry_control(spawn, target, int(bird["serial"]), float(bird["seed"]))
	var middle := InkLandscape.bird_entry_position(spawn, control, target, 0.5)
	var finish := InkLandscape.bird_entry_position(spawn, control, target, 1.0)
	assert(spawn.y < 0.0)
	assert(middle.y < finish.y)
	assert(finish.y > 0.0 and finish.y < 1.0)
	assert(middle.x < spawn.x and middle.x > finish.x)
	effect.free()
	pass


func bird_entry_uses_constant_speed_test() -> void:
	var spawn := Vector2(0.72, 1.08)
	var target := Vector2(0.72, 0.4)
	var control := Vector2(0.84, 0.72)
	var first := InkLandscape.bird_entry_position(spawn, control, target, 0.25)
	var second := InkLandscape.bird_entry_position(spawn, control, target, 0.5)
	var third := InkLandscape.bird_entry_position(spawn, control, target, 0.75)
	var first_distance := spawn.distance_to(first)
	var second_distance := first.distance_to(second)
	var third_distance := second.distance_to(third)
	assert(absf(first_distance - second_distance) < 0.015)
	assert(absf(second_distance - third_distance) < 0.015)
	assert(not is_equal_approx(first.x, target.x))
	pass


func cached_bird_path_matches_entry_position_test() -> void:
	var spawn := Vector2(0.74, -0.08)
	var control := Vector2(0.61, 0.18)
	var target := Vector2(0.52, 0.36)
	var points := InkLandscape.bird_entry_path(spawn, control, target)
	var lengths := InkLandscape.bird_path_lengths(points)
	assert(points.size() == 25)
	assert(lengths.size() == points.size())
	for progress in [0.0, 0.2, 0.5, 0.8, 1.0]:
		var cached := InkLandscape.bird_path_position(points, lengths, lengths[-1], progress)
		var direct := InkLandscape.bird_entry_position(spawn, control, target, progress)
		assert(cached.is_equal_approx(direct))
	pass


func bird_entry_never_reverses_horizontal_direction_test() -> void:
	for serial in range(1, 7):
		var target := InkLandscape.bird_position(serial, 0.5)
		var spawn := InkLandscape.bird_spawn_position(target.x, serial)
		var control := InkLandscape.bird_entry_control(spawn, target, serial, 0.5)
		var previous := spawn
		var direction := signf(target.x - spawn.x)
		for index in range(1, 25):
			var current := InkLandscape.bird_entry_position(spawn, control, target, float(index) / 24.0)
			assert((current.x - previous.x) * direction >= -0.0001)
			previous = current
	pass


func bird_wing_is_sampled_as_smooth_curve_test() -> void:
	var center := Vector2(100.0, 80.0)
	var wing := InkLandscape.bird_wing_curve(center, 32.0, 12.0, -1.0, 1.0)
	assert(wing.size() == 13)
	assert(wing[0].is_equal_approx(center))
	assert(wing[-1].is_equal_approx(center + Vector2(-32.0, -4.8)))
	for index in range(1, wing.size()):
		assert(wing[index].distance_to(wing[index - 1]) < 5.0)
	pass


func bird_downstroke_bows_above_its_straight_chord_test() -> void:
	var center := Vector2(100.0, 80.0)
	var wing := InkLandscape.bird_wing_curve(center, 32.0, -12.0, 1.0, 1.0)
	assert(wing[-1].y > center.y)
	var straight_middle := center.lerp(wing[-1], 0.5)
	assert(wing[6].y < straight_middle.y - 1.0)
	assert(wing[-1].y > wing[-2].y)
	pass


func bird_speed_varies_smoothly_with_wing_stroke_test() -> void:
	var slow := InkLandscape.bird_flight_speed(0.0)
	var cruise := InkLandscape.bird_flight_speed(PI * 0.5)
	var fast := InkLandscape.bird_flight_speed(PI)
	assert(slow < cruise)
	assert(cruise < fast)
	assert(slow >= 0.50 and fast <= 1.50)
	pass


func departing_bird_shrinks_to_nothing_test() -> void:
	var full_size := InkLandscape.bird_departure_scale(0.0)
	var middle_size := InkLandscape.bird_departure_scale(0.5)
	var final_size := InkLandscape.bird_departure_scale(1.0)
	assert(is_equal_approx(full_size, 1.0))
	assert(middle_size > 0.0 and middle_size < full_size)
	assert(is_zero_approx(final_size))
	pass


func bird_departure_continues_entry_direction_test() -> void:
	for serial in range(1, 7):
		var target := InkLandscape.bird_exit_position(serial, 0.5)
		var spawn := InkLandscape.bird_spawn_position(target.x, serial)
		var control := InkLandscape.bird_entry_control(spawn, target, serial, 0.5)
		var entry_direction := (target - control).normalized()
		for falls in [false, true]:
			var first_offset := InkLandscape.bird_departure_offset(entry_direction, 0.001, falls)
			assert(first_offset.normalized().dot(entry_direction) > 0.999)
			assert(signf(first_offset.x) == signf(target.x - spawn.x))
	pass


func failed_bird_sags_without_reversing_departure_test() -> void:
	var control := Vector2(0.4, 0.7)
	var target := Vector2(0.6, 0.4)
	var tangent := (target - control).normalized()
	var success := InkLandscape.bird_departure_offset(tangent, 1.0, false)
	var failure := InkLandscape.bird_departure_offset(tangent, 1.0, true)
	assert(is_equal_approx(failure.x, success.x))
	assert(failure.y > success.y)
	assert(failure.x > 0.0)
	pass


func bird_downstroke_shortens_visible_wing_span_test() -> void:
	var raised := InkLandscape.bird_wing_span_scale(1.0)
	var level := InkLandscape.bird_wing_span_scale(0.0)
	var partial_downstroke := InkLandscape.bird_wing_span_scale(-0.5)
	var full_downstroke := InkLandscape.bird_wing_span_scale(-1.0)
	assert(is_equal_approx(raised, 1.0))
	assert(is_equal_approx(level, 1.0))
	assert(partial_downstroke < level and partial_downstroke > full_downstroke)
	assert(is_equal_approx(full_downstroke, 0.78))
	pass


func gliding_bird_finishes_flap_cycle_before_locking_test() -> void:
	var effect := InkLandscape.new()
	effect.visible = true
	effect.on_tool_execution_start("glide-anchor", ReadTool.NAME, {})
	var bird: Dictionary = effect.birds[0]
	bird["entry"] = 1.0
	effect.on_tool_execution_end("glide-anchor", ReadTool.NAME, AgentToolResult.ok("done"))
	var phase_before := float(bird["wing"])
	effect._process(0.01)
	assert(int(bird["phase"]) == InkLandscape.BirdPhase.FINISHING)
	assert(float(bird["wing"]) > phase_before)
	assert(float(bird["departure"]) == 0.0)
	for _frame in range(180):
		effect._process(1.0 / 60.0)
		if int(bird["phase"]) == InkLandscape.BirdPhase.DEPARTING:
			break
	assert(int(bird["phase"]) == InkLandscape.BirdPhase.DEPARTING)
	var locked_phase := float(bird["wing"])
	assert(is_equal_approx(sin(locked_phase), 3.0 / 11.0))
	effect._process(0.1)
	assert(is_equal_approx(float(bird["wing"]), locked_phase))
	assert(float(bird["departure"]) > 0.0)
	effect.free()
	pass


func bird_perspective_shrinks_and_fades_with_height_test() -> void:
	var far := InkLandscape.bird_perspective(-0.08)
	var upper := InkLandscape.bird_perspective(0.25)
	var near := InkLandscape.bird_perspective(1.0)
	assert(far.x < upper.x)
	assert(upper.x < near.x)
	assert(far.x < near.x)
	assert(far.y < near.y)
	assert(far.x < 0.06)
	assert(is_zero_approx(far.y))
	assert(is_equal_approx(near.x, 1.18))
	pass


func completed_tool_keeps_flapping_until_entry_finishes_test() -> void:
	var effect := InkLandscape.new()
	var args: Dictionary[String, Variant] = {}
	effect.on_tool_execution_start("fast-tool", ReadTool.NAME, args)
	effect.on_tool_execution_end("fast-tool", ReadTool.NAME, AgentToolResult.ok("done"))
	var initial_wing := float(effect.birds[0]["wing"])
	effect.visible = true
	effect._process(1.0)
	assert(float(effect.birds[0]["entry"]) < 1.0)
	assert(float(effect.birds[0]["wing"]) > initial_wing + 6.9)
	assert(float(effect.birds[0]["departure"]) == 0.0)
	for _frame in range(600):
		effect._process(1.0 / 60.0)
	assert(float(effect.birds[0]["entry"]) == 1.0)
	effect._process(0.5)
	assert(float(effect.birds[0]["departure"]) > 0.0)
	effect.free()
	pass


func completed_tool_bird_departs_after_glide_test() -> void:
	var effect := InkLandscape.new()
	effect.on_tool_execution_start("departing-tool", ReadTool.NAME, {})
	effect.birds[0]["entry"] = 1.0
	effect.on_tool_execution_end("departing-tool", ReadTool.NAME, AgentToolResult.ok("done"))
	effect.visible = true
	effect._process(6.0)
	assert(effect.birds.is_empty())
	effect.free()
	pass


func mountain_count_is_capped_test() -> void:
	var effect := InkLandscape.new()
	for _index in range(96):
		effect.on_turn_start()
	assert(effect.mountains.size() == InkLandscape.MAX_MOUNTAINS)
	assert(effect.cloud_count == InkLandscape.MAX_CLOUDS)
	assert(effect.turn_serial == 96)
	effect.free()
	pass


func perspective_strictly_controls_size_test() -> void:
	var distant := InkLandscape.mountain_dimensions(0.05)
	var middle := InkLandscape.mountain_dimensions(0.5)
	var foreground := InkLandscape.mountain_dimensions(0.95)
	assert(distant.x < middle.x and middle.x < foreground.x)
	assert(distant.y < middle.y and middle.y < foreground.y)
	assert(distant.x >= 0.025 and foreground.x <= 0.12)
	assert(distant.y >= 0.10 and foreground.y <= 0.56)
	pass


func mountain_canvas_is_cropped_to_its_bounds_test() -> void:
	var mountain := {
		"center": 0.5,
		"width": 0.04,
		"base": 0.62,
		"height": 0.18,
	}
	var bounds := InkLandscape.mountain_bounds(mountain)
	assert(bounds.size.x < 1.0)
	assert(bounds.size.y < 1.0)
	assert(bounds.has_point(Vector2(0.5, 0.62)))
	pass


func first_three_mountains_span_screen_test() -> void:
	var first_width := InkLandscape.mountain_dimensions(InkLandscape.mountain_depth(1)).x
	var second_width := InkLandscape.mountain_dimensions(InkLandscape.mountain_depth(2)).x
	var third_width := InkLandscape.mountain_dimensions(InkLandscape.mountain_depth(3)).x
	var first := InkLandscape.mountain_center(1, first_width)
	var second := InkLandscape.mountain_center(2, second_width)
	var third := InkLandscape.mountain_center(3, third_width)
	assert(first < 0.3)
	assert(second > 0.4 and second < 0.6)
	assert(third > 0.7)
	assert(InkLandscape.mountain_depth(3) > InkLandscape.mountain_depth(1))
	assert(InkLandscape.mountain_depth(3) > InkLandscape.mountain_depth(2))
	pass


func one_mountain_is_added_per_turn_test() -> void:
	var effect := InkLandscape.new()
	effect.visible = true
	effect.on_turn_start()
	assert(effect.cloud_count == 1)
	assert(effect.mountains.is_empty())
	effect.on_turn_start()
	effect._process(0.25)
	assert(effect.mountains.size() == 1)
	var first_growth := float(effect.mountains[0]["growth"])
	assert(first_growth > 0.0 and first_growth < 1.0)
	effect.on_turn_end()
	assert(float(effect.mountains[0]["growth"]) == 1.0)
	effect.on_turn_start()
	assert(effect.cloud_count == 2)
	assert(effect.mountains.size() == 1)
	effect.on_turn_start()
	assert(effect.mountains.size() == 2)
	assert(float(effect.mountains[0]["growth"]) == 1.0)
	assert(float(effect.mountains[1]["growth"]) == 0.0)
	effect.free()
	pass


func cloud_appears_gradually_test() -> void:
	var effect := InkLandscape.new()
	effect.visible = true
	effect.on_turn_start()
	assert(effect.cloud_count == 1)
	assert(effect.cloud_reveal == 0.0)
	effect._process(0.5)
	assert(effect.cloud_reveal > 0.0 and effect.cloud_reveal < 1.0)
	effect._process(2.0)
	assert(effect.cloud_reveal == 1.0)
	effect.free()
	pass


func cloud_turn_does_not_settle_previous_mountain_test() -> void:
	var effect := InkLandscape.new()
	effect.on_turn_start()
	effect.on_turn_start()
	assert(effect.current_turn_has_mountain)
	effect.mountains[0]["growth"] = 0.42
	effect.on_turn_start()
	assert(not effect.current_turn_has_mountain)
	effect.on_turn_end()
	assert(is_equal_approx(float(effect.mountains[0]["growth"]), 0.42))
	effect.free()
	pass


func cloud_layers_are_vertically_cropped_test() -> void:
	for index in range(3):
		var bounds := InkLandscape.cloud_layer_bounds(index)
		assert(bounds.position.y >= 0.0)
		assert(bounds.end.y <= 1.0)
		assert(bounds.size.y < 1.0)
	pass


func render_smoke_test() -> void:
	var effect := InkLandscape.new()
	effect.size = Vector2(1280.0, 720.0)
	Engine.get_main_loop().root.add_child.call_deferred(effect)
	await Engine.get_main_loop().process_frame
	assert(effect.cloud_canvas != null)
	assert(effect.cloud_material != null)
	assert(effect.cloud_material.shader != null)
	assert(effect.cloud_canvases.size() == 3)
	assert(effect.cloud_canvases[0].z_index < effect.cloud_canvases[1].z_index)
	assert(effect.cloud_canvases[1].z_index < effect.cloud_canvases[2].z_index)
	effect.set_landscape_alpha(0.37)
	assert(is_equal_approx(float(effect.cloud_material.get_shader_parameter("fade_alpha")), 0.37))
	effect.visible = true
	effect.on_turn_start()
	effect.on_turn_start()
	effect.on_message_update("Consider the evidence, compare it, then answer.", OpenAiClient.STREAM_KIND_REASONING)
	effect.on_message_update("The answer follows from the evidence.", OpenAiClient.STREAM_KIND_CONTENT)
	var args: Dictionary[String, Variant] = {"path": "res://project.godot"}
	effect.on_tool_execution_start("render-tool", ReadTool.NAME, args)
	effect.on_tool_execution_end("render-tool", ReadTool.NAME, AgentToolResult.ok("done"))
	effect._process(0.3)
	await Engine.get_main_loop().process_frame
	assert(effect.z_index == 100)
	var mountain_canvas: ColorRect = effect.mountains[0]["canvas"]
	var mountain_material: ShaderMaterial = effect.mountains[0]["material"]
	var initial_strength := float(mountain_material.get_shader_parameter("strength"))
	assert(mountain_canvas.z_index < 0)
	assert(mountain_canvas.z_index < effect.cloud_canvas.z_index)
	assert(effect.cloud_canvases[0].z_index < mountain_canvas.z_index)
	effect.set_landscape_alpha(0.23)
	assert(is_equal_approx(float(mountain_material.get_shader_parameter("fade_alpha")), 0.23))
	for _index in range(12):
		effect.on_turn_start()
	assert(is_equal_approx(float(mountain_material.get_shader_parameter("strength")), initial_strength))
	effect.get_parent().remove_child(effect)
	effect.free()
	pass
