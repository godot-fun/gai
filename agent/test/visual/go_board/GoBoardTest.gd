extends RefCounted


func new_board() -> GoBoard:
	var effect := GoBoard.new()
	effect.on_agent_start(1)
	return effect


func place(effect: GoBoard, cell: Vector2i, side: int) -> void:
	assert(effect.place_stone(cell, side, false))


func surround_white_stone(effect: GoBoard) -> void:
	place(effect, Vector2i(6, 5), GoBoard.Stone.WHITE)
	for cell: Vector2i in [Vector2i(5, 5), Vector2i(7, 5), Vector2i(6, 4), Vector2i(6, 6)]:
		place(effect, cell, GoBoard.Stone.BLACK)
	pass


## The factory is asserted from source: loading VisualControl pulls every effect script into the
## headless run, which crashes at engine shutdown in this build.
func visual_type_is_registered_test() -> void:
	var source := FileAccess.get_file_as_string("res://agent/ui/visuals/VisualControl.gd")
	assert(source.contains("\tGO_BOARD,"))
	assert(source.contains("Type.GO_BOARD:"))
	assert(source.contains("return GoBoard.new()"))
	# Random picks actual enum values, so removed numeric ids and future explicit ids are safe.
	assert(source.contains("visual_type = visual_types.pick_random() as Type"))
	pass


func translations_exist_test() -> void:
	for locale_path: String in ["res://agent/config/locale/en.json", "res://agent/config/locale/zh.json"]:
		var text := FileAccess.get_file_as_string(locale_path)
		for key: String in ["visual_go_board", "go_move", "go_captures", "go_black", "go_white", "go_komi"]:
			assert(text.contains("\"%s\"" % key), "missing key %s in %s" % [key, locale_path])
	pass


func group_without_liberties_is_captured_test() -> void:
	var effect := new_board()
	surround_white_stone(effect)
	assert(effect.liberties_of(effect.group_cells(Vector2i(6, 5))).is_empty())
	assert(effect.capture_adjacent_enemy(Vector2i(5, 5), GoBoard.Stone.BLACK) == 1)
	assert(not effect.stones.has(Vector2i(6, 5)))
	assert(effect.fading.size() == 1)
	effect.free()
	pass


func territory_only_claims_single_color_regions_test() -> void:
	var effect := new_board()
	for cell: Vector2i in [Vector2i(5, 5), Vector2i(7, 5), Vector2i(6, 4), Vector2i(6, 6)]:
		place(effect, cell, GoBoard.Stone.BLACK)
	var single := effect.compute_territory()
	assert(single.get(Vector2i(6, 5), -1) == GoBoard.Stone.BLACK)
	assert(single.get(Vector2i(0, 0), -1) == GoBoard.Stone.BLACK)
	place(effect, Vector2i(12, 12), GoBoard.Stone.WHITE)
	var split := effect.compute_territory()
	assert(split.get(Vector2i(6, 5), -1) == GoBoard.Stone.BLACK)
	assert(not split.has(Vector2i(0, 0)))
	effect.free()
	pass


func successful_tool_wins_the_fight_test() -> void:
	var effect := new_board()
	surround_white_stone(effect)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.fights.size() == 1)
	assert(not effect.liberties.is_empty())
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(effect.fights.is_empty())
	assert(effect.captures[GoBoard.Stone.BLACK] == 1)
	assert(not effect.stones.has(Vector2i(6, 5)))
	assert(effect.flashes.size() == 1)
	effect.free()
	pass


func failed_tool_loses_the_group_and_leaves_a_mark_test() -> void:
	var effect := new_board()
	surround_white_stone(effect)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	var fought: Vector2i = effect.fights["t1"]
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.fights.is_empty())
	assert(effect.marks.size() == 1)
	assert(effect.captures[GoBoard.Stone.WHITE] == 1)
	assert(effect.stones.has(Vector2i(6, 5)))
	# White answers on the point the lost group vacated.
	assert(effect.stones[fought].side == GoBoard.Stone.WHITE)
	effect.free()
	pass


func reasoning_tries_shadows_and_answers_settle_them_test() -> void:
	var effect := new_board()
	effect.on_turn_start(1)
	effect.on_message_update(1, "thinking about the plan for a while", OpenAiClient.STREAM_KIND_REASONING)
	assert(not effect.shadows.is_empty())
	var shadowed: Vector2i = effect.shadows[0].cell
	for _index in range(2):
		effect.on_message_update(1, "streamed answer chunk with enough characters", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.stones.has(shadowed))
	assert(effect.move_number >= 1)
	effect.on_turn_start(1)
	assert(effect.shadows.is_empty())
	effect.free()
	pass


func scoring_adds_stones_territory_and_komi_test() -> void:
	var effect := new_board()
	for cell: Vector2i in [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(5, 6), Vector2i(6, 6)]:
		place(effect, cell, GoBoard.Stone.BLACK)
	var usage := OpenAiUsage.new()
	usage.total_tokens = 1000
	effect.on_message_complete(1, usage)
	effect.start_scoring()
	assert(is_equal_approx(effect.komi, 2.0))
	assert(effect.black_score == GoBoard.BOARD_SIZE * GoBoard.BOARD_SIZE)
	assert(is_equal_approx(effect.white_score, 2.0))
	effect.free()
	pass


func scoring_groups_empty_points_into_regions_test() -> void:
	var effect := new_board()
	for cell: Vector2i in [Vector2i(5, 5), Vector2i(7, 5), Vector2i(6, 4), Vector2i(6, 6)]:
		place(effect, cell, GoBoard.Stone.BLACK)
	effect.start_scoring()
	assert(effect.regions.size() == 2)
	assert(effect.regions[0].cells.size() >= effect.regions[1].cells.size())
	assert(effect.regions[1].cells.size() == 1)
	assert(effect.regions[1].owner == GoBoard.Stone.BLACK)
	effect.free()
	pass


func board_survives_a_full_event_sequence_in_tree_test() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var effect := GoBoard.new()
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.set_visual_visible(true, false)
	effect.on_turn_start(1)
	for _index in range(3):
		effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
		effect.on_message_update(1, "streamed answer chunk with enough characters", OpenAiClient.STREAM_KIND_CONTENT)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t2", "read_file", {} as Dictionary[String, Variant])
	for _frame in range(3):
		await scene_tree.process_frame
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	effect.on_tool_execution_end(1, "t2", "read_file", AgentToolResult.error("boom"))
	effect.on_message_complete(1, null)
	effect.on_turn_end(1)
	effect.start_scoring()
	for _frame in range(3):
		await scene_tree.process_frame
	effect.queue_free()
	await scene_tree.process_frame
	pass
