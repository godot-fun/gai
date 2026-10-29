class_name HoloFoil
extends VisualEffect

## Holographic foil (全息镭射膜): the interface is laminated with a diffraction-grating foil like a
## security sticker. Streamed text keeps nudging the card so the rainbow mosaic and glitter shift
## with every chunk; turns and finished messages roll a bright band across. Each tool call is
## stamped as a guilloche hologram seal at its own spot that flashes when the tool succeeds and
## cracks red when it fails. The end of the run rolls one last band and lets the foil fade.

const HOLO_SHADER: Shader = preload("res://agent/ui/visuals/holo_foil/HoloFoil.gdshader")
const MAX_SEALS := 8
const SEAL_RADIUS := 0.075
const SEAL_MERGE_DISTANCE := 0.02
const STAMP_PER_SECOND := 3.2
const GLOW_DECAY_PER_SECOND := 0.9
const SEAL_REST_GLOW := 0.3
const RUN_SHEEN := 0.45
const MAX_SHEEN := 1.0
const SHEEN_DECAY_PER_SECOND := 0.35
const STREAM_SHEEN_GAIN := 3.0
const STREAM_KICK_GAIN := 9.0
const TILT_STIFFNESS := 9.0
const TILT_DAMPING := 3.2
const DRIFT_AMPLITUDE := 0.55
const SWEEP_PER_SECOND := 1.1
const PRESENCE_PER_SECOND := 3.0
const FAILURE_DECAY_PER_SECOND := 0.8
const END_SETTLE_MSEC := 1400
const DARK_BASE_GAIN := 0.07
const LIGHT_BASE_GAIN := 0.09


class Seal extends RefCounted:
	var center: Vector2
	var radius: float
	var noise_seed: float
	var stamp: float = 0.0
	var glow: float = 1.0
	var error: float = 0.0
	var age: float = 0.0
	var key: String = ""


var screen_rect: ColorRect
var holo_material: ShaderMaterial
var seals: Array[Seal] = []
var presence: float = 0.0
var presence_target: float = 0.0
var sheen: float = 0.0
var sheen_floor: float = 0.0
var tilt: Vector2 = Vector2.ZERO
var tilt_velocity: Vector2 = Vector2.ZERO
var sweep: float = -1.0
var foil_time: float = 0.0
var failure_tint: float = 0.0


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "HoloSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holo_material = ShaderMaterial.new()
	holo_material.shader = HOLO_SHADER
	holo_material.set_shader_parameter("toolbar_height_px", float(AgentLayout.TOOLBAR_HEIGHT))
	screen_rect.material = holo_material
	add_child(screen_rect)
	gdf.events.theme_changed.connect(update_theme_presentation)
	gdf.events.theme_color_changed.connect(update_theme_presentation)
	update_theme_presentation()
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.2


func fade_out_seconds() -> float:
	return 0.45


func on_agent_start(_session_id: int) -> void:
	seals.clear()
	presence_target = 1.0
	sheen_floor = RUN_SHEEN
	sheen = RUN_SHEEN
	tilt = Vector2.ZERO
	tilt_velocity = Vector2(0.6, -0.4)
	failure_tint = 0.0
	start_sweep()
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	sheen_floor = 0.0
	if StringUtils.is_not_blank(error_message):
		failure_tint = 1.0
	start_sweep()
	if not is_inside_tree():
		presence_target = 0.0
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < END_SETTLE_MSEC and sweep >= 0.0:
		await get_tree().process_frame
	presence_target = 0.0
	pass


func on_turn_start(_session_id: int) -> void:
	start_sweep()
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := SimulationEffect.stream_energy_for_length(chunk.length())
	sheen = minf(sheen + energy * STREAM_SHEEN_GAIN, MAX_SHEEN)
	tilt_velocity += Vector2.from_angle(randf() * TAU) * energy * STREAM_KICK_GAIN
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	start_sweep()
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	stamp_seal(tool_call_id, SimulationEffect.tool_anchor(tool_name))
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var seal := find_seal(tool_call_id)
	if seal == null:
		seal = stamp_seal(tool_call_id, SimulationEffect.tool_anchor(tool_name))
	seal.glow = 1.0
	if result.is_error:
		seal.error = 1.0
		failure_tint = 1.0
		tilt_velocity += Vector2.from_angle(randf() * TAU) * 2.5
	else:
		sheen = minf(sheen + 0.2, MAX_SHEEN)
	pass


## Stamps a new seal at [param center]; a seal already at that spot is restamped in place.
func stamp_seal(key: String, center: Vector2) -> Seal:
	for seal: Seal in seals:
		if seal.center.distance_to(center) < SEAL_MERGE_DISTANCE:
			seal.key = key
			seal.stamp = 0.0
			seal.glow = 1.0
			seal.error = 0.0
			seal.age = 0.0
			return seal
	if seals.size() >= MAX_SEALS:
		seals.pop_front()
	var seal := Seal.new()
	seal.center = center
	seal.radius = SEAL_RADIUS
	seal.noise_seed = float(absi(key.hash()) % 1000) / 1000.0
	seal.key = key
	seals.append(seal)
	return seal


func find_seal(key: String) -> Seal:
	for seal: Seal in seals:
		if seal.key == key:
			return seal
	return null


func start_sweep() -> void:
	sweep = 0.0
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	var safe_delta := minf(delta, 1.0 / 20.0)
	step_foil(safe_delta)
	apply_shader_state()
	pass


func step_foil(delta: float) -> void:
	foil_time += delta
	presence = move_toward(presence, presence_target, PRESENCE_PER_SECOND * delta)
	sheen = maxf(move_toward(sheen, sheen_floor, SHEEN_DECAY_PER_SECOND * delta), sheen_floor)
	var drift := Vector2(sin(foil_time * 0.37), cos(foil_time * 0.29)) * DRIFT_AMPLITUDE
	tilt_velocity += (-(tilt - drift) * TILT_STIFFNESS - tilt_velocity * TILT_DAMPING) * delta
	tilt += tilt_velocity * delta
	if sweep >= 0.0:
		sweep += SWEEP_PER_SECOND * delta
		if sweep > 1.0:
			sweep = -1.0
	failure_tint = move_toward(failure_tint, 0.0, FAILURE_DECAY_PER_SECOND * delta)
	for seal: Seal in seals:
		seal.stamp = minf(seal.stamp + STAMP_PER_SECOND * delta, 1.0)
		seal.glow = maxf(move_toward(seal.glow, SEAL_REST_GLOW, GLOW_DECAY_PER_SECOND * delta), SEAL_REST_GLOW)
		seal.age += delta
	pass


func apply_shader_state() -> void:
	if holo_material == null:
		return
	var shapes := PackedVector4Array()
	var states := PackedVector4Array()
	shapes.resize(MAX_SEALS)
	states.resize(MAX_SEALS)
	for index in range(mini(seals.size(), MAX_SEALS)):
		var seal := seals[index]
		shapes[index] = Vector4(seal.center.x, seal.center.y, seal.radius, seal.noise_seed)
		states[index] = Vector4(seal.stamp, seal.glow, seal.error, seal.age)
	holo_material.set_shader_parameter("seal_count", mini(seals.size(), MAX_SEALS))
	holo_material.set_shader_parameter("seal_shape", shapes)
	holo_material.set_shader_parameter("seal_state", states)
	holo_material.set_shader_parameter("presence", presence)
	holo_material.set_shader_parameter("sheen", sheen)
	holo_material.set_shader_parameter("tilt", tilt)
	holo_material.set_shader_parameter("sweep", sweep)
	holo_material.set_shader_parameter("foil_time", foil_time)
	holo_material.set_shader_parameter("failure_tint", failure_tint)
	pass


func update_theme_presentation() -> void:
	if holo_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	holo_material.set_shader_parameter("error_color", Colors.error)
	holo_material.set_shader_parameter("base_gain", DARK_BASE_GAIN if dark else LIGHT_BASE_GAIN)
	holo_material.set_shader_parameter("light_mode", 0.0 if dark else 1.0)
	pass
