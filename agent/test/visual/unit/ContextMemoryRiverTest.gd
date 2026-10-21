extends RefCounted


static func visual_type_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.CONTEXT_MEMORY_RIVER)
	assert(effect is ContextMemoryRiver)
	effect.free()
	pass


static func compaction_entry_maps_to_system_test() -> void:
	var entry := ChatEntry.new(ChatEntry.KIND_COMPACTION, ChatEntry.TITLE_COMPACTION, "summary")
	assert(ContextMemoryRiver.stream_type_for_entry(entry) == ContextMemoryRiver.StreamType.SYSTEM)
	pass


static func thinking_entry_maps_to_thinking_stream_test() -> void:
	var entry := ChatEntry.new(ChatEntry.KIND_THINKING, ChatEntry.TITLE_THINKING, "plan")
	assert(ContextMemoryRiver.stream_type_for_entry(entry) == ContextMemoryRiver.StreamType.THINKING)
	pass


static func tool_name_stream_types_test() -> void:
	assert(ContextMemoryRiver.stream_type_for_tool_name(ReadTool.NAME) == ContextMemoryRiver.StreamType.FILE)
	assert(ContextMemoryRiver.stream_type_for_tool_name(WebSearchTool.NAME) == ContextMemoryRiver.StreamType.WEB)
	assert(ContextMemoryRiver.stream_type_for_tool_name(BashTool.NAME) == ContextMemoryRiver.StreamType.TOOL)
	var web_entry := ChatEntry.new(ChatEntry.KIND_WEB_TOOL, WebFetchTool.NAME, "https://example.com")
	assert(ContextMemoryRiver.stream_type_for_entry(web_entry) == ContextMemoryRiver.StreamType.WEB)
	pass


static func context_usage_test() -> void:
	var effect := ContextMemoryRiver.new()
	var usage := OpenAiUsage.new()
	usage.prompt_tokens = 64_000
	usage.completion_tokens = 2_000
	effect.on_message_complete(1, usage)
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
		effect.add_item(ContextMemoryRiver.StreamType.ANSWER, "ANSWER", 0.5)
	var oldest := effect.items[0]
	effect.add_item(ContextMemoryRiver.StreamType.ANSWER, "NEW", 0.5)
	assert(effect.items.size() == ContextMemoryRiver.MAX_ITEMS)
	assert(effect.items[0] == oldest)
	effect.free()
	pass


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


static func stream_palette_respects_theme_test() -> void:
	var base := ContextMemoryRiver.neon_base_for_type(ContextMemoryRiver.StreamType.USER)
	var original := ThemeColor.current_theme
	ThemeColor.current_theme = ThemeColor.ThemeEnum.DARK
	var dark := VisualColor.appearance_color(base)
	ThemeColor.current_theme = ThemeColor.ThemeEnum.LIGHT
	var light := VisualColor.appearance_color(base)
	ThemeColor.current_theme = original
	assert(dark.v >= VisualColor.NEON_VALUE_FLOOR)
	assert(light.v >= VisualColor.LIGHT_INK_VALUE_MIN)
	assert(light.v <= VisualColor.LIGHT_INK_VALUE_MAX)
	pass


static func absorption_spawns_one_output_mote_test() -> void:
	var effect := ContextMemoryRiver.new()
	effect.add_item(ContextMemoryRiver.StreamType.TOOL, "READ", 0.5)
	var item: ContextMemoryRiver.StreamItem = effect.items.pop_front()
	effect.add_absorption_effect(item)
	effect.visible = true
	effect._process(ContextMemoryRiver.ABSORPTION_DURATION * 0.51)
	assert(effect.output_motes.size() == 1)
	assert(effect.absorption_effects[0].output_spawned)
	effect.free()
	pass
