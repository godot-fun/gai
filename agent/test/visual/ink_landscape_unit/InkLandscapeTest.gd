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
	assert(int(effect.birds[0]["state"]) == InkLandscape.BirdState.FLYING)
	effect.on_tool_execution_end("tool-1", ReadTool.NAME, AgentToolResult.ok("done"))
	assert(not effect.active_birds.has("tool-1"))
	assert(int(effect.birds[0]["state"]) == InkLandscape.BirdState.GLIDING)
	effect.free()
	pass


func repeated_tools_keep_unique_bird_positions_test() -> void:
	var effect := InkLandscape.new()
	var args: Dictionary[String, Variant] = {}
	for index in range(24):
		effect.on_tool_execution_start("tool-%d" % index, ReadTool.NAME, args)
	assert(effect.birds.size() == InkLandscape.MAX_BIRDS)
	assert(effect.bird_serial == 24)
	var positions: Dictionary[Vector2, bool] = {}
	for bird: Dictionary in effect.birds:
		var position := InkLandscape.bird_position(int(bird["serial"]), float(bird["seed"]))
		positions[position] = true
	assert(positions.size() == InkLandscape.MAX_BIRDS)
	effect.free()
	pass


func tool_birds_enter_from_below_screen_test() -> void:
	var effect := InkLandscape.new()
	var args: Dictionary[String, Variant] = {}
	effect.on_tool_execution_start("bottom-bird", ReadTool.NAME, args)
	var target := InkLandscape.bird_exit_position(1, float(effect.birds[0]["seed"]))
	var spawn := InkLandscape.bird_spawn_position(target.x)
	assert(spawn.y > 1.0)
	assert(target.y < 0.0)
	assert(is_equal_approx(spawn.x, target.x))
	effect.visible = true
	effect._process(0.5)
	assert(float(effect.birds[0]["entry"]) > 0.0 and float(effect.birds[0]["entry"]) < 1.0)
	effect.free()
	pass


func tool_bird_crosses_and_exits_screen_test() -> void:
	var effect := InkLandscape.new()
	var args: Dictionary[String, Variant] = {}
	effect.on_tool_execution_start("cross-screen", ReadTool.NAME, args)
	var bird: Dictionary = effect.birds[0]
	var target := InkLandscape.bird_exit_position(int(bird["serial"]), float(bird["seed"]))
	var spawn := InkLandscape.bird_spawn_position(target.x)
	var control := InkLandscape.bird_entry_control(spawn, target, int(bird["serial"]), float(bird["seed"]))
	var middle := InkLandscape.bird_entry_position(spawn, control, target, 0.5)
	var finish := InkLandscape.bird_entry_position(spawn, control, target, 1.0)
	assert(spawn.y > 1.0)
	assert(middle.y > 0.0 and middle.y < 1.0)
	assert(finish.y < 0.0)
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


func bird_speed_varies_smoothly_with_wing_stroke_test() -> void:
	var slow := InkLandscape.bird_flight_speed(0.0)
	var cruise := InkLandscape.bird_flight_speed(PI * 0.5)
	var fast := InkLandscape.bird_flight_speed(PI)
	assert(slow < cruise)
	assert(cruise < fast)
	assert(slow >= 0.50 and fast <= 1.50)
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
	assert(float(effect.birds[0]["flight"]) == 0.0)
	for _frame in range(600):
		effect._process(1.0 / 60.0)
	assert(float(effect.birds[0]["entry"]) == 1.0)
	effect._process(0.5)
	assert(float(effect.birds[0]["flight"]) > 0.0)
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
	assert(distant.y >= 0.07 and foreground.y <= 0.44)
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


func render_smoke_test() -> void:
	var effect := InkLandscape.new()
	effect.size = Vector2(1280.0, 720.0)
	Engine.get_main_loop().root.add_child.call_deferred(effect)
	await Engine.get_main_loop().process_frame
	assert(effect.ink_canvas != null)
	assert(effect.ink_material != null)
	assert(effect.ink_material.shader != null)
	assert(not effect.ink_canvas.visible)
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
	assert(mountain_canvas.z_index < 0)
	assert(mountain_canvas.z_index < effect.cloud_canvas.z_index)
	assert(effect.cloud_canvases[0].z_index < mountain_canvas.z_index)
	effect.set_landscape_alpha(0.23)
	assert(is_equal_approx(float(mountain_material.get_shader_parameter("fade_alpha")), 0.23))
	effect.get_parent().remove_child(effect)
	effect.free()
	pass
