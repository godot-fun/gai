extends RefCounted


static func source_entries_use_type_labels_test() -> void:
	var effect := ContextMemoryRiver.new()
	var entry := ChatEntry.new(ChatEntry.KIND_USER, ChatEntry.TITLE_USER, "Detailed user prompt that must not become river text.")
	effect.on_chat_entry_add(1, entry)
	assert(effect.items.size() == 1)
	assert(effect.items[0].stream_type == ContextMemoryRiver.StreamType.USER)
	assert(effect.items[0].label == ContextMemoryRiver.label_for_type(ContextMemoryRiver.StreamType.USER))
	effect.free()
	pass


static func streamed_entries_wait_for_transcript_cursor_test() -> void:
	var effect := ContextMemoryRiver.new()
	var thinking := ChatEntry.new(ChatEntry.KIND_THINKING, ChatEntry.TITLE_THINKING, "follow")
	var agent := ChatEntry.new(ChatEntry.KIND_AGENT, ChatEntry.TITLE_AGENT, "answer")
	effect.on_chat_entry_add(1, thinking)
	effect.on_chat_entry_add(1, agent)
	assert(effect.items.is_empty())
	effect.free()
	pass
