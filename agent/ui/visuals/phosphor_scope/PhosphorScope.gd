class_name PhosphorScope
extends VisualEffect

## The live interface becomes a phosphor oscilloscope faceplate. Reasoning pulls the beam
## horizontally, streamed answers pull it vertically, and tool calls flash brighter afterglow.

const SCOPE_SHADER: Shader = preload("res://agent/ui/visuals/phosphor_scope/PhosphorScope.gdshader")
const MAX_OFFSET_PX := 50.0
const TARGET_DECAY_PER_SECOND := 0.38
const BEAM_DECAY_PER_SECOND := 0.44
const DRIVE_FOLLOW_RATE := 3.4
const PHOSPHOR_BURST_DECAY_PER_SECOND := 2.6
const FAILURE_DECAY_PER_SECOND := 3.4
const IDLE_EPSILON := 0.001
const FREQUENCY_RATIOS: Array[float] = [1.5, 1.25]
const LIGHT_PHOSPHOR_GAIN := 0.34
const LIGHT_OVERLAY_GAIN := 0.46

var screen_rect: ColorRect
var scope_material: ShaderMaterial
var reasoning_drive: float = 0.0
var content_drive: float = 0.0
var target_reasoning_drive: float = 0.0
var target_content_drive: float = 0.0
var beam_energy: float = 0.0
var beam_phase: float = 0.0
var phosphor_burst: float = 0.0
var failure_tint: float = 0.0
var frequency_ratio_index: int = 0
var phase_direction: float = 1.0
var idle_shader_applied: bool = false


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "PhosphorScopeSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_material = ShaderMaterial.new()
	scope_material.shader = SCOPE_SHADER
	scope_material.set_shader_parameter("toolbar_height_px", float(AgentLayout.TOOLBAR_HEIGHT))
	scope_material.set_shader_parameter("max_offset_px", MAX_OFFSET_PX)
	screen_rect.material = scope_material
	update_theme_colors()
	add_child(screen_rect)
	gdf.events.theme_changed.connect(update_theme_colors)
	gdf.events.theme_color_changed.connect(update_theme_colors)
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.14


func fade_out_seconds() -> float:
	return 0.28


func on_agent_start(_session_id: int) -> void:
	reset_scope_field()
	pulse_beam(0.42)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	pulse_beam(1.0 if StringUtils.is_not_blank(error_message) else 0.68)
	if StringUtils.is_not_blank(error_message):
		failure_tint = 1.0
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 900 and not scope_is_idle():
		await get_tree().process_frame
	pass


func on_turn_start(_session_id: int) -> void:
	frequency_ratio_index = 1 - frequency_ratio_index
	phase_direction *= -1.0
	pulse_beam(0.52)
	pass


func on_turn_end(_session_id: int) -> void:
	target_reasoning_drive = minf(target_reasoning_drive, 0.35)
	target_content_drive = minf(target_content_drive, 0.35)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var stream_energy := stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		target_reasoning_drive = combine_energy(target_reasoning_drive, stream_energy * 1.15)
		target_content_drive = combine_energy(target_content_drive, stream_energy * 0.18)
	else:
		target_content_drive = combine_energy(target_content_drive, stream_energy * 1.08)
		target_reasoning_drive = combine_energy(target_reasoning_drive, stream_energy * 0.14)
	beam_energy = combine_energy(beam_energy, stream_energy)
	idle_shader_applied = false
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	pulse_beam(0.48)
	target_reasoning_drive = minf(target_reasoning_drive, 0.42)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	pulse_beam(0.82)
	phosphor_burst = 1.0
	beam_phase = fmod(beam_phase + phase_kick_for_tool(tool_name), TAU * 8.0)
	idle_shader_applied = false
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	pulse_beam(1.0 if result.is_error else 0.62)
	phosphor_burst = 1.0
	if result.is_error:
		failure_tint = 1.0
	idle_shader_applied = false
	pass


func _process(delta: float) -> void:
	if not visible:
		idle_shader_applied = false
		return
	step_scope_field(delta)
	if scope_is_idle():
		if idle_shader_applied:
			return
		idle_shader_applied = true
	else:
		idle_shader_applied = false
	apply_shader_state()
	pass


func pulse_beam(strength: float) -> void:
	beam_energy = combine_energy(beam_energy, strength)
	idle_shader_applied = false
	pass


func step_scope_field(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var follow := 1.0 - exp(-safe_delta * DRIVE_FOLLOW_RATE)
	reasoning_drive = lerpf(reasoning_drive, target_reasoning_drive, follow)
	content_drive = lerpf(content_drive, target_content_drive, follow)
	target_reasoning_drive = move_toward(target_reasoning_drive, 0.0, TARGET_DECAY_PER_SECOND * safe_delta)
	target_content_drive = move_toward(target_content_drive, 0.0, TARGET_DECAY_PER_SECOND * safe_delta)
	var motion := maxf(reasoning_drive, content_drive)
	var phase_speed := phase_speed_for_motion(motion) * phase_direction
	beam_phase = fmod(beam_phase + safe_delta * phase_speed, TAU * 8.0)
	beam_energy = move_toward(beam_energy, 0.0, BEAM_DECAY_PER_SECOND * safe_delta)
	phosphor_burst = move_toward(phosphor_burst, 0.0, PHOSPHOR_BURST_DECAY_PER_SECOND * safe_delta)
	failure_tint = move_toward(failure_tint, 0.0, FAILURE_DECAY_PER_SECOND * safe_delta)
	snap_idle_scalars()
	pass


func scope_is_idle() -> bool:
	return reasoning_drive <= IDLE_EPSILON and content_drive <= IDLE_EPSILON and target_reasoning_drive <= IDLE_EPSILON and target_content_drive <= IDLE_EPSILON and beam_energy <= IDLE_EPSILON and phosphor_burst <= IDLE_EPSILON and failure_tint <= IDLE_EPSILON


func snap_idle_scalars() -> void:
	if reasoning_drive < IDLE_EPSILON:
		reasoning_drive = 0.0
	if content_drive < IDLE_EPSILON:
		content_drive = 0.0
	if target_reasoning_drive < IDLE_EPSILON:
		target_reasoning_drive = 0.0
	if target_content_drive < IDLE_EPSILON:
		target_content_drive = 0.0
	if beam_energy < IDLE_EPSILON:
		beam_energy = 0.0
	pass


func apply_shader_state() -> void:
	if scope_material == null:
		return
	scope_material.set_shader_parameter("reasoning_drive", reasoning_drive)
	scope_material.set_shader_parameter("content_drive", content_drive)
	scope_material.set_shader_parameter("beam_energy", beam_energy)
	scope_material.set_shader_parameter("beam_phase", beam_phase)
	scope_material.set_shader_parameter("frequency_ratio", FREQUENCY_RATIOS[frequency_ratio_index])
	scope_material.set_shader_parameter("phosphor_burst", phosphor_burst)
	scope_material.set_shader_parameter("failure_tint", failure_tint)
	pass


func update_theme_colors() -> void:
	if scope_material == null:
		return
	var accent := ThemeColor.accent_theme_color()
	var error := Colors.error
	if ThemeColor.is_dark_theme():
		scope_material.set_shader_parameter("accent_color", accent)
		scope_material.set_shader_parameter("error_color", error)
		scope_material.set_shader_parameter("phosphor_gain", 1.0)
		scope_material.set_shader_parameter("overlay_gain", 1.0)
	else:
		scope_material.set_shader_parameter("accent_color", VisualColor.appearance_color(accent, 0.02, 0.88, 0.92))
		scope_material.set_shader_parameter("error_color", VisualColor.appearance_color(error, 0.0, 1.0, 1.0))
		scope_material.set_shader_parameter("phosphor_gain", LIGHT_PHOSPHOR_GAIN)
		scope_material.set_shader_parameter("overlay_gain", LIGHT_OVERLAY_GAIN)
	pass


func reset_scope_field() -> void:
	reasoning_drive = 0.0
	content_drive = 0.0
	target_reasoning_drive = 0.0
	target_content_drive = 0.0
	beam_energy = 0.0
	beam_phase = 0.0
	phosphor_burst = 0.0
	failure_tint = 0.0
	frequency_ratio_index = 0
	phase_direction = 1.0
	idle_shader_applied = false
	apply_shader_state()
	pass


static func combine_energy(current: float, incoming: float) -> float:
	var safe_current := clampf(current, 0.0, 1.0)
	var safe_incoming := clampf(incoming, 0.0, 1.0)
	return 1.0 - (1.0 - safe_current) * (1.0 - safe_incoming)


static func stream_energy_for_length(length: int) -> float:
	return clampf(float(length) * 0.0018, 0.004, 0.045)


static func phase_speed_for_motion(motion: float) -> float:
	return lerpf(0.0, 8.4, clampf(motion, 0.0, 1.0))


static func phase_kick_for_tool(tool_name: String) -> float:
	return fmod(float(tool_name.hash()) * 0.0011, TAU)


static func beam_channels(phase: float, frequency_ratio: float, reasoning: float, content: float, beam: float) -> Vector2:
	var bundle := maxf(maxi(reasoning, content), beam * 0.58)
	var x_ch := sin(phase) * reasoning + sin(phase * 2.0 + 0.4) * content * 0.62 + cos(phase) * bundle * 0.32
	var y_ch := sin(phase * frequency_ratio + 0.72) * content + cos(phase * frequency_ratio * 0.5) * reasoning * 0.62 + sin(phase * 0.5) * bundle * 0.30
	return Vector2(x_ch, y_ch)


static func beam_offset(phase: float, frequency_ratio: float, reasoning: float, content: float, max_offset_px: float, beam: float = 0.0) -> Vector2:
	return beam_channels(phase, frequency_ratio, reasoning, content, beam) * max_offset_px
