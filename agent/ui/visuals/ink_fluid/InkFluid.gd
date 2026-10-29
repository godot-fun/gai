class_name InkFluid
extends SimulationEffect

## Two inks are poured into a fluid solved on the GPU beneath the interface. Streamed answers rise
## as warm accent plumes from below, reasoning drifts across the top as cool ink, and every tool
## call stirs a vortex at its own spot. Where the inks meet they cancel; the end of the run thins
## the liquid until it clears.

const FIELD_SHADER: Shader = preload("res://agent/ui/visuals/ink_fluid/InkFluidField.gdshader")
const DISPLAY_SHADER: Shader = preload("res://agent/ui/visuals/ink_fluid/InkFluid.gdshader")
const PRESSURE_ITERATIONS := 10
const PLUME_COST := 0.05
const DRIFT_COST := 0.06
const MAX_POURS_PER_FRAME := 2
const RUN_VELOCITY_DISSIPATION := 0.985
const RUN_INK_DISSIPATION := 0.993
const SETTLE_DISSIPATION := 0.95
const LIGHT_INK_GAIN := 0.8
const DARK_INK_GAIN := 0.7

var content_pour: float = 0.0
var reasoning_pour: float = 0.0
var velocity_dissipation: float = RUN_VELOCITY_DISSIPATION
var ink_dissipation: float = RUN_INK_DISSIPATION


func field_shader() -> Shader:
	return FIELD_SHADER


func display_shader() -> Shader:
	return DISPLAY_SHADER


func pass_kinds() -> PackedInt32Array:
	var kinds := PackedInt32Array([0])
	for _index in range(PRESSURE_ITERATIONS):
		kinds.append(1)
	kinds.append(2)
	return kinds


func activity_decay_per_second() -> float:
	return 0.6


func on_agent_start(session_id: int) -> void:
	super.on_agent_start(session_id)
	content_pour = 0.0
	reasoning_pour = 0.0
	velocity_dissipation = RUN_VELOCITY_DISSIPATION
	ink_dissipation = RUN_INK_DISSIPATION
	queue_impulse(Vector2(0.08, 0.6), 0.05, 0.6, Vector4(3.0, -0.6, 0.0, 0.0))
	queue_impulse(Vector2(0.92, 0.6), 0.05, -0.6, Vector4(-3.0, -0.6, 0.0, 0.0))
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	velocity_dissipation = SETTLE_DISSIPATION
	ink_dissipation = SETTLE_DISSIPATION
	await super.on_agent_end(session_id, error_message)
	pass


func on_turn_start(_session_id: int) -> void:
	queue_impulse(Vector2(0.5, 0.92), 0.06, 0.5, Vector4(0.0, -3.5, 0.0, 0.0))
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		reasoning_pour += energy
	else:
		content_pour += energy * 1.4
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	queue_impulse(Vector2(randf_range(0.3, 0.7), 0.9), 0.05, 0.7, Vector4(0.0, -4.0, 0.0, 0.0))
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	queue_impulse(tool_anchor(tool_name), 0.05, 0.8, Vector4(0.0, 0.0, 3.5, 0.0))
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var anchor := tool_anchor(tool_name)
	if result.is_error:
		failure_tint = 1.0
		for index in range(3):
			var spin := 4.0 if index % 2 == 0 else -4.0
			queue_impulse(anchor + Vector2.from_angle(float(index) * TAU / 3.0) * 0.08, 0.04, 0.9, Vector4(0.0, 0.0, spin, 0.0))
	else:
		queue_impulse(anchor, 0.04, -0.5, Vector4(0.0, 0.0, -3.0, 0.0))
	pass


func step_field(_delta: float) -> void:
	var pours := 0
	while content_pour >= PLUME_COST and pours < MAX_POURS_PER_FRAME:
		content_pour -= PLUME_COST
		pours += 1
		queue_impulse(Vector2(randf_range(0.2, 0.8), 0.94), 0.022, 0.55, Vector4(randf_range(-0.6, 0.6), -3.2, 0.0, 0.0))
	while reasoning_pour >= DRIFT_COST and pours < MAX_POURS_PER_FRAME:
		reasoning_pour -= DRIFT_COST
		pours += 1
		var from_left := randf() < 0.5
		var x := 0.04 if from_left else 0.96
		queue_impulse(Vector2(x, randf_range(0.18, 0.4)), 0.03, -0.5, Vector4(2.6 if from_left else -2.6, 0.3, 0.0, 0.0))
	pass


func apply_field_state() -> void:
	chain.set_param("velocity_dissipation", velocity_dissipation)
	chain.set_param("ink_dissipation", ink_dissipation)
	pass


func update_theme_presentation() -> void:
	if display_material == null:
		return
	var accent := ThemeColor.accent_theme_color()
	var dark := ThemeColor.is_dark_theme()
	display_material.set_shader_parameter("warm_color", VisualColor.appearance_color(accent))
	display_material.set_shader_parameter("cool_color", VisualColor.appearance_color(VisualColor.shift_hsv(accent, 0.33)))
	display_material.set_shader_parameter("error_color", Colors.error)
	display_material.set_shader_parameter("ink_gain", DARK_INK_GAIN if dark else LIGHT_INK_GAIN)
	display_material.set_shader_parameter("glow_blend", 1.0 if dark else 0.0)
	pass
