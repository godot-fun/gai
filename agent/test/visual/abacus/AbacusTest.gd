extends RefCounted


func new_abacus() -> Abacus:
	var effect := Abacus.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	return effect


## Asserted from source for the same reason as [GoBoard]: the factory script is not loaded here.
func visual_type_is_registered_test() -> void:
	var source := FileAccess.get_file_as_string("res://agent/ui/visuals/VisualControl.gd")
	assert(source.contains("\tABACUS,"))
	assert(source.contains("Type.ABACUS:"))
	assert(source.contains("return Abacus.new()"))
	pass


func translations_exist_test() -> void:
	for locale_path: String in ["res://agent/config/locale/en.json", "res://agent/config/locale/zh.json"]:
		var text := FileAccess.get_file_as_string(locale_path)
		assert(text.contains("\"visual_abacus\""), "missing visual_abacus in %s" % locale_path)
		assert(text.contains("\"abacus_preview\""), "missing abacus_preview in %s" % locale_path)
	pass


func digits_are_units_first_test() -> void:
	var digits := Abacus.digits_of(1234, 6)
	assert(digits.size() == 6)
	assert(digits[0] == 4)
	assert(digits[1] == 3)
	assert(digits[2] == 2)
	assert(digits[3] == 1)
	assert(digits[4] == 0)
	assert(digits[5] == 0)
	pass


func bead_targets_split_upper_and_lower_decks_test() -> void:
	assert(Abacus.bead_targets(0) == Vector2i(0, 0))
	assert(Abacus.bead_targets(4) == Vector2i(0, 4))
	assert(Abacus.bead_targets(5) == Vector2i(1, 0))
	assert(Abacus.bead_targets(7) == Vector2i(1, 2))
	assert(Abacus.bead_targets(9) == Vector2i(1, 4))
	assert(Abacus.rod_value(1, 2) == 7)
	pass


func carry_lands_on_the_next_rod_test() -> void:
	assert(Abacus.carry_rod(8) == 0)
	assert(Abacus.carry_rod(9) == 1)
	assert(Abacus.carry_rod(99) == 2)
	assert(Abacus.carry_rod(108) == 0)
	pass


func value_commits_beads_and_carries_test() -> void:
	var effect := new_abacus()
	effect.set_value(9)
	assert(effect.rods[0].target_upper == 1)
	assert(effect.rods[0].target_lower == 4)
	effect.set_value(10)
	assert(effect.rods[0].target_upper == 0)
	assert(effect.rods[0].target_lower == 0)
	assert(effect.rods[1].target_upper == 0)
	assert(effect.rods[1].target_lower == 1)
	effect.free()
	pass


func content_stream_counts_units_test() -> void:
	var effect := new_abacus()
	for _index in range(6):
		effect.on_message_update(1, "streamed answer chunk of a reasonable length", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.value > 0)
	var digits := Abacus.digits_of(effect.value, effect.rods.size())
	for index in range(effect.rods.size()):
		var targets := Abacus.bead_targets(digits[index])
		assert(effect.rods[index].target_upper == targets.x)
		assert(effect.rods[index].target_lower == targets.y)
	effect.free()
	pass


func reasoning_previews_without_committing_test() -> void:
	var effect := new_abacus()
	effect.set_value(3)
	for _index in range(2):
		effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.value == 3)
	assert(effect.preview_value > effect.value)
	effect.on_turn_start(1)
	assert(effect.value == effect.preview_value)
	effect.free()
	pass


func tool_failure_restores_the_snapshot_test() -> void:
	var effect := new_abacus()
	effect.set_value(5)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.active_rod == Abacus.carry_rod(6))
	effect.set_value(12)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.value == 5)
	assert(effect.active_rod == -1)
	var shook := false
	for rod: Abacus.Rod in effect.rods:
		if rod.shake > 0.0:
			shook = true
	assert(shook)
	effect.free()
	pass


func tool_success_commits_the_preview_test() -> void:
	var effect := new_abacus()
	effect.set_value(3)
	for _index in range(3):
		effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
	var preview := effect.preview_value
	assert(preview > 3)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(effect.value >= preview)
	assert(effect.preview_value == effect.value)
	effect.free()
	pass


func ending_clears_the_frame_to_zero_test() -> void:
	var effect := new_abacus()
	effect.set_value(42)
	effect.on_agent_end(1, "")
	assert(effect.clearing)
	assert(effect.value == 0)
	assert(effect.rods[0].target_lower == 0)
	assert(effect.rods[1].target_lower == 0)
	effect.free()
	pass


func beads_settle_on_their_targets_test() -> void:
	var effect := new_abacus()
	effect.set_value(8)
	for _index in range(120):
		effect.step_abacus(1.0 / 60.0)
	assert(effect.rods[0].upper_pos == 1.0)
	assert(effect.rods[0].lower_pos == 3.0)
	effect.free()
	pass


func abacus_survives_a_full_event_sequence_in_tree_test() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var effect := Abacus.new()
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	effect.set_visual_visible(true, false)
	effect.on_turn_start(1)
	effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t2", "read_file", {} as Dictionary[String, Variant])
	for _index in range(3):
		effect.on_message_update(1, "streamed answer chunk of a reasonable length", OpenAiClient.STREAM_KIND_CONTENT)
		await scene_tree.process_frame
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	effect.on_tool_execution_end(1, "t2", "read_file", AgentToolResult.error("boom"))
	effect.on_message_complete(1, null)
	effect.on_turn_end(1)
	for _frame in range(3):
		await scene_tree.process_frame
	effect.queue_free()
	await scene_tree.process_frame
	pass
