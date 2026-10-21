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
