extends RefCounted


static func visual_type_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.QUANTUM_CIRCUIT))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.QUANTUM_CIRCUIT)
	assert(effect != null)
	assert(effect.get_visual_type() == VisualType.Type.QUANTUM_CIRCUIT)
	effect.free()
	control.free()
	pass


func turn_and_reasoning_create_wire_and_gates_test() -> void:
	var effect := QuantumCircuit.new()
	effect.on_turn_start()
	effect.on_message_update("reason about the next operation", OpenAiClient.STREAM_KIND_REASONING)
	assert(effect.wires.size() == 1)
	assert(bool(effect.active_wire["active"]))
	assert((effect.wires[0]["gates"] as Array).size() >= 1)
	assert(int(effect.active_wire["signal_kind"]) == QuantumCircuit.SignalKind.REASONING)
	effect.on_message_update("answer", OpenAiClient.STREAM_KIND_CONTENT)
	assert(int(effect.active_wire["signal_kind"]) == QuantumCircuit.SignalKind.OUTPUT)
	effect.on_turn_end()
	assert(not bool(effect.active_wire["active"]))
	effect.free()
	pass


func tool_measurement_and_decoherence_test() -> void:
	var effect := QuantumCircuit.new()
	effect.on_turn_start()
	effect.on_tool_execution_start("ok", "read_file", {})
	assert((effect.active_wire["tool_echoes"] as Array).is_empty())
	effect.on_tool_execution_end("ok", "read_file", AgentToolResult.ok("done"))
	assert(int(effect.tool_gates["ok"]["state"]) == QuantumCircuit.GateState.MEASURED)
	assert((effect.active_wire["tool_echoes"] as Array).size() == 1)
	effect.on_tool_execution_start("bad", "write_file", {})
	effect.on_tool_execution_end("bad", "write_file", AgentToolResult.error("failed"))
	assert(int(effect.tool_gates["bad"]["state"]) == QuantumCircuit.GateState.FAILED)
	assert(float(effect.active_wire["decoherence"]) == 1.0)
	effect.free()
	pass


func final_answer_starts_collapse_test() -> void:
	var effect := QuantumCircuit.new()
	effect.on_agent_end("")
	assert(effect.completing)
	assert(not effect.ended_with_error)
	effect.free()
	pass


func palette_follows_accent_theme_color_test() -> void:
	var original: Color = ThemeColor.theme_color
	ThemeColor.theme_color = Color(0.18, 0.52, 0.96)
	ThemeColor.refresh_derived_colors()
	assert(QuantumCircuit.circuit_color() == ThemeColor.accent_theme_color())
	var first_phase := QuantumCircuit.phase_color()
	var first_tool := QuantumCircuit.tool_color()
	assert(first_phase != QuantumCircuit.circuit_color())
	assert(first_tool != QuantumCircuit.circuit_color())
	ThemeColor.theme_color = Color(0.95, 0.3, 0.12)
	ThemeColor.refresh_derived_colors()
	assert(QuantumCircuit.circuit_color() == ThemeColor.accent_theme_color())
	assert(QuantumCircuit.phase_color() != first_phase)
	assert(QuantumCircuit.tool_color() != first_tool)
	ThemeColor.theme_color = original
	ThemeColor.refresh_derived_colors()
	pass


func full_register_replaces_slots_without_reflow_test() -> void:
	var effect := QuantumCircuit.new()
	for index in range(QuantumCircuit.MAX_WIRES):
		effect.on_turn_start()
	var stable_second: Dictionary = effect.wires[1]
	var stable_last: Dictionary = effect.wires[QuantumCircuit.MAX_WIRES - 1]
	effect.on_turn_start()
	assert(effect.wires.size() == QuantumCircuit.MAX_WIRES)
	assert(int(effect.wires[0]["turn"]) == QuantumCircuit.MAX_WIRES + 1)
	assert(effect.wires[1] == stable_second)
	assert(effect.wires[QuantumCircuit.MAX_WIRES - 1] == stable_last)
	effect.on_turn_start()
	assert(int(effect.wires[1]["turn"]) == QuantumCircuit.MAX_WIRES + 2)
	assert(effect.wires[QuantumCircuit.MAX_WIRES - 1] == stable_last)
	effect.free()
	pass
