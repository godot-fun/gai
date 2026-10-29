class_name ThermalTrace
extends SimulationEffect

## The interface seen through a thermal camera. Heat comes from real pixel changes between frames,
## so streamed text, scrolling, and new tool cards glow where they actually happen, then cool and
## bleed outward. Tool calls add their own heat at a stable spot; failures flare the whole view.

const FIELD_SHADER: Shader = preload("res://agent/ui/visuals/thermal_trace/ThermalTraceField.gdshader")
const DISPLAY_SHADER: Shader = preload("res://agent/ui/visuals/thermal_trace/ThermalTrace.gdshader")
const PASS_KINDS: PackedInt32Array = [0, 1, 1]
const RUN_COOLING := 0.985
const SETTLE_COOLING := 0.94
const BASE_SENSITIVITY := 3.5
const STREAM_SENSITIVITY := 6.5
const DRIVE_DECAY_PER_SECOND := 0.6
const LIGHT_COLD_GAIN := 0.16
const DARK_COLD_GAIN := 0.3

var stream_drive: float = 0.0
var cooling: float = RUN_COOLING


func field_shader() -> Shader:
	return FIELD_SHADER


func display_shader() -> Shader:
	return DISPLAY_SHADER


func pass_kinds() -> PackedInt32Array:
	return PASS_KINDS


func reads_previous_frame() -> bool:
	return true


func activity_decay_per_second() -> float:
	return 0.6


func on_agent_start(session_id: int) -> void:
	super.on_agent_start(session_id)
	stream_drive = 0.0
	cooling = RUN_COOLING
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	cooling = SETTLE_COOLING
	if StringUtils.is_not_blank(error_message):
		queue_impulse(Vector2(0.5, 0.5), 0.5, 1.2)
	await super.on_agent_end(session_id, error_message)
	pass


func on_turn_start(_session_id: int) -> void:
	queue_impulse(Vector2(0.5, 0.55), 0.12, 0.35)
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	stream_drive = combine_energy(stream_drive, stream_energy_for_length(chunk.length()) * 4.0)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	queue_impulse(tool_anchor(tool_name), 0.04, 0.9)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	if result.is_error:
		failure_tint = 1.0
		queue_impulse(tool_anchor(tool_name), 0.1, 1.3)
	else:
		queue_impulse(tool_anchor(tool_name), 0.025, 0.5)
	pass


func step_field(delta: float) -> void:
	stream_drive = move_toward(stream_drive, 0.0, DRIVE_DECAY_PER_SECOND * delta)
	pass


func current_sensitivity() -> float:
	return lerpf(BASE_SENSITIVITY, STREAM_SENSITIVITY, clampf(stream_drive, 0.0, 1.0))


func apply_field_state() -> void:
	chain.set_param("sensitivity", current_sensitivity())
	chain.set_param("cooling", cooling)
	pass


func update_theme_presentation() -> void:
	if display_material == null:
		return
	display_material.set_shader_parameter("cold_gain", DARK_COLD_GAIN if ThemeColor.is_dark_theme() else LIGHT_COLD_GAIN)
	pass
