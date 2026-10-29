extends RefCounted


static func falling_sand_has_translations_test() -> void:
	for locale_path: String in ["res://agent/config/locale/en.json", "res://agent/config/locale/zh.json"]:
		assert(FileAccess.get_file_as_string(locale_path).contains("\"visual_falling_sand\""))
	pass


static func sand_tool_tags_stay_clear_of_reserved_tags_test() -> void:
	for tool_name: String in ["grep", "read_file", "shell", "web_search", "write_file", "glob"]:
		var tag := FallingSand.tool_tag(tool_name)
		assert(absf(tag - FallingSand.CONTENT_TAG) > 0.07)
		assert(tag > 0.04 and tag < 0.96)
	pass


func sand_passes_alternate_block_offsets_test() -> void:
	var effect := FallingSand.new()
	var kinds := effect.pass_kinds()
	assert(kinds.size() % 2 == 0)
	for index in range(kinds.size()):
		assert(kinds[index] % 2 == index % 2)
	effect.free()
	pass


func answers_pour_from_a_sweeping_spout_test() -> void:
	var effect := new_sand()
	for _index in range(5):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	var start_x := effect.pour_x
	effect.step_field(1.0 / 60.0)
	assert(effect.impulse_shapes.size() == 1)
	assert(int(effect.impulse_vectors[0].x) == FallingSand.Stamp.POUR)
	assert(effect.impulse_vectors[0].y == FallingSand.CONTENT_TAG)
	assert(effect.pour_x > start_x)
	assert(effect.impulse_shapes[0].y > effect.ceiling_uv())
	for _index in range(2000):
		effect.advance_pour(1.0 / 60.0)
		assert(effect.pour_x >= FallingSand.POUR_MIN_X and effect.pour_x <= FallingSand.POUR_MAX_X)
	effect.free()
	pass


func falling_sand_covers_the_toolbar_test() -> void:
	var effect := new_sand()
	assert(is_zero_approx(effect.ceiling_uv()))
	effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	effect.step_field(1.0 / 60.0)
	assert(is_equal_approx(effect.impulse_shapes[0].y, FallingSand.POUR_Y_OFFSET))
	effect.free()
	pass


static func falling_sand_keeps_the_interface_readable_test() -> void:
	assert(is_equal_approx(FallingSand.DARK_SAND_OPACITY, 0.38))
	assert(is_equal_approx(FallingSand.LIGHT_SAND_OPACITY, 0.34))
	pass


func reasoning_sifts_a_pale_row_test() -> void:
	var effect := new_sand()
	effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
	effect.step_field(1.0 / 60.0)
	assert(effect.content_flow == 0.0)
	assert(effect.impulse_shapes.size() == 1)
	assert(int(effect.impulse_vectors[0].x) == FallingSand.Stamp.ROW)
	assert(is_equal_approx(effect.impulse_vectors[0].y, FallingSand.REASONING_TAG))
	effect.free()
	pass


func later_turns_lay_divider_lines_test() -> void:
	var effect := new_sand()
	effect.on_turn_start(1)
	assert(effect.divider_time == 0.0)
	effect.on_turn_start(1)
	assert(effect.divider_time == FallingSand.DIVIDER_SECONDS)
	effect.step_field(1.0 / 60.0)
	assert(is_equal_approx(effect.impulse_vectors[0].y, FallingSand.DIVIDER_TAG))
	for _index in range(30):
		effect.step_field(1.0 / 60.0)
	assert(effect.divider_time <= 0.0)
	effect.free()
	pass


func tools_pour_their_own_streams_and_failures_soak_the_column_test() -> void:
	var effect := new_sand()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t2", "shell", {} as Dictionary[String, Variant])
	effect.step_field(1.0 / 60.0)
	assert(effect.impulse_shapes.size() == 2)
	assert(is_equal_approx(effect.impulse_shapes[0].x, SimulationEffect.tool_anchor("grep").x))
	assert(is_equal_approx(effect.impulse_vectors[0].y, FallingSand.tool_tag("grep")))
	effect.impulse_shapes.clear()
	effect.impulse_vectors.clear()
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(not effect.faucets.has("t1") and effect.impulse_shapes.is_empty())
	effect.on_tool_execution_end(1, "t2", "shell", AgentToolResult.error("boom"))
	assert(effect.faucets.is_empty())
	assert(effect.failure_tint == 1.0)
	assert(int(effect.impulse_vectors[0].x) == FallingSand.Stamp.WET)
	assert(is_equal_approx(effect.impulse_shapes[0].x, SimulationEffect.tool_anchor("shell").x))
	effect.free()
	pass


func faucet_cap_drops_the_oldest_tool_test() -> void:
	var effect := new_sand()
	for index in range(FallingSand.MAX_FAUCETS + 2):
		effect.on_tool_execution_start(1, "t%d" % index, "tool_%d" % index, {} as Dictionary[String, Variant])
	assert(effect.faucets.size() == FallingSand.MAX_FAUCETS)
	assert(not effect.faucets.has("t0") and effect.faucets.has("t%d" % (FallingSand.MAX_FAUCETS + 1)))
	effect.free()
	pass


func full_pile_leaks_through_the_floor_test() -> void:
	var effect := new_sand()
	effect.step_field(1.0 / 60.0)
	assert(effect.drain == 0.0)
	effect.estimated_grains = float(effect.field_cells.x * effect.field_cells.y) * (FallingSand.FILL_LIMIT + 0.05)
	var before := effect.estimated_grains
	effect.step_field(1.0 / 60.0)
	assert(effect.drain == FallingSand.DRAIN_RATE)
	assert(effect.estimated_grains < before)
	effect.free()
	pass


func successful_end_flips_the_hourglass_test() -> void:
	var effect := new_sand()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	await effect.on_agent_end(1, "")
	assert(effect.gravity_up)
	assert(effect.faucets.is_empty() and effect.content_flow == 0.0)
	assert(effect.activity_floor == 0.0)
	effect.estimated_grains = float(effect.field_cells.x * effect.field_cells.y)
	effect.impulse_shapes.clear()
	effect.step_field(1.0 / 60.0)
	assert(effect.drain == 0.0 and effect.impulse_shapes.is_empty())
	effect.free()
	pass


func failed_end_soaks_all_sand_test() -> void:
	var effect := new_sand()
	await effect.on_agent_end(1, "Stop.")
	assert(not effect.gravity_up)
	assert(effect.failure_tint == 1.0)
	assert(int(effect.impulse_vectors[0].x) == FallingSand.Stamp.WET)
	assert(effect.impulse_shapes[0].z >= 0.5)
	effect.free()
	pass


func falling_sand_survives_a_full_event_sequence_in_tree_test() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var effect := FallingSand.new()
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.set_visual_visible(true, false)
	effect.on_turn_start(1)
	effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
	effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	for _frame in range(4):
		await scene_tree.process_frame
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	effect.on_message_complete(1, null)
	effect.on_turn_end(1)
	for _frame in range(3):
		await scene_tree.process_frame
	effect.queue_free()
	await scene_tree.process_frame
	pass


func new_sand() -> FallingSand:
	var effect := FallingSand.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.impulse_shapes.clear()
	effect.impulse_vectors.clear()
	return effect
