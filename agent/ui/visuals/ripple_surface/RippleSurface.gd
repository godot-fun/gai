class_name RippleSurface
extends SimulationEffect

## The interface lies under a water surface simulated on the GPU. Streamed answers fall as drops
## that march along like a typing caret, reasoning drizzles faint rings, and every tool call is a
## stone thrown at its own spot. Waves interfere, reflect off the window edges, and settle at end.

const FIELD_SHADER: Shader = preload("res://agent/ui/visuals/ripple_surface/RippleSurfaceField.gdshader")
const DISPLAY_SHADER: Shader = preload("res://agent/ui/visuals/ripple_surface/RippleSurface.gdshader")
const PASS_COUNT := 4
const DROP_COST := 0.06
const DRIZZLE_COST := 0.08
const MAX_DROPS_PER_FRAME := 2
const CARET_STEP := 0.034
const RUN_DAMPING := 0.995
const SETTLE_DAMPING := 0.976
const LIGHT_HIGHLIGHT_GAIN := 0.45

var content_rain: float = 0.0
var reasoning_rain: float = 0.0
var caret: Vector2 = Vector2(0.22, 0.7)
var damping: float = RUN_DAMPING


func field_shader() -> Shader:
	return FIELD_SHADER


func display_shader() -> Shader:
	return DISPLAY_SHADER


func pass_kinds() -> PackedInt32Array:
	var kinds := PackedInt32Array()
	kinds.resize(PASS_COUNT)
	return kinds


func field_downscale() -> float:
	return 3.0


func activity_decay_per_second() -> float:
	return 0.7


func on_agent_start(session_id: int) -> void:
	super.on_agent_start(session_id)
	content_rain = 0.0
	reasoning_rain = 0.0
	caret = Vector2(0.22, 0.7)
	damping = RUN_DAMPING
	queue_impulse(Vector2(0.5, 0.55), 0.05, -1.6)
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	damping = SETTLE_DAMPING
	if StringUtils.is_not_blank(error_message):
		queue_impulse(Vector2(0.5, 0.5), 0.06, -2.4)
	await super.on_agent_end(session_id, error_message)
	pass


func on_turn_start(_session_id: int) -> void:
	queue_impulse(Vector2(0.5, 0.5), 0.03, -1.2)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		reasoning_rain += energy
	else:
		content_rain += energy * 1.6
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	queue_impulse(caret, 0.02, -1.0)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	queue_impulse(tool_anchor(tool_name), 0.028, -2.2)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var anchor := tool_anchor(tool_name)
	if result.is_error:
		failure_tint = 1.0
		for index in range(3):
			queue_impulse(anchor + Vector2.from_angle(float(index) * TAU / 3.0) * 0.07, 0.024, -1.8)
	else:
		queue_impulse(anchor, 0.016, 1.1)
	pass


func step_field(_delta: float) -> void:
	var drops := 0
	while content_rain >= DROP_COST and drops < MAX_DROPS_PER_FRAME:
		content_rain -= DROP_COST
		drops += 1
		advance_caret()
		queue_impulse(caret, 0.008, -0.42)
	while reasoning_rain >= DRIZZLE_COST and drops < MAX_DROPS_PER_FRAME:
		reasoning_rain -= DRIZZLE_COST
		drops += 1
		queue_impulse(Vector2(randf_range(0.08, 0.92), randf_range(0.14, 0.55)), 0.006, -0.32)
	pass


## Moves the drop caret like text being typed: left to right, then down a line.
func advance_caret() -> void:
	caret.x += CARET_STEP
	if caret.x > 0.8:
		caret.x = 0.22
		caret.y = 0.62 if caret.y > 0.84 else caret.y + 0.055
	pass


func apply_field_state() -> void:
	chain.set_param("damping", damping)
	pass


func update_theme_presentation() -> void:
	if display_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	display_material.set_shader_parameter("accent_color", VisualColor.appearance_color(ThemeColor.accent_theme_color()))
	display_material.set_shader_parameter("error_color", Colors.error)
	display_material.set_shader_parameter("highlight_gain", 1.0 if dark else LIGHT_HIGHLIGHT_GAIN)
	pass
