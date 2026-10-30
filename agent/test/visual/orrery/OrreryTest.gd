extends RefCounted


func new_deck() -> Orrery:
	var effect := Orrery.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	return effect


## Asserted from source for the same reason as [GoBoard]: the factory script is not loaded here.
func visual_type_is_registered_test() -> void:
	var source := FileAccess.get_file_as_string("res://agent/ui/visuals/VisualControl.gd")
	assert(source.contains("\tORRERY,"))
	assert(source.contains("Type.ORRERY:"))
	assert(source.contains("return Orrery.new()"))
	pass


func translations_exist_test() -> void:
	var keys: Array[String] = ["visual_orrery", "orrery_title", "orrery_session", "orrery_summary"]
	keys.append_array(Orrery.PANEL_TITLES.map(func(key: String) -> String: return key.get_slice(".", 2)))
	for locale_path: String in ["res://agent/config/locale/en.json", "res://agent/config/locale/zh.json"]:
		var text := FileAccess.get_file_as_string(locale_path)
		for key: String in keys:
			assert(text.contains("\"%s\"" % key), "missing %s in %s" % [key, locale_path])
	pass


func web_curves_run_rim_to_rim_inside_the_disc_test() -> void:
	var effect := Orrery.new()
	assert(effect.web_curves.size() == Orrery.WEB_CURVES * 3)
	assert(effect.web_layers.size() == Orrery.WEB_CURVES)
	var pulse_curves := 0
	for curve in range(Orrery.WEB_CURVES):
		assert(absf(effect.web_curves[curve * 3].length() - 1.0) < 0.0001)
		assert(absf(effect.web_curves[curve * 3 + 2].length() - 1.0) < 0.0001)
		assert(effect.web_point(curve, 0.5).length() <= 1.0001)
		if effect.web_layers[curve] >= 0:
			pulse_curves += 1
	assert(pulse_curves > Orrery.WEB_CURVES / 5 and pulse_curves < Orrery.WEB_CURVES / 2)
	assert(effect.web_nodes.size() == Orrery.WEB_NODES)
	assert(Orrery.ease_in_out(0.0) == 0.0 and Orrery.ease_in_out(1.0) == 1.0)
	effect.free()
	pass


func runners_glide_and_respawn_test() -> void:
	var effect := new_deck()
	assert(effect.runners.size() == Orrery.RUNNER_COUNT)
	var first := effect.runners[0]
	var start := first.t
	effect.step_orrery(1.0 / 30.0)
	assert(effect.runners[0] != first or first.t > start)
	for _index in range(300):
		effect.step_orrery(1.0 / 30.0)
	assert(effect.runners.size() == Orrery.RUNNER_COUNT)
	for runner: Orrery.Runner in effect.runners:
		assert(runner.t >= 0.0 and runner.t < 1.0)
	effect.free()
	pass


func comets_land_on_the_ring_and_flash_it_test() -> void:
	var effect := new_deck()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.comets.size() == 4)
	var pulses_before := effect.pulses.size()
	for _index in range(45):
		effect.step_orrery(1.0 / 30.0)
		if not effect.ring_flashes.is_empty():
			break
	assert(not effect.ring_flashes.is_empty())
	assert(effect.pulses.size() > pulses_before)
	# A converging tool comet lands near that tool's bearing on the ring.
	var flash := effect.ring_flashes[0]
	var landing := flash.x + effect.outer_angle
	assert(absf(angle_difference(landing, Orrery.tool_angle("grep"))) < 0.2)
	for _index in range(60):
		effect.step_orrery(1.0 / 30.0)
	assert(effect.comets.is_empty() and effect.ring_flashes.is_empty())
	effect.free()
	pass


func turns_pulse_the_web_layers_test() -> void:
	var effect := new_deck()
	effect.on_turn_start(1)
	assert(effect.layer_env[0] >= 0.6 and effect.beat_env == 1.0)
	assert(effect.comets.size() == 6)
	for _index in range(60):
		effect.step_orrery(1.0 / 30.0)
	assert(effect.layer_env[0] < 0.2 and effect.beat_env < 0.05)
	effect.free()
	pass


func ring_tiles_cover_the_circumference_test() -> void:
	var tiles := Orrery.ring_tiles()
	assert(tiles >= 3)
	var effect := Orrery.new()
	effect.size = Vector2(1600.0, 900.0)
	var tile := effect.tile_pixel_size()
	assert(tile.y > tile.x * 3)
	effect.free()
	pass


func reasoning_zooms_in_and_tools_zoom_out_test() -> void:
	var effect := new_deck()
	assert(effect.zoom_target() == Orrery.ZOOM_MIN)
	for _index in range(4):
		effect.on_message_update(1, "thinking about the overlay in depth", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.zoom_target() == Orrery.ZOOM_MAX)
	for _index in range(60):
		effect.step_orrery(1.0 / 30.0)
		effect.on_message_update(1, "thinking about the overlay in depth", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.zoom > 1.5)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.zoom_target() == Orrery.ZOOM_MIN)
	effect.on_agent_end(1, "")
	assert(effect.zoom_target() == Orrery.ZOOM_END)
	effect.free()
	pass


func inner_and_outer_layers_rotate_independently_test() -> void:
	var effect := new_deck()
	effect.step_orrery(0.5)
	assert(effect.inner_angle > 0.0)
	# Outer layers turn the opposite way; fposmod keeps the angle in [0, TAU).
	assert(effect.outer_angle > PI)
	effect.free()
	pass


func tools_and_answers_emit_pulses_test() -> void:
	var effect := new_deck()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.pulses.size() == 1 and effect.pulses[0].w == 1.0)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.pulses.size() == 2 and effect.pulses[1].w == 2.0)
	assert(Orrery.tool_angle("grep") == Orrery.tool_angle("grep"))
	for _index in range(60):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.pulses.size() > 2 and effect.pulses.size() <= Orrery.PULSE_LIMIT)
	# Comets still in flight land later and emit pulses of their own, so let all of them drain.
	for _index in range(150):
		effect.step_orrery(1.0 / 30.0)
	assert(effect.pulses.is_empty())
	effect.free()
	pass


func helpers_format_for_terminal_rows_test() -> void:
	assert(Orrery.compact_count(999) == "999")
	assert(Orrery.compact_count(12300) == "12.3K")
	assert(Orrery.format_clock(75.4) == "01:15")
	assert(Orrery.clip_text("abcdef", 4) == "abc…")
	assert(Orrery.clean_text("a\nb\tc") == "a b c")
	var args: Dictionary[String, Variant] = {"path": "res://a.gd", "line": 3, "extra": true}
	assert(Orrery.compact_args(args, 64) == "path=res://a.gd line=3")
	assert(Orrery.histogram_bin(0) == 0)
	assert(Orrery.histogram_bin(100000) == Orrery.HISTOGRAM_BINS - 1)
	pass


func stream_fills_feed_and_buffers_test() -> void:
	var effect := new_deck()
	for _index in range(4):
		effect.on_message_update(1, "considering which files define the visual overlay", OpenAiClient.STREAM_KIND_REASONING)
	effect.on_message_update(1, "Here is the plan.", OpenAiClient.STREAM_KIND_CONTENT)
	effect.on_turn_end(1)
	assert(effect.reasoning_chars > 0 and effect.content_chars > 0)
	assert(effect.reasoning_energy > 0.0)
	assert(not effect.dots.is_empty())
	var tags := effect.feed.map(func(line: Orrery.FeedLine) -> int: return line.tag)
	assert(tags.has(Orrery.Tag.THINK))
	assert(tags.has(Orrery.Tag.WRITE))
	assert(effect.feed.size() <= Orrery.FEED_LIMIT)
	for _index in range(30):
		effect.step_orrery(1.0 / 30.0)
	assert(effect.reasoning_history.size() == Orrery.HISTORY_SIZE)
	assert(effect.reasoning_history[effect.reasoning_history.size() - 1] > 0.0)
	effect.free()
	pass


func tools_track_success_and_failure_test() -> void:
	var effect := new_deck()
	effect.on_tool_execution_start(1, "t1", "grep", {"pattern": "deck"} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t2", "read_file", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t3", "grep", {} as Dictionary[String, Variant])
	assert(effect.running_tools() == 3)
	assert(effect.phase_key() == "agent.visuals.orrery_dispatch")
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	effect.on_tool_execution_end(1, "t2", "read_file", AgentToolResult.error("boom"))
	effect.on_tool_execution_end(1, "missing", "grep", AgentToolResult.ok("ignored"))
	assert(effect.running_tools() == 1)
	assert(effect.tool_total == 3)
	assert(effect.tool_failed == 1)
	assert(effect.error_flash > 0.0)
	assert(effect.tool_stats["grep"] == Vector2i(2, 0))
	assert(effect.tool_stats["read_file"] == Vector2i(1, 1))
	assert(effect.ranked_tools()[0] == "grep")
	effect.free()
	pass


func tracks_trim_finished_before_running_test() -> void:
	var effect := new_deck()
	effect.on_tool_execution_start(1, "long", "bash", {} as Dictionary[String, Variant])
	for index in range(Orrery.TRACK_LIMIT + 3):
		var id := "t%d" % index
		effect.on_tool_execution_start(1, id, "grep", {} as Dictionary[String, Variant])
		effect.on_tool_execution_end(1, id, "grep", AgentToolResult.ok("done"))
	assert(effect.tracks.size() == Orrery.TRACK_LIMIT)
	assert(effect.track_by_id.has("long"))
	assert(effect.tracks[0].id == "long")
	effect.free()
	pass


func ending_finishes_tools_and_runs_scan_test() -> void:
	var effect := new_deck()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_agent_end(1, "network down")
	assert(effect.ending)
	assert(effect.running_tools() == 0)
	assert(effect.tool_failed == 1)
	assert(effect.feed[effect.feed.size() - 1].tag == Orrery.Tag.FAIL)
	effect.on_message_update(1, "late chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.content_chars == 0)
	for _index in range(40):
		effect.step_orrery(1.0 / 30.0)
	assert(effect.end_progress == 1.0)
	effect.on_agent_start(2)
	assert(not effect.ending and effect.feed.size() == 1 and effect.tool_total == 0)
	effect.free()
	pass


func deck_survives_a_full_event_sequence_in_tree_test() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var effect := Orrery.new()
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.set_visual_visible(true, false)
	effect.on_turn_start(1)
	effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
	effect.on_tool_execution_start(1, "t1", "grep", {"pattern": "x"} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t2", "read_file", {} as Dictionary[String, Variant])
	for _index in range(3):
		effect.on_message_update(1, "streamed answer chunk of a reasonable length", OpenAiClient.STREAM_KIND_CONTENT)
		await scene_tree.process_frame
	assert(effect.screen_viewport != null)
	assert(effect.screen_viewport.size.x > 16)
	assert(effect.stage != null and effect.stage.clip_contents)
	assert(effect.stage.size.y > 16.0)
	assert(effect.stage.ring_mesh != null and effect.stage.ring_mesh.mesh != null)
	assert(effect.stage.procedural_layer != null and effect.stage.procedural_material != null)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	effect.on_tool_execution_end(1, "t2", "read_file", AgentToolResult.error("boom"))
	effect.on_message_complete(1, null)
	effect.on_turn_end(1)
	for _frame in range(3):
		await scene_tree.process_frame
	effect.queue_free()
	await scene_tree.process_frame
	pass
