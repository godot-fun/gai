func content_stream_sews_running_stitches_test() -> void:
	var effect := Embroidery.new()
	effect.on_agent_start(1)
	for _index in range(10):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	effect.flush_stitches()
	assert(effect.rows.size() >= 1)
	assert(effect.rows[0].kind == Embroidery.KIND_RUNNING)
	assert(effect.rows[0].x1 > effect.rows[0].x0)
	assert(effect.caret.x > Embroidery.LINE_LEFT)
	effect.free()
	pass


func reasoning_lays_separate_basting_test() -> void:
	var effect := Embroidery.new()
	effect.on_agent_start(1)
	effect.on_message_update(1, "thinking about it", OpenAiClient.STREAM_KIND_REASONING)
	effect.on_message_update(1, "the answer", OpenAiClient.STREAM_KIND_CONTENT)
	effect.flush_stitches()
	assert(effect.rows.size() == 2)
	assert(effect.rows[0].kind == Embroidery.KIND_BASTING)
	assert(effect.rows[1].kind == Embroidery.KIND_RUNNING)
	assert(is_equal_approx(effect.rows[1].x0, effect.rows[0].x1))
	effect.free()
	pass


func full_lines_wrap_and_unpick_at_bottom_test() -> void:
	var effect := Embroidery.new()
	effect.on_agent_start(1)
	effect.pending_width = (Embroidery.LINE_RIGHT - Embroidery.LINE_LEFT) * 2.5
	effect.flush_stitches()
	assert(is_equal_approx(effect.caret.y, Embroidery.LINE_TOP + Embroidery.LINE_HEIGHT * 2.0))
	effect.caret.y = Embroidery.LINE_BOTTOM
	effect.new_line()
	assert(is_equal_approx(effect.caret.y, Embroidery.LINE_TOP))
	for row: Embroidery.StitchRow in effect.rows:
		assert(row.unpick >= 0.0)
	effect.free()
	pass


func tool_badge_completes_with_gold_ring_on_success_test() -> void:
	var effect := Embroidery.new()
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	var patch := effect.find_patch("t1")
	assert(patch.center.is_equal_approx(SimulationEffect.tool_anchor("grep")))
	for _index in range(120):
		effect.step_stitches(1.0 / 60.0)
	assert(is_equal_approx(patch.progress, Embroidery.HOLD_PROGRESS))
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("fine"))
	for _index in range(120):
		effect.step_stitches(1.0 / 60.0)
	assert(patch.progress == 1.0)
	assert(patch.border == 1.0)
	effect.free()
	pass


func tool_error_unravels_badge_test() -> void:
	var effect := Embroidery.new()
	effect.on_agent_start(1)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	var patch := effect.find_patch("t1")
	assert(patch.unravel == 0.0)
	for _index in range(150):
		effect.step_stitches(1.0 / 60.0)
	assert(effect.patches.is_empty())
	effect.free()
	pass


func message_complete_ties_knot_and_breaks_line_test() -> void:
	var effect := Embroidery.new()
	effect.on_agent_start(1)
	effect.on_message_update(1, "the answer", OpenAiClient.STREAM_KIND_CONTENT)
	effect.on_message_complete(1, null)
	assert(effect.rows[-1].knot)
	assert(is_equal_approx(effect.caret.x, Embroidery.LINE_LEFT))
	effect.free()
	pass
