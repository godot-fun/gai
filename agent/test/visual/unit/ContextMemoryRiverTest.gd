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
