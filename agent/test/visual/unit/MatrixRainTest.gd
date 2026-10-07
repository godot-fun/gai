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


func answer_creates_bounded_wave_test() -> void:
	var effect := MatrixRain.new()
	for index in range(MatrixRain.MAX_WAVES + 5):
		effect.ingest_sentence("answer %d." % index)
		effect.emit_turn_wave()
	assert(effect.waves.size() == MatrixRain.MAX_WAVES)
	assert(not effect.reply_glyphs.is_empty())
	assert(String(effect.reply_glyphs[0]["text"]) == "a")
	effect.free()
	pass


func sentences_share_one_wave_per_turn_test() -> void:
	var effect := MatrixRain.new()
	effect.on_turn_start()
	effect.ingest_sentence("First sentence.")
	effect.ingest_sentence("Second sentence.")
	assert(effect.waves.is_empty())
	effect.on_turn_end()
	assert(effect.waves.size() == 1)
	assert(String(effect.waves[0]["text"]) == "First sentence.Second sentence.")
	effect.free()
	pass


static func wave_glyph_density_is_bounded_test() -> void:
	assert(MatrixRain.wave_glyph_count(1000, 100.0) == floori(TAU * 100.0 / MatrixRain.WAVE_GLYPH_SPACING))
	assert(MatrixRain.wave_glyph_count(12, 100.0) == 12)
	assert(MatrixRain.wave_glyph_count(1000, 0.0) == 0)
	pass


func reply_glyphs_keep_their_character_test() -> void:
	var effect := MatrixRain.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.ensure_columns()
	effect.ingest_sentence("Stable reply.")
	var first_text := String(effect.reply_glyphs[0]["text"])
	effect.visible = true
	effect._process(0.5)
	assert(String(effect.reply_glyphs[0]["text"]) == first_text)
	effect.free()
	pass


func tools_reserve_and_release_columns_test() -> void:
	var effect := MatrixRain.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.ensure_columns()
	effect.on_tool_execution_start("tool-1", "read_file", {})
	assert(effect.active_tools.has("tool-1"))
	var column_index: int = effect.active_tools["tool-1"]
	assert(int(effect.columns[column_index]["tool_state"]) == MatrixRain.ToolState.RUNNING)
	effect.on_tool_execution_end("tool-1", "read_file", AgentToolResult.ok("done"))
	assert(not effect.active_tools.has("tool-1"))
	assert(int(effect.columns[column_index]["tool_state"]) == MatrixRain.ToolState.SUCCESS)
	assert(bool(effect.columns[column_index]["release_pending"]))
	var column: Dictionary = effect.columns[column_index]
	column["head_y"] = effect.size.y + float(column["length"]) * float(column["step_y"]) + 1.0
	effect.visible = true
	effect._process(0.01)
	assert(int(column["tool_state"]) == MatrixRain.ToolState.NONE)
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
