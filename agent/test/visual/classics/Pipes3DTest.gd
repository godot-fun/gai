extends RefCounted


func pipes_grow_without_crossing_test() -> void:
	var effect := Pipes3D.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.rng.seed = 7
	effect.on_agent_start(1)
	assert(effect.main_pipe != null and effect.main_pipe.alive)
	for _index in range(200):
		effect.step_pipes(1.0 / 30.0)
	assert(effect.segment_count > 0)
	var occupied := 0
	for value: int in effect.occupied:
		occupied += value
	var cells := {}
	for index in range(effect.item_kinds.size()):
		if effect.item_kinds[index] == Pipes3D.Item.SEGMENT:
			cells[effect.item_to[index]] = true
	assert(cells.size() == effect.segment_count)
	assert(occupied >= effect.segment_count)
	effect.free()
	pass


func pipes_draw_list_stays_far_to_near_test() -> void:
	var effect := Pipes3D.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	for _index in range(120):
		effect.step_pipes(1.0 / 30.0)
	for index in range(1, effect.item_sort_keys.size()):
		assert(effect.item_sort_keys[index - 1] <= effect.item_sort_keys[index])
	effect.free()
	pass


func pipes_tool_lays_its_own_pipe_and_caps_it_test() -> void:
	var effect := Pipes3D.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	var pipe := effect.find_pipe("t1")
	assert(pipe != null)
	assert(pipe.color == Pipes3D.tool_color("grep"))
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.find_pipe("t1") == null)
	assert(not pipe.alive)
	assert(effect.item_colors.has(Colors.error))
	assert(effect.bursts.size() == 1 and effect.bursts[0].w == 1.0)
	effect.free()
	pass


func pipes_turn_changes_main_pipe_color_test() -> void:
	var effect := Pipes3D.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	var first := effect.main_pipe
	effect.on_turn_start(1)
	assert(effect.main_pipe != first)
	assert(not first.alive)
	assert(effect.main_pipe.color != first.color)
	effect.free()
	pass


func pipes_full_screen_clears_and_restarts_test() -> void:
	var effect := Pipes3D.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.segment_count = Pipes3D.MAX_SEGMENTS
	effect.step_pipes(1.0 / 60.0)
	assert(effect.clear_fade == 1.0)
	for _index in range(int(Pipes3D.CLEAR_SECONDS * 60.0) + 2):
		effect.step_pipes(1.0 / 60.0)
	assert(effect.clear_fade == 0.0)
	assert(effect.segment_count < Pipes3D.MAX_SEGMENTS)
	effect.free()
	pass
