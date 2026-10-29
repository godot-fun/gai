extends RefCounted


func life_atlas_holds_every_pattern_test() -> void:
	var effect := GameOfLife.new()
	effect.build_pattern_atlas()
	var expected_population := {GameOfLife.Pattern.GLIDER: 5, GameOfLife.Pattern.LWSS: 9, GameOfLife.Pattern.ACORN: 7, GameOfLife.Pattern.R_PENTOMINO: 5, GameOfLife.Pattern.GOSPER_GUN: 36}
	var image := effect.pattern_atlas.get_image()
	for pattern: GameOfLife.Pattern in expected_population:
		assert(GameOfLife.pattern_population(pattern) == expected_population[pattern])
		var rect := effect.pattern_rects[pattern]
		var rows: Array = GameOfLife.PATTERN_ROWS[pattern]
		assert(int(rect.z) == str(rows[0]).length() and int(rect.w) == rows.size())
		var alive := 0
		for y in range(int(rect.w)):
			assert(str(rows[y]).length() == int(rect.z))
			for x in range(int(rect.z)):
				if image.get_pixel(int(rect.x) + x, int(rect.y) + y).r > 0.5:
					alive += 1
		assert(alive == expected_population[pattern])
	effect.free()
	pass


func life_stream_speeds_generations_test() -> void:
	var effect := GameOfLife.new()
	effect.on_agent_start(1)
	var idle := effect.current_generations_per_second()
	for _index in range(10):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.current_generations_per_second() > idle)
	var steps := 0
	for _index in range(60):
		effect.step_field(1.0 / 60.0)
		if effect.step_now:
			steps += 1
	assert(steps >= int(GameOfLife.IDLE_GENERATIONS_PER_SECOND) - 1)
	assert(steps <= 60)
	effect.free()
	pass


func life_content_sprinkles_soup_along_caret_test() -> void:
	var effect := GameOfLife.new()
	effect.on_agent_start(1)
	effect.impulse_shapes.clear()
	effect.impulse_vectors.clear()
	var start_caret := effect.caret
	for _index in range(20):
		effect.on_message_update(1, "answer chunk text", OpenAiClient.STREAM_KIND_CONTENT)
	effect.step_field(1.0 / 60.0)
	assert(effect.impulse_shapes.size() == GameOfLife.MAX_SPAWNS_PER_FRAME)
	assert(int(effect.impulse_vectors[0].x) == GameOfLife.Pattern.SOUP)
	assert(effect.caret != start_caret)
	effect.free()
	pass


func life_tools_seed_acorns_and_launch_spaceships_test() -> void:
	var effect := GameOfLife.new()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(int(effect.impulse_vectors[0].x) == GameOfLife.Pattern.ACORN)
	assert(Vector2(effect.impulse_shapes[0].x, effect.impulse_shapes[0].y).is_equal_approx(SimulationEffect.tool_anchor("grep")))
	assert(is_equal_approx(effect.impulse_vectors[0].z, GameOfLife.tool_tag("grep")))
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(int(effect.impulse_vectors[1].x) == GameOfLife.Pattern.LWSS)
	assert(int(effect.impulse_vectors[2].x) == GameOfLife.Pattern.LWSS)
	assert(effect.impulse_vectors[1].y != effect.impulse_vectors[2].y)
	effect.on_tool_execution_end(1, "t2", "shell", AgentToolResult.error("boom"))
	assert(effect.failure_tint == 1.0)
	assert(effect.impulse_vectors[3].z == GameOfLife.ERROR_TAG)
	effect.free()
	pass


func life_turns_plant_glider_guns_test() -> void:
	var effect := GameOfLife.new()
	effect.on_turn_start(1)
	effect.on_turn_start(1)
	assert(int(effect.impulse_vectors[0].x) == GameOfLife.Pattern.GOSPER_GUN)
	assert(not Vector2(effect.impulse_shapes[0].x, effect.impulse_shapes[0].y).is_equal_approx(Vector2(effect.impulse_shapes[1].x, effect.impulse_shapes[1].y)))
	effect.free()
	pass


static func life_tool_tags_stay_clear_of_content_and_error_test() -> void:
	for tool_name: String in ["grep", "read_file", "shell", "web_search", "write_file", "glob"]:
		var tag := GameOfLife.tool_tag(tool_name)
		assert(absf(tag - GameOfLife.CONTENT_TAG) > 0.07)
		assert(tag < 0.97 and tag > 0.0)
	pass
