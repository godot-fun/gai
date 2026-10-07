extends RefCounted


static func visual_type_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.DESKTOP_CAT))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.DESKTOP_CAT)
	assert(effect != null)
	assert(effect.get_visual_type() == VisualType.Type.DESKTOP_CAT)
	effect.free()
	control.free()
	pass


func lifecycle_state_test() -> void:
	var cat := DesktopCat.new()
	cat.on_agent_start(7)
	assert(cat.state == DesktopCat.CatState.THINKING)
	cat.on_turn_end()
	assert(cat.state == DesktopCat.CatState.IDLE)
	cat.on_agent_end("")
	assert(cat.state == DesktopCat.CatState.SUCCESS)
	cat.reset_visual()
	assert(cat.state == DesktopCat.CatState.IDLE)
	cat.free()
	pass


func tool_state_test() -> void:
	var cat := DesktopCat.new()
	cat.visible = true
	cat.on_tool_execution_start("read-1", "read_file", {})
	assert(cat.state == DesktopCat.CatState.TOOL_START)
	assert(cat.active_tools.has("read-1"))
	cat._process(DesktopCat.TOOL_REACH_MIN_SECONDS + 0.01)
	assert(cat.state == DesktopCat.CatState.TOOL_WAITING)
	cat.on_tool_execution_end("read-1", "read_file", AgentToolResult.ok("done"))
	assert(cat.state == DesktopCat.CatState.TOOL_SUCCESS)
	cat._process(DesktopCat.REACTION_SECONDS + 0.01)
	assert(cat.state == DesktopCat.CatState.IDLE)
	assert(cat.active_tools.is_empty())
	cat.free()
	pass


func concurrent_tool_returns_to_active_name_test() -> void:
	var cat := DesktopCat.new()
	cat.visible = true
	cat.on_tool_execution_start("read-1", "read_file", {})
	cat.on_tool_execution_start("write-1", "write_file", {})
	cat.on_tool_execution_end("write-1", "write_file", AgentToolResult.ok("done"))
	cat._process(DesktopCat.TOOL_REACH_MIN_SECONDS + 0.01)
	assert(cat.active_tool_name == "write_file")
	assert(cat.state == DesktopCat.CatState.TOOL_START)
	cat._process(DesktopCat.TOOL_REACH_MIN_SECONDS + 0.01)
	assert(cat.state == DesktopCat.CatState.TOOL_SUCCESS)
	cat._process(DesktopCat.REACTION_SECONDS + 0.01)
	assert(cat.active_tool_name == "read_file")
	assert(cat.state == DesktopCat.CatState.TOOL_WAITING)
	cat.free()
	pass


func failure_and_cancel_state_test() -> void:
	var cat := DesktopCat.new()
	cat.on_tool_execution_start("bad", "write_file", {})
	cat.on_tool_execution_end("bad", "write_file", AgentToolResult.error("denied"))
	assert(cat.state == DesktopCat.CatState.TOOL_START)
	cat.on_agent_end("network failed")
	assert(cat.state == DesktopCat.CatState.FAILED)
	cat.on_agent_end("Stop.")
	assert(cat.state == DesktopCat.CatState.CANCELLED)
	cat.free()
	pass


func final_state_skips_unfinished_tool_animations_test() -> void:
	var cat := DesktopCat.new()
	cat.on_tool_execution_start("read", "read_file", {})
	cat.on_tool_execution_end("read", "read_file", AgentToolResult.ok("done"))
	cat.on_tool_execution_start("write", "write_file", {})
	assert(not cat.animation_queue.is_empty())
	cat.on_agent_end("")
	assert(cat.state == DesktopCat.CatState.SUCCESS)
	assert(cat.animation_queue.is_empty())
	assert(not cat.animation_event_active)
	cat.free()
	pass


static func tail_swing_reaches_both_sides_test() -> void:
	assert(is_zero_approx(DesktopCat.tail_swing_amount(0.0)))
	assert(is_equal_approx(DesktopCat.tail_swing_amount(PI), 1.0))
	pass


static func whiskers_move_out_of_phase_test() -> void:
	var left_whisker := DesktopCat.whisker_wave(0.5, -0.13)
	var right_whisker := DesktopCat.whisker_wave(0.5, 1.27)
	assert(not is_equal_approx(left_whisker, right_whisker))
	assert(not is_equal_approx(left_whisker, DesktopCat.whisker_wave(0.8, -0.13)))
	pass


func reset_visual_clears_animation_state_test() -> void:
	var cat := DesktopCat.new()
	cat.elapsed = 8.0
	cat.state_seconds = 4.0
	cat.tail_offset = 6.0
	cat.tail_velocity = 3.0
	cat.tail_swing_phase = 2.0
	cat.tail_bob_phase = 4.0
	cat.whisker_phase = 5.0
	cat.reset_visual()
	assert(cat.elapsed == 0.0)
	assert(cat.state_seconds == 0.0)
	assert(cat.tail_offset == 0.0)
	assert(cat.tail_velocity == 0.0)
	assert(cat.tail_swing_phase == 0.0)
	assert(cat.tail_bob_phase == 0.0)
	assert(cat.whisker_phase == 0.0)
	cat.free()
	pass


static func idle_blink_includes_occasional_double_blink_test() -> void:
	assert(DesktopCat.blink_closed(9.7, true))
	assert(DesktopCat.blink_closed(10.05, true))
	assert(not DesktopCat.blink_closed(10.05, false))
	pass


static func mouth_morphs_from_angle_to_smile_test() -> void:
	var unhappy := DesktopCat.mouth_points(Vector2.ZERO, 0.0)
	var happy := DesktopCat.mouth_points(Vector2.ZERO, 1.0)
	assert(unhappy.size() == 13)
	assert(happy.size() == 13)
	assert(unhappy[6].y < unhappy[0].y)
	assert(happy[6].y > happy[0].y)
	assert(happy[6].y - happy[0].y >= 6.0)
	pass


static func reach_particles_fade_at_both_ends_test() -> void:
	assert(is_zero_approx(DesktopCat.reach_particle_alpha(1.0, 0.0)))
	assert(is_equal_approx(DesktopCat.reach_particle_alpha(1.0, 0.5), 1.0))
	assert(is_zero_approx(DesktopCat.reach_particle_alpha(1.0, 1.0)))
	assert(is_equal_approx(DesktopCat.reach_particle_alpha(0.25, 0.5), 0.25))
	pass


static func reach_particles_start_after_half_of_reach_test() -> void:
	assert(is_zero_approx(DesktopCat.reach_particle_amount(0.0)))
	assert(is_zero_approx(DesktopCat.reach_particle_amount(DesktopCat.REACH_PARTICLE_DELAY_PROGRESS)))
	assert(is_equal_approx(DesktopCat.reach_particle_amount(0.75), 0.5))
	assert(is_equal_approx(DesktopCat.reach_particle_amount(1.0), 1.0))
	pass
