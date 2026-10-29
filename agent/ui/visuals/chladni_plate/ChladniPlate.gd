class_name ChladniPlate
extends SimulationEffect

## Chladni plate (克拉尼图形): the interface is a vibrating plate dusted with sand. Every tool
## rings the plate at its own resonant mode, so grains flow off the antinodes and gather on that
## tool's nodal figure; turns ring the lower, simpler modes. Streamed text drives the plate harder,
## a failed tool scatters the sand, and the end of the run stops the plate with the last figure
## frozen in place.

const FIELD_SHADER: Shader = preload("res://agent/ui/visuals/chladni_plate/ChladniPlateField.gdshader")
const DISPLAY_SHADER: Shader = preload("res://agent/ui/visuals/chladni_plate/ChladniPlate.gdshader")
const PASS_COUNT := 4
## (n, m, sign) modes ordered from simple to dense; turns use the first [constant TURN_MODE_COUNT].
const MODES: Array[Vector3] = [
	Vector3(1, 2, -1), Vector3(1, 3, 1), Vector3(2, 3, -1), Vector3(1, 4, 1), Vector3(2, 4, -1), Vector3(1, 5, -1),
	Vector3(2, 5, 1), Vector3(3, 4, -1), Vector3(3, 5, 1), Vector3(2, 7, -1), Vector3(4, 5, 1), Vector3(3, 7, -1),
	Vector3(5, 6, 1), Vector3(4, 7, -1), Vector3(3, 8, 1), Vector3(5, 8, -1), Vector3(6, 7, 1), Vector3(4, 9, -1),
]
const TURN_MODE_COUNT := 6
const RUN_DRIVE := 0.55
const MAX_DRIVE_BOOST := 0.45
const STREAM_DRIVE_GAIN := 4.0
const REASONING_DRIVE_SCALE := 0.5
const TOOL_SUCCESS_BOOST := 0.2
const DRIVE_BOOST_DECAY_PER_SECOND := 0.5
const DRIVE_RAMP_PER_SECOND := 1.5
const MODE_SWEEP_PER_SECOND := 0.9
const SCATTER_DECAY_PER_SECOND := 1.2
const TOOL_SAND := 0.9
const DARK_SAND_OPACITY := 0.9
const LIGHT_SAND_OPACITY := 0.8

var mode_a: Vector3 = MODES[0]
var mode_b: Vector3 = MODES[0]
var mode_mix: float = 1.0
var base_drive: float = 0.0
var drive_boost: float = 0.0
var drive: float = 0.0
var scatter: float = 0.0
var turn_index: int = 0


func field_shader() -> Shader:
	return FIELD_SHADER


func display_shader() -> Shader:
	return DISPLAY_SHADER


func pass_kinds() -> PackedInt32Array:
	var kinds := PackedInt32Array()
	kinds.resize(PASS_COUNT)
	return kinds


func activity_decay_per_second() -> float:
	return 0.45


func on_agent_start(session_id: int) -> void:
	super.on_agent_start(session_id)
	mode_a = MODES[0]
	mode_b = MODES[0]
	mode_mix = 1.0
	base_drive = RUN_DRIVE
	drive_boost = 0.0
	drive = 0.0
	scatter = 0.0
	turn_index = 0
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	base_drive = 0.0
	drive_boost = 0.0
	if StringUtils.is_not_blank(error_message):
		scatter = 1.0
	await super.on_agent_end(session_id, error_message)
	pass


func on_turn_start(_session_id: int) -> void:
	ring_mode(turn_mode(turn_index))
	turn_index += 1
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := stream_energy_for_length(chunk.length()) * STREAM_DRIVE_GAIN
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		energy *= REASONING_DRIVE_SCALE
	drive_boost = minf(drive_boost + energy, MAX_DRIVE_BOOST)
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	queue_impulse(Vector2(0.5, 0.55), 0.18, 0.25)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	ring_mode(mode_for(tool_name))
	queue_impulse(tool_anchor(tool_name), 0.035, 0.3, Vector4(TOOL_SAND, 0.0, 0.0, 0.0))
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	if result.is_error:
		failure_tint = 1.0
		scatter = 1.0
		queue_impulse(tool_anchor(tool_name), 0.14, 1.0)
	else:
		drive_boost = minf(drive_boost + TOOL_SUCCESS_BOOST, MAX_DRIVE_BOOST)
	pass


## Starts sweeping the plate toward [param mode]. A sweep past halfway commits the current mode
## so the plate never blends more than two figures.
func ring_mode(mode: Vector3) -> void:
	if mode == mode_b:
		return
	if mode_mix >= 0.5:
		mode_a = mode_b
		mode_mix = 0.0
	mode_b = mode
	pass


func step_field(delta: float) -> void:
	mode_mix = move_toward(mode_mix, 1.0, MODE_SWEEP_PER_SECOND * delta)
	drive_boost = move_toward(drive_boost, 0.0, DRIVE_BOOST_DECAY_PER_SECOND * delta)
	drive = move_toward(drive, current_drive_target(), DRIVE_RAMP_PER_SECOND * delta)
	scatter = move_toward(scatter, 0.0, SCATTER_DECAY_PER_SECOND * delta)
	pass


func current_drive_target() -> float:
	return clampf(base_drive + drive_boost, 0.0, 1.0)


func apply_field_state() -> void:
	var viewport_height := get_viewport().get_visible_rect().size.y
	var plate_top := clampf(float(AgentLayout.TOOLBAR_HEIGHT) / viewport_height, 0.0, 0.3) if viewport_height > 0.0 else 0.0
	chain.set_param("mode_a", mode_a)
	chain.set_param("mode_b", mode_b)
	chain.set_param("mode_mix", mode_mix)
	chain.set_param("plate_top", plate_top)
	chain.set_param("drive", drive)
	chain.set_param("scatter", scatter)
	display_material.set_shader_parameter("mode_a", mode_a)
	display_material.set_shader_parameter("mode_b", mode_b)
	display_material.set_shader_parameter("mode_mix", mode_mix)
	display_material.set_shader_parameter("plate_top", plate_top)
	display_material.set_shader_parameter("drive", drive)
	pass


func update_theme_presentation() -> void:
	if display_material == null:
		return
	var accent := VisualColor.appearance_color(ThemeColor.accent_theme_color())
	var dark := ThemeColor.is_dark_theme()
	var sand := accent.lerp(Color(0.97, 0.94, 0.86), 0.7) if dark else accent.lerp(Color(0.16, 0.13, 0.10), 0.72)
	display_material.set_shader_parameter("sand_color", sand)
	display_material.set_shader_parameter("line_color", accent)
	display_material.set_shader_parameter("error_color", Colors.error)
	display_material.set_shader_parameter("sand_opacity", DARK_SAND_OPACITY if dark else LIGHT_SAND_OPACITY)
	pass


## Stable resonant mode for a tool, drawn from the denser modes so tools read apart from turns.
static func mode_for(tool_name: String) -> Vector3:
	return MODES[TURN_MODE_COUNT + absi(tool_name.hash()) % (MODES.size() - TURN_MODE_COUNT)]


static func turn_mode(index: int) -> Vector3:
	return MODES[absi(index) % TURN_MODE_COUNT]
