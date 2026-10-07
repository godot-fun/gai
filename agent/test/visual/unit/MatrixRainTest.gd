extends RefCounted


static func visual_type_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.MATRIX_RAIN))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.MATRIX_RAIN)
	assert(effect != null)
	assert(effect.get_visual_type() == VisualType.Type.MATRIX_RAIN)
	effect.free()
	control.free()
	pass


func reasoning_accelerates_rain_test() -> void:
	var effect := MatrixRain.new()
	effect.on_message_update("inspect the current implementation", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.reasoning_energy > 0.0)
	effect.free()
	pass


func answer_creates_bounded_reply_rains_without_evicting_old_glyphs_test() -> void:
	var effect := MatrixRain.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.ensure_columns()
	effect.ingest_sentence("The first reply rain must remain visible.")
	var first_text := effect.reply_glyphs[0].text
	for index in range(80):
		effect.ingest_sentence("answer %d with enough characters to fill columns." % index)
	assert(effect.active_reply_rain_count == MatrixRain.MAX_REPLY_RAINS)
	assert(effect.reply_glyphs[0].text == first_text)
	effect.free()
	pass


func reply_glyphs_keep_their_character_test() -> void:
	var effect := MatrixRain.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.ensure_columns()
	effect.ingest_sentence("Stable reply rain speed across its characters.")
	var first_text := effect.reply_glyphs[0].text
	var first_rain_speed := effect.reply_glyphs[0].speed
	assert(first_rain_speed >= MatrixRain.MIN_REPLY_RAIN_SPEED)
	assert(first_rain_speed <= MatrixRain.MAX_REPLY_RAIN_SPEED)
	for index in range(MatrixRain.REPLY_COLUMN_LENGTH):
		assert(is_equal_approx(effect.reply_glyphs[index].speed, first_rain_speed))
	effect.visible = true
	effect._process(0.5)
	assert(effect.reply_glyphs[0].text == first_text)
	effect.free()
	pass


func full_reply_rain_capacity_rejects_before_consuming_pending_sentence_test() -> void:
	var effect := MatrixRain.new()
	effect.active_reply_rain_count = MatrixRain.MAX_REPLY_RAINS
	effect.pending_sentence = "Keep this sentence pending."
	assert(not effect.offer_next_sentence())
	assert(effect.pending_sentence == "Keep this sentence pending.")
	effect.free()
	pass


func tools_reserve_and_release_columns_test() -> void:
	var effect := MatrixRain.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.ensure_columns()
	effect.on_agent_start(1)
	effect.on_tool_execution_start("tool-1", "read_file", {})
	assert(effect.active_tools.has("tool-1"))
	var column_index: int = effect.active_tools["tool-1"]
	assert(effect.columns[column_index].tool_state == MatrixRain.ToolState.RUNNING)
	effect.on_tool_execution_end("tool-1", "read_file", AgentToolResult.ok("done"))
	assert(not effect.active_tools.has("tool-1"))
	assert(effect.columns[column_index].tool_state == MatrixRain.ToolState.SUCCESS)
	assert(effect.columns[column_index].release_pending)
	var column := effect.columns[column_index]
	column.head_y = effect.size.y + float(column.length) * column.step_y + 1.0
	effect.visible = true
	effect._process(0.01)
	assert(column.tool_state == MatrixRain.ToolState.NONE)
	effect.free()
	pass


func agent_end_accelerates_rain_offscreen_test() -> void:
	var effect := MatrixRain.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.ensure_columns()
	effect.ingest_sentence("Finish with a fast falling rain animation.")
	var delay := effect.on_agent_end("")
	assert(is_zero_approx(delay))
	assert(effect.active_session_id == 0)
	for column: MatrixRain.RainColumn in effect.columns:
		assert(column.speed >= MatrixRain.END_DROP_MIN_SPEED)
	for reply_glyph: MatrixRain.ReplyGlyph in effect.reply_glyphs:
		assert(reply_glyph.speed >= MatrixRain.END_DROP_MIN_SPEED)
	effect.visible = true
	effect._process(MatrixRain.END_DROP_SECONDS)
	for column: MatrixRain.RainColumn in effect.columns:
		var tail_y := column.head_y - float(column.length - 1) * column.step_y
		assert(tail_y > effect.size.y)
	assert(effect.reply_glyphs.is_empty())
	effect.free()
	pass


static func sentence_cursor_waits_for_complete_tail_test() -> void:
	var entries: Array[ChatEntry] = [ChatEntry.new(ChatEntry.KIND_AGENT, ChatEntry.TITLE_AGENT, "First. Second")]
	var cursor := VisualChatSentenceCursor.new()
	assert(cursor.take_next(entries) == "First.")
	assert(cursor.take_next(entries).is_empty())
	entries[0].body += " complete!"
	assert(cursor.take_next(entries) == "Second complete!")
	pass
