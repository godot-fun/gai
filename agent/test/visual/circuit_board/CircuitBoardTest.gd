extends RefCounted

const CIRCUIT_BOARD_SCRIPT := preload("res://agent/ui/visuals/circuit_board/CircuitBoard.gd")


func visual_type_is_registered_test() -> void:
	var source := FileAccess.get_file_as_string("res://agent/ui/visuals/VisualControl.gd")
	assert(source.contains("\tCIRCUIT_BOARD,"))
	assert(source.contains("Type.CIRCUIT_BOARD:"))
	assert(source.contains("return CIRCUIT_BOARD_SCRIPT.new() as VisualEffect"))
	pass


func stream_and_tool_events_create_pulses_test() -> void:
	var effect := CIRCUIT_BOARD_SCRIPT.new()
	effect.on_agent_start(1)
	assert(effect.traces.size() >= 20)
	assert(effect.components.size() >= 20)
	effect.on_message_update(1, "reason about the next operation", OpenAiClient.STREAM_KIND_REASONING)
	assert(not effect.pulses.is_empty())
	effect.on_tool_execution_start(1, "call-1", "read_file", {})
	assert(effect.pulses.size() >= 2)
	effect.free()
	pass


func translations_exist_test() -> void:
	for locale_path: String in ["res://agent/config/locale/en.json", "res://agent/config/locale/zh.json"]:
		var text := FileAccess.get_file_as_string(locale_path)
		assert(text.contains("\"visual_circuit_board\""))
	pass

