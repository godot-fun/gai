extends RefCounted


static func visual_type_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.CONTEXT_MEMORY_RIVER))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.CONTEXT_MEMORY_RIVER)
	assert(effect is ContextMemoryRiver)
	assert(effect.get_visual_type() == VisualType.Type.CONTEXT_MEMORY_RIVER)
	effect.free()
	control.free()
	pass


static func context_usage_test() -> void:
	var effect := ContextMemoryRiver.new()
	var usage := OpenAiUsage.new()
	usage.prompt_tokens = 64_000
	usage.completion_tokens = 2_000
	effect.on_message_complete(usage)
	assert(is_equal_approx(effect.context_ratio(), 0.5))
	assert(effect.token_label() == "64.0K / 128.0K")
	effect.free()
	pass


static func delivered_item_expires_test() -> void:
	var effect := ContextMemoryRiver.new()
	effect.add_item(ContextMemoryRiver.StreamType.USER, "USER", 0.5)
	effect.visible = true
	effect._process(10.0)
	assert(effect.items.is_empty())
	assert(effect.activity == 1.0)
	effect.free()
	pass


static func saturated_stream_preserves_in_flight_items_test() -> void:
	var effect := ContextMemoryRiver.new()
	for index in range(ContextMemoryRiver.MAX_ITEMS):
		effect.add_item(ContextMemoryRiver.StreamType.REASONING, "THOUGHT", 0.5)
	var oldest := effect.items[0]
	effect.add_item(ContextMemoryRiver.StreamType.REASONING, "NEW", 0.5)
	assert(effect.items.size() == ContextMemoryRiver.MAX_ITEMS)
	assert(effect.items[0] == oldest)
	effect.free()
	pass


static func streaming_fragments_coalesce_test() -> void:
	var effect := ContextMemoryRiver.new()
	effect.add_stream_fragment(ContextMemoryRiver.StreamType.REASONING, "follow", "THOUGHT")
	effect.add_stream_fragment(ContextMemoryRiver.StreamType.REASONING, " path", "THOUGHT")
	assert(effect.items.size() == 1)
	assert(effect.items[0].label == "follow path")
	assert(effect.items[0].glyph_advances.size() == effect.items[0].label.length())
	effect.free()
	pass


static func visible_text_items_are_bounded_test() -> void:
	var effect := ContextMemoryRiver.new()
	for index in range(ContextMemoryRiver.MAX_TEXT_ITEMS + 4):
		effect.add_item(ContextMemoryRiver.StreamType.TOOL, "TOOL %d" % index, 0.5)
	assert(effect.active_text_item_count() == ContextMemoryRiver.MAX_TEXT_ITEMS)
	assert(effect.items.size() == ContextMemoryRiver.MAX_TEXT_ITEMS)
	# Output particles use their own cheap rendering path and remain independent.
	effect.add_item(ContextMemoryRiver.StreamType.ANSWER, "ANSWER", 0.5)
	assert(effect.items.size() == ContextMemoryRiver.MAX_TEXT_ITEMS + 1)
	effect.free()
	pass


static func absorption_spawns_one_output_mote_test() -> void:
	var effect := ContextMemoryRiver.new()
	effect.add_item(ContextMemoryRiver.StreamType.TOOL, "READ", 0.5)
	effect.add_absorption_effect(effect.items[0])
	effect.visible = true
	effect._process(ContextMemoryRiver.ABSORPTION_DURATION * 0.51)
	assert(effect.output_motes.size() == 1)
	assert(effect.absorption_effects[0].output_spawned)
	effect.free()
	pass
