extends RefCounted


func new_movement() -> Clockwork:
	var effect := Clockwork.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	return effect


## Asserted from source for the same reason as [GoBoard]: the factory script is not loaded here.
func visual_type_is_registered_test() -> void:
	var source := FileAccess.get_file_as_string("res://agent/ui/visuals/VisualControl.gd")
	assert(source.contains("\tCLOCKWORK,"))
	assert(source.contains("Type.CLOCKWORK:"))
	assert(source.contains("return Clockwork.new()"))
	pass


func translations_exist_test() -> void:
	for locale_path: String in ["res://agent/config/locale/en.json", "res://agent/config/locale/zh.json"]:
		var text := FileAccess.get_file_as_string(locale_path)
		assert(text.contains("\"visual_clockwork\""), "missing visual_clockwork in %s" % locale_path)
	pass


func gear_ratio_flips_direction_test() -> void:
	assert(is_equal_approx(Clockwork.gear_ratio(48, 40), -1.2))
	assert(is_equal_approx(Clockwork.gear_ratio(30, 15), -2.0))
	assert(Clockwork.gear_ratio(10, 0) == 0.0)
	pass


func movement_meshes_gears_tangentially_test() -> void:
	var effect := new_movement()
	assert(effect.gears.size() == 4)
	for index in range(1, effect.gears.size()):
		var gap := effect.gears[index].center.distance_to(effect.gears[index - 1].center)
		var touching := effect.gears[index].radius + effect.gears[index - 1].radius
		assert(absf(gap - touching) < touching * 0.05, "gear %d does not mesh" % index)
	assert(effect.gears[1].ratio < 0.0)
	assert(effect.gears[2].ratio > 0.0)
	assert(effect.gears[3].ratio < 0.0)
	effect.free()
	pass


func reasoning_winds_the_mainspring_test() -> void:
	var effect := new_movement()
	assert(effect.tension == 0.0)
	effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.tension > 0.0)
	var wound := effect.tension
	effect.step_clock(0.25)
	assert(effect.tension < wound)
	effect.free()
	pass


func answer_stream_releases_beats_test() -> void:
	var effect := new_movement()
	for _index in range(2):
		effect.on_message_update(1, "streamed answer chunk of a reasonable length", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.beat_count > 0)
	assert(effect.beat_flash > 0.0)
	effect.free()
	pass


func escape_wheel_only_sits_on_teeth_test() -> void:
	var effect := new_movement()
	effect.tension = 1.0
	effect.beat()
	for _index in range(40):
		effect.step_clock(1.0 / 60.0)
	var escape: Clockwork.Gear = effect.gears[3]
	var tooth := TAU / float(Clockwork.ESCAPE_TEETH)
	var offset := fposmod(escape.angle, tooth)
	assert(offset < 0.001 or absf(offset - tooth) < 0.001, "escape wheel slid off its teeth")
	effect.free()
	pass


func tool_success_chimes_and_advances_test() -> void:
	var effect := new_movement()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.hammers.size() == 1)
	effect.step_clock(0.2)
	assert(effect.hammers["t1"].lift > 0.0)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(effect.hammers.is_empty())
	assert(effect.chime == 1.0)
	assert(effect.beat_count == 1)
	assert(effect.tension > 0.0)
	effect.free()
	pass


func tool_failure_jams_the_escapement_test() -> void:
	var effect := new_movement()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.hammers.is_empty())
	assert(effect.jam == 1.0)
	assert(effect.chime == 0.0)
	effect.step_clock(0.5)
	assert(effect.jam < 1.0)
	effect.free()
	pass


func unwinding_stops_the_movement_test() -> void:
	var effect := new_movement()
	effect.tension = 1.0
	effect.on_agent_end(1, "")
	assert(effect.unwinding)
	for _index in range(240):
		effect.step_clock(1.0 / 60.0)
	assert(effect.tension == 0.0)
	assert(effect.rate < 0.01)
	effect.free()
	pass


func movement_is_centred_in_the_window_test() -> void:
	var effect := new_movement()
	var view := effect.view_size()
	var center := effect.composition_bounds().get_center()
	assert((center - view * 0.5).length() < 1.0, "movement centre %s is off the window centre %s" % [center, view * 0.5])
	effect.free()
	pass


func seconds_hand_steps_in_eighth_ticks_test() -> void:
	var effect := new_movement()
	effect.tension = 1.0
	for _index in range(30):
		effect.step_clock(1.0 / 60.0)
	assert(effect.seconds_angle > 0.0)
	var tooth := TAU / Clockwork.SECONDS_STEPS
	var ticks := roundf(effect.seconds_angle / tooth)
	assert(absf(effect.seconds_angle - ticks * tooth) < 0.001, "seconds hand did not step cleanly")
	effect.free()
	pass


func winding_clicks_the_ratchet_test() -> void:
	var effect := new_movement()
	for _index in range(4):
		effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
	effect.step_clock(1.0 / 60.0)
	assert(effect.ratchet_steps > 0)
	assert(effect.pawl_flick > 0.0)
	effect.free()
	pass


func beat_fires_a_spark_at_the_escape_wheel_test() -> void:
	var effect := new_movement()
	effect.step_clock(1.0)
	assert(effect.spark_age == Clockwork.SPARK_SECONDS)
	effect.beat()
	assert(effect.spark_age == 0.0)
	effect.step_clock(Clockwork.SPARK_SECONDS)
	assert(effect.spark_age == Clockwork.SPARK_SECONDS)
	effect.free()
	pass


func movement_survives_a_full_event_sequence_in_tree_test() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var effect := Clockwork.new()
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.set_visual_visible(true, false)
	effect.on_turn_start(1)
	effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t2", "read_file", {} as Dictionary[String, Variant])
	for _frame in range(3):
		await scene_tree.process_frame
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	effect.on_tool_execution_end(1, "t2", "read_file", AgentToolResult.error("boom"))
	effect.on_message_update(1, "streamed answer chunk of a reasonable length", OpenAiClient.STREAM_KIND_CONTENT)
	effect.on_message_complete(1, null)
	effect.on_turn_end(1)
	for _frame in range(3):
		await scene_tree.process_frame
	effect.queue_free()
	await scene_tree.process_frame
	pass
