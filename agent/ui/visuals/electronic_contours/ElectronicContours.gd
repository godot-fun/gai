class_name ElectronicContours
extends VisualEffect

## Rebuilds the live interface as a deflected electronic raster. Local luminance gradients become
## terrain height, while tool events send a travelling seismic front through the scan field.

const CONTOURS_SHADER: Shader = preload("res://agent/ui/visuals/electronic_contours/ElectronicContours.gdshader")
const TARGET_LINE_SPACING_PX := 8.5
const MIN_LINE_COUNT := 72.0
const MAX_LINE_COUNT := 260.0
const MAX_DEFLECTION_PX := 54.0
const ENERGY_DECAY_PER_SECOND := 0.32
const SPRING_STRENGTH := 48.0
const SPRING_DAMPING := 11.5
const QUAKE_SPEED := 0.72
const QUAKE_DECAY_PER_SECOND := 0.44
const IDLE_EPSILON := 0.001

var screen_rect: ColorRect
var relief_material: ShaderMaterial
var relief_energy: float = 0.0
var relief_amount: float = 0.0
var relief_velocity: float = 0.0
var raster_phase: float = 0.0
var quake_energy: float = 0.0
var quake_progress: float = 1.2
var active_line_count: float = MIN_LINE_COUNT


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "ElectronicContoursSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	relief_material = ShaderMaterial.new()
	relief_material.shader = CONTOURS_SHADER
	relief_material.set_shader_parameter("toolbar_height_px", 0.0)
	relief_material.set_shader_parameter("max_deflection_px", MAX_DEFLECTION_PX)
	relief_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	relief_material.set_shader_parameter("background_color", Colors.app_background)
	screen_rect.material = relief_material
	add_child(screen_rect)
	resized.connect(update_raster_layout)
	update_raster_layout()
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.10


func fade_out_seconds() -> float:
	return 0.34


func on_agent_start(_session_id: int) -> void:
	reset_relief()
	pulse(0.48)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	pulse(1.0 if StringUtils.is_not_blank(error_message) else 0.76)
	trigger_quake(1.0 if StringUtils.is_not_blank(error_message) else 0.64)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 1450 and (relief_energy > 0.08 or relief_amount > 0.06):
		await get_tree().process_frame
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	relief_energy = combine_energy(relief_energy, stream_energy_for_length(chunk.length()))
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	pulse(0.68)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	pulse(0.94)
	trigger_quake(0.92)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	pulse(1.0 if result.is_error else 0.78)
	trigger_quake(1.0 if result.is_error else 0.58)
	pass


func on_chat_entry_add(_session_id: int, _entry: ChatEntry) -> void:
	pulse(0.62)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	step_relief(delta)
	apply_shader_state()
	pass


func pulse(strength: float) -> void:
	relief_energy = combine_energy(relief_energy, strength)
	pass


func trigger_quake(strength: float) -> void:
	if quake_energy <= 0.12 or quake_progress >= 1.1:
		quake_progress = -0.08
	quake_energy = combine_energy(quake_energy, strength)
	pass


func step_relief(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var target_amount := smoothstep(0.025, 0.68, relief_energy)
	var acceleration := (target_amount - relief_amount) * SPRING_STRENGTH - relief_velocity * SPRING_DAMPING
	relief_velocity += acceleration * safe_delta
	relief_amount = clampf(relief_amount + relief_velocity * safe_delta, 0.0, 1.0)
	if relief_amount == 0.0 or relief_amount == 1.0:
		relief_velocity *= 0.48
	raster_phase = fmod(raster_phase + safe_delta * lerpf(0.28, 1.25, relief_amount), TAU * 16.0)
	relief_energy = move_toward(relief_energy, 0.0, ENERGY_DECAY_PER_SECOND * safe_delta)
	quake_progress = minf(quake_progress + safe_delta * QUAKE_SPEED, 1.25)
	quake_energy = move_toward(quake_energy, 0.0, QUAKE_DECAY_PER_SECOND * safe_delta)
	if relief_energy < IDLE_EPSILON:
		relief_energy = 0.0
	if quake_energy < IDLE_EPSILON:
		quake_energy = 0.0
	if relief_energy == 0.0 and relief_amount < IDLE_EPSILON and absf(relief_velocity) < IDLE_EPSILON:
		relief_amount = 0.0
		relief_velocity = 0.0
	pass


func apply_shader_state() -> void:
	if relief_material == null:
		return
	relief_material.set_shader_parameter("relief_amount", relief_amount)
	relief_material.set_shader_parameter("raster_phase", raster_phase)
	relief_material.set_shader_parameter("quake_energy", quake_energy)
	relief_material.set_shader_parameter("quake_progress", quake_progress)
	pass


func update_raster_layout() -> void:
	if relief_material == null or size.y <= 0.0:
		return
	active_line_count = line_count_for_height(size.y)
	relief_material.set_shader_parameter("line_count", active_line_count)
	pass


func reset_relief() -> void:
	relief_energy = 0.0
	relief_amount = 0.0
	relief_velocity = 0.0
	raster_phase = 0.0
	quake_energy = 0.0
	quake_progress = 1.2
	apply_shader_state()
	pass


static func combine_energy(current: float, incoming: float) -> float:
	var safe_current := clampf(current, 0.0, 1.0)
	var safe_incoming := clampf(incoming, 0.0, 1.0)
	return 1.0 - (1.0 - safe_current) * (1.0 - safe_incoming)


static func stream_energy_for_length(length: int) -> float:
	return clampf(float(length) * 0.0017, 0.004, 0.042)


static func line_count_for_height(viewport_height: float) -> float:
	if viewport_height <= 0.0:
		return MIN_LINE_COUNT
	return clampf(roundf(viewport_height / TARGET_LINE_SPACING_PX), MIN_LINE_COUNT, MAX_LINE_COUNT)
