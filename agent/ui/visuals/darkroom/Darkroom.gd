class_name Darkroom
extends SimulationEffect

## Darkroom (暗房显影): the run happens under a red safelight with the interface as a print in the
## developer tray. The image develops unevenly, strongest detail first, and every turn slides in a
## fresh sheet that has to develop again. Streamed text laps small waves along the tray, tools
## rock it from alternating sides, and a failed tool fogs the paper with a light leak. When the
## run ends the room lights come on and the print returns to full color.

const FIELD_SHADER: Shader = preload("res://agent/ui/visuals/darkroom/DarkroomField.gdshader")
const DISPLAY_SHADER: Shader = preload("res://agent/ui/visuals/darkroom/Darkroom.gdshader")
const PASS_KINDS: PackedInt32Array = [0, 0]
const START_DEVELOP := 0.22
const DEVELOP_PER_SECOND := 0.16
const STREAM_DEVELOP_GAIN := 6.0
const MAX_DEVELOP_BOOST := 1.5
const DEVELOP_BOOST_DECAY_PER_SECOND := 0.8
const SHEET_BLEACH_PER_SECOND := 1.2
const SHEET_BLEACH_SECONDS := 0.5
const BLEACH_FLOOR := 0.2
const LIGHTS_PER_SECOND := 1.4
const LEAK_DECAY_PER_SECOND := 0.3
const LAP_THRESHOLD := 0.04
const MAX_LAPS_PER_FRAME := 2
const ROCK_RADIUS := 0.32
const ROCK_AMOUNT := 0.9
const LIGHT_EXPOSURE := 0.6

var develop_boost: float = 0.0
var bleach_seconds: float = 0.0
var lights: float = 1.0
var lights_target: float = 1.0
var leak: float = 0.0
var leak_position: Vector2 = Vector2(0.5, 0.5)
var rock_side: float = -1.0
var lap_energy: float = 0.0
var frame_delta: float = 0.0


func field_shader() -> Shader:
	return FIELD_SHADER


func display_shader() -> Shader:
	return DISPLAY_SHADER


func pass_kinds() -> PackedInt32Array:
	return PASS_KINDS


func activity_decay_per_second() -> float:
	return 0.6


func on_agent_start(session_id: int) -> void:
	super.on_agent_start(session_id)
	develop_boost = 0.0
	bleach_seconds = 0.0
	lights_target = 0.0
	leak = 0.0
	lap_energy = 0.0
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	if StringUtils.is_not_blank(error_message):
		start_leak(Vector2(0.5, 0.5))
	lights_target = 1.0
	await super.on_agent_end(session_id, error_message)
	pass


func on_turn_start(_session_id: int) -> void:
	bleach_seconds = SHEET_BLEACH_SECONDS
	queue_impulse(Vector2(0.5, 1.0), 0.3, 0.6)
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := stream_energy_for_length(chunk.length())
	lap_energy += energy
	develop_boost = minf(develop_boost + energy * STREAM_DEVELOP_GAIN, MAX_DEVELOP_BOOST)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	var edge_x := 0.0 if rock_side < 0.0 else 1.0
	queue_impulse(Vector2(edge_x, 0.6), ROCK_RADIUS, ROCK_AMOUNT)
	rock_side = -rock_side
	bump_activity(0.5)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	if result.is_error:
		start_leak(tool_anchor(tool_name))
	else:
		queue_impulse(tool_anchor(tool_name), 0.05, -0.5)
		develop_boost = minf(develop_boost + 0.4, MAX_DEVELOP_BOOST)
	pass


func start_leak(position: Vector2) -> void:
	leak = 1.0
	leak_position = position
	failure_tint = 1.0
	pass


func step_field(delta: float) -> void:
	frame_delta = delta
	bleach_seconds = maxf(bleach_seconds - delta, 0.0)
	develop_boost = move_toward(develop_boost, 0.0, DEVELOP_BOOST_DECAY_PER_SECOND * delta)
	lights = move_toward(lights, lights_target, LIGHTS_PER_SECOND * delta)
	leak = move_toward(leak, 0.0, LEAK_DECAY_PER_SECOND * delta)
	var laps := 0
	while lap_energy >= LAP_THRESHOLD and laps < MAX_LAPS_PER_FRAME:
		lap_energy -= LAP_THRESHOLD
		queue_impulse(Vector2(randf_range(0.12, 0.88), 0.93), 0.025, -0.35)
		laps += 1
	lap_energy = minf(lap_energy, LAP_THRESHOLD * 4.0)
	pass


func apply_field_state() -> void:
	var passes := float(PASS_KINDS.size())
	var develop_rate := DEVELOP_PER_SECOND * (1.0 + develop_boost) if lights_target < 1.0 else 0.0
	chain.set_param("develop_step", develop_rate * frame_delta / passes)
	chain.set_param("bleach_step", SHEET_BLEACH_PER_SECOND * frame_delta / passes if bleach_seconds > 0.0 else 0.0)
	chain.set_param("bleach_floor", BLEACH_FLOOR)
	chain.set_param("start_develop", START_DEVELOP)
	display_material.set_shader_parameter("lights", lights)
	display_material.set_shader_parameter("leak", leak)
	display_material.set_shader_parameter("leak_position", leak_position)
	display_material.set_shader_parameter("field_cell_px", field_downscale())
	pass


func update_theme_presentation() -> void:
	if display_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	display_material.set_shader_parameter("paper_color", Colors.app_background)
	display_material.set_shader_parameter("exposure", 1.0 if dark else LIGHT_EXPOSURE)
	display_material.set_shader_parameter("leak_color", Color(1.0, 0.62, 0.28))
	pass
