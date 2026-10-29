class_name HeatMirage
extends VisualEffect

## The live interface shimmers like heat haze over road: edges refract, streamed answers add drift,
## and tool calls send a rippling shock across the mirage field.

const MIRAGE_SHADER: Shader = preload("res://agent/ui/visuals/heat_mirage/HeatMirage.gdshader")
const MAX_DEFLECTION_PX := 42.0
const TARGET_DECAY_PER_SECOND := 0.36
const FIELD_DECAY_PER_SECOND := 0.42
const DRIVE_FOLLOW_RATE := 3.2
const FLOW_SPEED_MIN := 1.6
const FLOW_SPEED_MAX := 6.8
const SHOCK_SPEED := 0.78
const SHOCK_DECAY_PER_SECOND := 0.48
const IDLE_EPSILON := 0.001
const LIGHT_PRESENTATION_GAIN := 0.52
const LIGHT_FALSE_COLOR_GAIN := 0.34
const FLOW_IDLE_EPSILON := 0.04

var screen_rect: ColorRect
var mirage_material: ShaderMaterial
var mirage_strength: float = 0.0
var flow_strength: float = 0.0
var target_mirage: float = 0.0
var target_flow: float = 0.0
var field_energy: float = 0.0
var flow_phase: float = 0.0
var shock_energy: float = 0.0
var shock_progress: float = 1.2
var shock_angle: float = 0.0
var idle_shader_applied: bool = false


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "HeatMirageSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mirage_material = ShaderMaterial.new()
	mirage_material.shader = MIRAGE_SHADER
	mirage_material.set_shader_parameter("toolbar_height_px", 0.0)
	mirage_material.set_shader_parameter("max_deflection_px", MAX_DEFLECTION_PX)
	screen_rect.material = mirage_material
	add_child(screen_rect)
	gdf.events.theme_changed.connect(update_theme_presentation)
	gdf.events.theme_color_changed.connect(update_theme_presentation)
	update_theme_presentation()
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.12


func fade_out_seconds() -> float:
	return 0.30


func on_agent_start(_session_id: int) -> void:
	reset_mirage_field()
	pulse_field(0.44)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	pulse_field(1.0 if StringUtils.is_not_blank(error_message) else 0.70)
	trigger_shock(1.0 if StringUtils.is_not_blank(error_message) else 0.62, shock_angle + 0.9)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 950 and not mirage_is_idle():
		await get_tree().process_frame
	pass


func on_turn_start(_session_id: int) -> void:
	pulse_field(0.50)
	flow_phase = fmod(flow_phase + 0.85, TAU * 8.0)
	pass


func on_turn_end(_session_id: int) -> void:
	target_mirage = minf(target_mirage, 0.36)
	target_flow = minf(target_flow, 0.32)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var stream_energy := stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		target_mirage = combine_energy(target_mirage, stream_energy * 1.18)
		target_flow = combine_energy(target_flow, stream_energy * 0.22)
	else:
		target_flow = combine_energy(target_flow, stream_energy * 1.05)
		target_mirage = combine_energy(target_mirage, stream_energy * 0.16)
	field_energy = combine_energy(field_energy, stream_energy)
	idle_shader_applied = false
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	pulse_field(0.46)
	target_mirage = minf(target_mirage, 0.40)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	pulse_field(0.84)
	trigger_shock(0.94, angle_for_tool(tool_name))
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	pulse_field(1.0 if result.is_error else 0.64)
	trigger_shock(1.0 if result.is_error else 0.58, angle_for_tool(tool_name) + 0.4)
	pass


func on_chat_entry_add(_session_id: int, _entry: ChatEntry) -> void:
	pulse_field(0.36)
	pass


func _process(delta: float) -> void:
	if not visible:
		idle_shader_applied = false
		return
	step_mirage_field(delta)
	if mirage_is_idle():
		if idle_shader_applied:
			return
		idle_shader_applied = true
	else:
		idle_shader_applied = false
	apply_shader_state()
	pass


func pulse_field(strength: float) -> void:
	field_energy = combine_energy(field_energy, strength)
	idle_shader_applied = false
	pass


func trigger_shock(strength: float, angle: float) -> void:
	if shock_energy <= 0.10 or shock_progress >= 1.08:
		shock_progress = 0.0
	shock_energy = maxf(shock_energy, strength)
	shock_angle = angle
	idle_shader_applied = false
	pass


func step_mirage_field(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var follow := 1.0 - exp(-safe_delta * DRIVE_FOLLOW_RATE)
	mirage_strength = lerpf(mirage_strength, target_mirage, follow)
	flow_strength = lerpf(flow_strength, target_flow, follow)
	target_mirage = move_toward(target_mirage, 0.0, TARGET_DECAY_PER_SECOND * safe_delta)
	target_flow = move_toward(target_flow, 0.0, TARGET_DECAY_PER_SECOND * safe_delta)
	if flow_strength > FLOW_IDLE_EPSILON:
		var flow_speed := lerpf(FLOW_SPEED_MIN, FLOW_SPEED_MAX, flow_strength)
		flow_phase = fmod(flow_phase + safe_delta * flow_speed, TAU * 8.0)
	field_energy = move_toward(field_energy, 0.0, FIELD_DECAY_PER_SECOND * safe_delta)
	if shock_energy > 0.0:
		shock_progress += safe_delta * SHOCK_SPEED
		shock_energy = move_toward(shock_energy, 0.0, SHOCK_DECAY_PER_SECOND * safe_delta)
		if shock_progress >= 1.12:
			shock_progress = 1.2
			shock_energy = 0.0
	snap_idle_scalars()
	pass


func mirage_is_idle() -> bool:
	if shock_energy > IDLE_EPSILON or shock_progress < 1.1:
		return false
	return mirage_strength <= IDLE_EPSILON and flow_strength <= IDLE_EPSILON and target_mirage <= IDLE_EPSILON and target_flow <= IDLE_EPSILON and field_energy <= IDLE_EPSILON


func snap_idle_scalars() -> void:
	if mirage_strength < IDLE_EPSILON:
		mirage_strength = 0.0
	if flow_strength < IDLE_EPSILON:
		flow_strength = 0.0
	if target_mirage < IDLE_EPSILON:
		target_mirage = 0.0
	if target_flow < IDLE_EPSILON:
		target_flow = 0.0
	if field_energy < IDLE_EPSILON:
		field_energy = 0.0
	pass


func apply_shader_state() -> void:
	if mirage_material == null:
		return
	mirage_material.set_shader_parameter("mirage_strength", mirage_strength)
	mirage_material.set_shader_parameter("flow_strength", flow_strength)
	mirage_material.set_shader_parameter("field_energy", field_energy)
	mirage_material.set_shader_parameter("flow_phase", flow_phase)
	mirage_material.set_shader_parameter("shock_energy", shock_energy)
	mirage_material.set_shader_parameter("shock_progress", shock_progress)
	mirage_material.set_shader_parameter("shock_angle", shock_angle)
	pass


func update_theme_presentation() -> void:
	if mirage_material == null:
		return
	var accent := ThemeColor.accent_theme_color()
	if ThemeColor.is_dark_theme():
		mirage_material.set_shader_parameter("accent_color", accent)
		mirage_material.set_shader_parameter("presentation_gain", 1.0)
		mirage_material.set_shader_parameter("false_color_gain", 1.0)
	else:
		mirage_material.set_shader_parameter("accent_color", VisualColor.appearance_color(accent, 0.0, 0.9, 0.95))
		mirage_material.set_shader_parameter("presentation_gain", LIGHT_PRESENTATION_GAIN)
		mirage_material.set_shader_parameter("false_color_gain", LIGHT_FALSE_COLOR_GAIN)
	pass


func reset_mirage_field() -> void:
	mirage_strength = 0.0
	flow_strength = 0.0
	target_mirage = 0.0
	target_flow = 0.0
	field_energy = 0.0
	flow_phase = 0.0
	shock_energy = 0.0
	shock_progress = 1.2
	shock_angle = 0.0
	idle_shader_applied = false
	apply_shader_state()
	pass


static func combine_energy(current: float, incoming: float) -> float:
	var safe_current := clampf(current, 0.0, 1.0)
	var safe_incoming := clampf(incoming, 0.0, 1.0)
	return 1.0 - (1.0 - safe_current) * (1.0 - safe_incoming)


static func stream_energy_for_length(length: int) -> float:
	return clampf(float(length) * 0.0018, 0.004, 0.045)


static func angle_for_tool(tool_name: String) -> float:
	return fmod(float(tool_name.hash()) * 0.0013, TAU)
