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


static func old_context_expires_test() -> void:
	var effect := ContextMemoryRiver.new()
	effect.add_item(ContextMemoryRiver.StreamType.USER, "USER", 0.5)
	effect.on_turn_start()
	effect.on_turn_start()
	effect.on_turn_start()
	assert(effect.items.is_empty())
	effect.free()
	pass
