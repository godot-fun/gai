func start_runs_a_full_refresh_test() -> void:
	var effect := EInkRefresh.new()
	effect.on_agent_start(1)
	assert(effect.full_refresh != null)
	assert(effect.presence_target == 1.0)
	for _index in range(80):
		effect.step_panel(1.0 / 60.0)
	assert(effect.full_refresh == null)
	assert(effect.presence == 1.0)
	effect.free()
	pass


func content_stream_refreshes_strips_along_the_caret_test() -> void:
	var effect := EInkRefresh.new()
	effect.on_agent_start(1)
	var start_caret := effect.caret
	for _index in range(20):
		effect.on_message_update(1, "streamed answer chunk text", OpenAiClient.STREAM_KIND_CONTENT)
	effect.flush_strip()
	assert(effect.refreshes.size() > 0)
	assert(effect.refreshes.size() < EInkRefresh.MAX_REFRESHES)
	assert(effect.caret != start_caret)
	assert(effect.ghost > 0.0)
	for refresh: EInkRefresh.Refresh in effect.refreshes:
		assert(refresh.mode == EInkRefresh.MODE_PARTIAL)
	effect.free()
	pass


func reasoning_uses_fast_refresh_test() -> void:
	var effect := EInkRefresh.new()
	effect.on_agent_start(1)
	effect.on_message_update(1, "thinking", OpenAiClient.STREAM_KIND_REASONING)
	effect.step_panel(EInkRefresh.FAST_INTERVAL + 0.01)
	assert(effect.refreshes.size() == 1)
	assert(effect.refreshes[0].mode == EInkRefresh.MODE_FAST)
	effect.free()
	pass


func tool_busy_region_resolves_to_partial_or_stuck_test() -> void:
	var effect := EInkRefresh.new()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t2", "read_file", {} as Dictionary[String, Variant])
	var busy := effect.find_refresh("t1")
	assert(busy.mode == EInkRefresh.MODE_BUSY)
	assert(busy.rect.get_center().is_equal_approx(SimulationEffect.tool_anchor("grep")))
	for _index in range(200):
		effect.step_panel(1.0 / 60.0)
	assert(effect.refreshes.has(busy))
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("fine"))
	assert(busy.mode == EInkRefresh.MODE_PARTIAL)
	var failed := effect.find_refresh("t2")
	effect.on_tool_execution_end(1, "t2", "read_file", AgentToolResult.error("boom"))
	assert(failed.mode == EInkRefresh.MODE_STUCK)
	assert(failed.error == 1.0)
	effect.free()
	pass


func full_refresh_clears_ghosting_test() -> void:
	var effect := EInkRefresh.new()
	for _index in range(5):
		effect.add_refresh(Rect2(0.1, 0.1, 0.2, 0.05), EInkRefresh.MODE_PARTIAL, EInkRefresh.PARTIAL_SECONDS)
	assert(effect.ghost > 0.0)
	effect.start_full_refresh(0.0)
	for _index in range(40):
		effect.step_panel(1.0 / 60.0)
	assert(effect.ghost == 0.0)
	effect.free()
	pass
