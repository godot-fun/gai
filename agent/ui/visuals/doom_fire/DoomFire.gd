class_name DoomFire
extends SimulationEffect

## Doom fire (毁灭战士火焰): the PSX Doom fire algorithm burns along the bottom of the window.
## Tokens are fuel: reasoning keeps a low bed of flame, streamed answers stoke it high. Every
## running tool burns a taller flare in its own column, a finished tool throws a fireball that
## rises and burns out, and a failed one flares the whole fire toward the error color. When the
## run ends the fuel line goes dark and the fire dies down just like the original title screen.

const FIELD_SHADER: Shader = preload("res://agent/ui/visuals/doom_fire/DoomFireField.gdshader")
const DISPLAY_SHADER: Shader = preload("res://agent/ui/visuals/doom_fire/DoomFire.gdshader")
const PASS_COUNT := 2
const MAX_FLARES := 8
const LOW_DECAY := 0.075
const HIGH_DECAY := 0.016
const RUN_HEIGHT := 0.22
const REASONING_HEIGHT := 0.34
const MAX_HEIGHT_BOOST := 0.75
const HEIGHT_BOOST_GAIN := 7.0
const HEIGHT_BOOST_DECAY_PER_SECOND := 0.28
const HEIGHT_RESPONSE := 2.5
const FLARE_WIDTH := 0.035
const FLARE_RAMP_PER_SECOND := 2.5
const FIREBALL_RADIUS := 0.028
const ERROR_FIREBALL_RADIUS := 0.045


var flares: Dictionary[String, Vector2] = {}
var fuel: float = 0.0
var reasoning: bool = false
var running: bool = false
var height_boost: float = 0.0
var flame_height: float = 0.0


func field_shader() -> Shader:
	return FIELD_SHADER


func display_shader() -> Shader:
	return DISPLAY_SHADER


func pass_kinds() -> PackedInt32Array:
	var kinds := PackedInt32Array()
	kinds.resize(PASS_COUNT)
	for index in range(PASS_COUNT):
		kinds[index] = index
	return kinds


func activity_decay_per_second() -> float:
	return 0.55


func on_agent_start(session_id: int) -> void:
	super.on_agent_start(session_id)
	flares.clear()
	running = true
	reasoning = false
	fuel = 1.0
	height_boost = 0.0
	flame_height = 0.0
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	running = false
	fuel = 0.0
	flares.clear()
	height_boost = 0.0
	if StringUtils.is_not_blank(error_message):
		queue_impulse(Vector2(0.5, 0.86), ERROR_FIREBALL_RADIUS * 1.5, 1.0)
	await super.on_agent_end(session_id, error_message)
	pass


func on_turn_start(_session_id: int) -> void:
	reasoning = false
	height_boost = minf(height_boost + 0.25, MAX_HEIGHT_BOOST)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	reasoning = stream_kind == OpenAiClient.STREAM_KIND_REASONING
	if not reasoning:
		height_boost = minf(height_boost + stream_energy_for_length(chunk.length()) * HEIGHT_BOOST_GAIN, MAX_HEIGHT_BOOST)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	if flares.size() >= MAX_FLARES:
		flares.erase(flares.keys()[0])
	flares[tool_call_id] = Vector2(tool_anchor(tool_name).x, 0.0)
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	flares.erase(tool_call_id)
	var anchor := tool_anchor(tool_name)
	if result.is_error:
		failure_tint = 1.0
		height_boost = MAX_HEIGHT_BOOST
		queue_impulse(Vector2(anchor.x, 0.8), ERROR_FIREBALL_RADIUS, 1.0)
	else:
		queue_impulse(Vector2(anchor.x, 0.84), FIREBALL_RADIUS, 1.0)
	pass


func current_height_target() -> float:
	if not running:
		return flame_height
	return clampf((REASONING_HEIGHT if reasoning else RUN_HEIGHT) + height_boost, 0.0, 1.0)


func current_decay() -> float:
	return lerpf(LOW_DECAY, HIGH_DECAY, flame_height)


func step_field(delta: float) -> void:
	height_boost = move_toward(height_boost, 0.0, HEIGHT_BOOST_DECAY_PER_SECOND * delta)
	flame_height = lerpf(flame_height, current_height_target(), 1.0 - exp(-HEIGHT_RESPONSE * delta))
	for key: String in flares.keys():
		var flare := flares[key]
		flare.y = move_toward(flare.y, 1.0, FLARE_RAMP_PER_SECOND * delta)
		flares[key] = flare
	pass


func apply_field_state() -> void:
	var shapes := PackedVector4Array()
	shapes.resize(MAX_FLARES)
	var index := 0
	for flare: Vector2 in flares.values():
		if index >= MAX_FLARES:
			break
		shapes[index] = Vector4(flare.x, FLARE_WIDTH, flare.y, 0.0)
		index += 1
	chain.set_param("decay", current_decay())
	chain.set_param("fuel", fuel)
	chain.set_param("flare_count", index)
	chain.set_param("flares", shapes)
	display_material.set_shader_parameter("ember_rate", clampf(flame_height * 1.3, 0.0, 1.0) * (1.0 if running else 0.0))
	pass


func update_theme_presentation() -> void:
	if display_material == null:
		return
	display_material.set_shader_parameter("error_color", Colors.error)
	display_material.set_shader_parameter("light_mode", 0.0 if ThemeColor.is_dark_theme() else 1.0)
	pass
