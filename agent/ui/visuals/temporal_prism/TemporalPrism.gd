class_name TemporalPrism
extends VisualEffect

## Reinterprets the horizontal screen axis as staggered time. Invisible vertical slices receive
## different phases of one continuous field, stretching the existing interface without drawing
## scan lines, trails, or generated decoration over it.

const PRISM_SHADER: Shader = preload("res://agent/ui/visuals/temporal_prism/TemporalPrism.gdshader")
const TARGET_SLICE_WIDTH_PX := 38.0
const MIN_SLICE_COUNT := 28.0
const MAX_SLICE_COUNT := 96.0
const MAX_OFFSET_PX := 38.0
const ENERGY_DECAY_PER_SECOND := 0.48
const IDLE_EPSILON := 0.001

var screen_rect: ColorRect
var prism_material: ShaderMaterial
var temporal_energy: float = 0.0
var temporal_phase: float = 0.0
var temporal_direction: float = 1.0
var active_slice_count: float = MIN_SLICE_COUNT


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "TemporalPrismSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prism_material = ShaderMaterial.new()
	prism_material.shader = PRISM_SHADER
	prism_material.set_shader_parameter("toolbar_height_px", 0.0)
	prism_material.set_shader_parameter("max_offset_px", MAX_OFFSET_PX)
	prism_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	screen_rect.material = prism_material
	add_child(screen_rect)
	resized.connect(update_slice_layout)
	gdf.events.theme_color_changed.connect(update_accent_color)
	update_slice_layout()
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.12


func fade_out_seconds() -> float:
	return 0.26


func on_agent_start(_session_id: int) -> void:
	reset_temporal_field()
	pulse(0.46)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	pulse(1.0 if StringUtils.is_not_blank(error_message) else 0.72)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 900 and temporal_energy > 0.12:
		await get_tree().process_frame
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	temporal_energy = combine_energy(temporal_energy, stream_energy_for_length(chunk.length()))
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	pulse(0.58)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	pulse(0.86)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	pulse(1.0 if result.is_error else 0.68)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	step_temporal_field(delta)
	apply_shader_state()
	pass


func pulse(strength: float) -> void:
	# Direction changes only when a new temporal phrase begins. Events arriving during an active
	# phrase add energy instead of replacing the current slice choreography.
	if temporal_energy <= 0.12:
		temporal_direction = -temporal_direction
	temporal_energy = combine_energy(temporal_energy, strength)
	pass


func step_temporal_field(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var phase_speed := lerpf(2.4, 7.6, temporal_energy)
	temporal_phase = fmod(temporal_phase + safe_delta * phase_speed, TAU * 8.0)
	temporal_energy = move_toward(temporal_energy, 0.0, ENERGY_DECAY_PER_SECOND * safe_delta)
	if temporal_energy < IDLE_EPSILON:
		temporal_energy = 0.0
	pass


func apply_shader_state() -> void:
	if prism_material == null:
		return
	prism_material.set_shader_parameter("temporal_energy", temporal_energy)
	prism_material.set_shader_parameter("temporal_phase", temporal_phase)
	prism_material.set_shader_parameter("temporal_direction", temporal_direction)
	pass


func update_accent_color() -> void:
	if prism_material != null:
		prism_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	pass


func update_slice_layout() -> void:
	if prism_material == null or size.x <= 0.0:
		return
	active_slice_count = slice_count_for_width(size.x)
	prism_material.set_shader_parameter("slice_count", active_slice_count)
	pass


func reset_temporal_field() -> void:
	temporal_energy = 0.0
	temporal_phase = 0.0
	temporal_direction = 1.0
	apply_shader_state()
	pass


static func combine_energy(current: float, incoming: float) -> float:
	var safe_current := clampf(current, 0.0, 1.0)
	var safe_incoming := clampf(incoming, 0.0, 1.0)
	return 1.0 - (1.0 - safe_current) * (1.0 - safe_incoming)


static func stream_energy_for_length(length: int) -> float:
	return clampf(float(length) * 0.0018, 0.004, 0.045)


static func slice_count_for_width(viewport_width: float) -> float:
	if viewport_width <= 0.0:
		return MIN_SLICE_COUNT
	return clampf(roundf(viewport_width / TARGET_SLICE_WIDTH_PX), MIN_SLICE_COUNT, MAX_SLICE_COUNT)
