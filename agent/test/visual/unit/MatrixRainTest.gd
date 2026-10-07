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


func answer_creates_bounded_reply_glyphs_test() -> void:
	var effect := MatrixRain.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.ensure_columns()
	for index in range(80):
		effect.ingest_sentence("answer %d with enough characters to fill columns." % index)
	assert(effect.reply_glyphs.size() <= MatrixRain.MAX_REPLY_GLYPHS)
	assert(not effect.reply_glyphs.is_empty())
	effect.free()
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
