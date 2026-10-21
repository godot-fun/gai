extends RefCounted


static func drain_complete_sentences_test() -> void:
	var effect := ContextMemoryRiver.new()
	assert(effect.drain_complete_sentences(ContextMemoryRiver.StreamType.THINKING, "First. Second.") == "")
	assert(effect.items.size() == 2)
	assert(effect.items[0].label == "First.")
	assert(effect.items[1].label == "Second.")
	assert(effect.drain_complete_sentences(ContextMemoryRiver.StreamType.TOOL, "res://path.gd") == "res://path.gd")
	assert(effect.items.size() == 2)
	effect.free()
	pass


static func streaming_fragments_wait_for_sentence_end_test() -> void:
	var effect := ContextMemoryRiver.new()
	effect.add_stream_fragment(ContextMemoryRiver.StreamType.THINKING, "follow", "THOUGHT")
	assert(effect.items.is_empty())
	effect.add_stream_fragment(ContextMemoryRiver.StreamType.THINKING, " path.", "THOUGHT")
	assert(effect.items.size() == 1)
	assert(effect.items[0].label == "follow path.")
	assert(effect.items[0].glyph_advances.size() == effect.items[0].label.length())
	effect.free()
	pass
