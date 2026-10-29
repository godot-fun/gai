const PHOSPHOR_SCOPE_SCRIPT := preload("res://agent/ui/visuals/phosphor_scope/PhosphorScope.gd")


static func visual_type_is_registered_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PHOSPHOR_SCOPE)
	assert(effect != null)
	assert(effect.get_script() == PHOSPHOR_SCOPE_SCRIPT)
	effect.free()
	pass


static func visual_script_instantiates_test() -> void:
	var effect: Variant = PHOSPHOR_SCOPE_SCRIPT.new()
	assert(effect.get_script() == PHOSPHOR_SCOPE_SCRIPT)
	effect.free()
	pass


static func energy_composition_is_additive_without_overflow_test() -> void:
	assert(is_equal_approx(PHOSPHOR_SCOPE_SCRIPT.combine_energy(0.0, 0.4), 0.4))
	assert(PHOSPHOR_SCOPE_SCRIPT.combine_energy(0.6, 0.5) > 0.6)
	assert(PHOSPHOR_SCOPE_SCRIPT.combine_energy(0.6, 0.5) < 1.0)
	assert(PHOSPHOR_SCOPE_SCRIPT.combine_energy(1.0, 1.0) == 1.0)
	pass


static func streamed_chunks_have_restrained_energy_test() -> void:
	var short_energy: float = PHOSPHOR_SCOPE_SCRIPT.stream_energy_for_length(1)
	var long_energy: float = PHOSPHOR_SCOPE_SCRIPT.stream_energy_for_length(1000)
	assert(short_energy > 0.0)
	assert(long_energy > short_energy)
	assert(is_equal_approx(long_energy, 0.045))
	pass


static func beam_offset_is_zero_when_drives_are_idle_test() -> void:
	var offset: Vector2 = PHOSPHOR_SCOPE_SCRIPT.beam_offset(1.2, 1.5, 0.0, 0.0, 34.0)
	assert(offset.is_equal_approx(Vector2.ZERO))
	pass


static func phase_speed_rest_when_motion_is_idle_test() -> void:
	assert(is_equal_approx(PHOSPHOR_SCOPE_SCRIPT.phase_speed_for_motion(0.0), 0.0))
	assert(PHOSPHOR_SCOPE_SCRIPT.phase_speed_for_motion(1.0) > 7.0)
	pass


static func tool_phase_kick_is_stable_for_name_test() -> void:
	var first: float = PHOSPHOR_SCOPE_SCRIPT.phase_kick_for_tool("grep")
	var second: float = PHOSPHOR_SCOPE_SCRIPT.phase_kick_for_tool("grep")
	assert(is_equal_approx(first, second))
	assert(first >= 0.0 and first <= TAU)
	pass


static func coupled_beam_keeps_both_axes_during_reasoning_test() -> void:
	var reasoning_only: Vector2 = PHOSPHOR_SCOPE_SCRIPT.beam_offset(PI * 0.5, 1.5, 1.0, 0.0, 10.0, 0.0)
	assert(absf(reasoning_only.x) > 0.5)
	assert(absf(reasoning_only.y) > 0.05)
	var content_only: Vector2 = PHOSPHOR_SCOPE_SCRIPT.beam_offset(0.0, 1.5, 0.0, 1.0, 10.0, 0.0)
	assert(absf(content_only.y) > 0.4)
	assert(absf(content_only.x) > 0.05)
	pass


func reasoning_stream_raises_reasoning_drive_test() -> void:
	var effect: Variant = PHOSPHOR_SCOPE_SCRIPT.new()
	effect.on_message_update(1, "think", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.target_reasoning_drive > 0.0)
	effect.step_scope_field(1.0 / 60.0)
	assert(effect.reasoning_drive > 0.0)
	assert(effect.reasoning_drive > effect.content_drive)
	effect.free()
	pass


func content_stream_raises_content_drive_test() -> void:
	var effect: Variant = PHOSPHOR_SCOPE_SCRIPT.new()
	effect.on_message_update(1, "answer", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.target_content_drive > 0.0)
	effect.step_scope_field(1.0 / 60.0)
	assert(effect.content_drive > 0.0)
	effect.free()
	pass


func turn_start_swaps_frequency_ratio_without_resetting_phase_test() -> void:
	var effect: Variant = PHOSPHOR_SCOPE_SCRIPT.new()
	effect.beam_phase = 1.7
	effect.frequency_ratio_index = 0
	effect.on_turn_start(1)
	assert(effect.frequency_ratio_index == 1)
	assert(is_equal_approx(effect.beam_phase, 1.7))
	effect.free()
	pass


func scope_field_decays_to_rest_test() -> void:
	var effect: Variant = PHOSPHOR_SCOPE_SCRIPT.new()
	effect.target_reasoning_drive = 0.8
	effect.target_content_drive = 0.6
	effect.beam_energy = 0.7
	for _index in range(90):
		effect.step_scope_field(1.0 / 60.0)
	assert(effect.scope_is_idle())
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = PHOSPHOR_SCOPE_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.scope_material != null)
	assert(effect.scope_material.shader != null)
	effect.queue_free()
	await scene_tree.process_frame
	pass
