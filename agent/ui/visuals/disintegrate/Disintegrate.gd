class_name Disintegrate
extends VisualEffect

## Disintegrate (灰飞烟灭): every running tool scorches a small spot of the interface. When the tool
## succeeds the scorch mends; when it fails the spot burns into a ragged hole with an ember edge
## and the consumed content blows away as ash. The next success or the end of the turn runs every
## burn backwards, so the ash flies home and the content reassembles. Streamed text lifts faint
## embers from below. A run that ends in error burns the middle of the screen before mending.

const DISINTEGRATE_SHADER: Shader = preload("res://agent/ui/visuals/disintegrate/Disintegrate.gdshader")
const MAX_BURNS := 4
const SCORCH_RADIUS := 0.06
const SCORCH_PROGRESS := 0.55
const BURN_RADIUS := 0.24
const END_BURN_RADIUS := 0.42
const FULL_PROGRESS := 1.2
const BURN_SPEED := 0.8
const MEND_SPEED := 1.0
const RUN_EMBERS := 0.15
const STREAM_EMBER_GAIN := 5.0
const EMBER_DECAY_PER_SECOND := 0.35
const ERROR_BURN_MSEC := 1100
const END_SETTLE_MSEC := 2200


class Burn extends RefCounted:
	var key: String = ""
	## Screen UV.
	var center: Vector2 = Vector2(0.5, 0.5)
	## Viewport-height units.
	var radius: float = 0.1
	var noise_seed: float = 0.0
	var progress: float = 0.0
	var target: float = 0.0


var surface_rect: ColorRect
var burn_material: ShaderMaterial
var burns: Array[Burn] = []
var embers: float = 0.0
var ember_floor: float = 0.0
var field_time: float = 0.0
var burn_serial: int = 0


func _ready() -> void:
	super._ready()
	surface_rect = ColorRect.new()
	surface_rect.name = "DisintegrateSurface"
	surface_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	burn_material = ShaderMaterial.new()
	burn_material.shader = DISINTEGRATE_SHADER
	surface_rect.material = burn_material
	add_child(surface_rect)
	update_theme_presentation()
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.15


func fade_out_seconds() -> float:
	return 0.35


func on_agent_start(_session_id: int) -> void:
	burns.clear()
	embers = RUN_EMBERS
	ember_floor = RUN_EMBERS
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	ember_floor = 0.0
	if StringUtils.is_not_blank(error_message):
		ignite("end", Vector2(0.5, 0.55), END_BURN_RADIUS, FULL_PROGRESS)
		if is_inside_tree():
			await get_tree().create_timer(ERROR_BURN_MSEC / 1000.0).timeout
	mend_all()
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < END_SETTLE_MSEC and not burns.is_empty():
		await get_tree().process_frame
	pass


func on_turn_end(_session_id: int) -> void:
	mend_all()
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	embers = minf(embers + SimulationEffect.stream_energy_for_length(chunk.length()) * STREAM_EMBER_GAIN, 1.0)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	ignite(tool_call_id, SimulationEffect.tool_anchor(tool_name), SCORCH_RADIUS, SCORCH_PROGRESS)
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	if result.is_error:
		ignite(tool_call_id, SimulationEffect.tool_anchor(tool_name), BURN_RADIUS, FULL_PROGRESS)
	else:
		mend_all()
	pass


## Starts or grows the burn for [param key]. When every slot is busy the oldest burn is dropped.
func ignite(key: String, center: Vector2, radius: float, target: float) -> Burn:
	var burn := find_burn(key)
	if burn == null:
		if burns.size() >= MAX_BURNS:
			burns.remove_at(0)
		burn = Burn.new()
		burn.key = key
		burn.center = center
		burn_serial += 1
		burn.noise_seed = fmod(float(absi(("%s#%d" % [key, burn_serial]).hash())) * 0.001, 1.0)
		burns.append(burn)
	# Growing the radius keeps the scorched core inside the larger hole.
	if radius > burn.radius or burn.progress <= 0.0:
		burn.progress *= burn.radius / radius if burn.radius > 0.0 else 0.0
		burn.radius = radius
	burn.target = target
	return burn


func mend_all() -> void:
	for burn: Burn in burns:
		burn.target = 0.0
	pass


func find_burn(key: String) -> Burn:
	for burn: Burn in burns:
		if burn.key == key:
			return burn
	return null


func _process(delta: float) -> void:
	if not visible:
		return
	step_burns(delta)
	apply_shader_state()
	pass


func step_burns(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	field_time += safe_delta
	embers = move_toward(embers, ember_floor, EMBER_DECAY_PER_SECOND * safe_delta)
	for index in range(burns.size() - 1, -1, -1):
		var burn := burns[index]
		var speed := BURN_SPEED if burn.target > burn.progress else MEND_SPEED
		burn.progress = move_toward(burn.progress, burn.target, speed * safe_delta)
		if burn.target <= 0.0 and burn.progress <= 0.0:
			burns.remove_at(index)
	pass


func apply_shader_state() -> void:
	if burn_material == null:
		return
	var shapes := PackedVector4Array()
	var states := PackedVector4Array()
	shapes.resize(MAX_BURNS)
	states.resize(MAX_BURNS)
	for index in range(burns.size()):
		var burn := burns[index]
		shapes[index] = Vector4(burn.center.x, burn.center.y, burn.radius, burn.noise_seed)
		states[index] = Vector4(burn.progress, BURN_SPEED, 0.0, 0.0)
	burn_material.set_shader_parameter("field_time", field_time)
	burn_material.set_shader_parameter("burn_count", burns.size())
	burn_material.set_shader_parameter("burn_shapes", shapes)
	burn_material.set_shader_parameter("burn_state", states)
	burn_material.set_shader_parameter("ember_level", embers)
	pass


func update_theme_presentation() -> void:
	if burn_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	burn_material.set_shader_parameter("char_color", Color(0.05, 0.04, 0.04) if dark else Color(0.16, 0.13, 0.11))
	burn_material.set_shader_parameter("ash_color", Color(0.45, 0.43, 0.41) if dark else Color(0.35, 0.33, 0.31))
	burn_material.set_shader_parameter("glow_gain", 1.0 if dark else 0.55)
	pass
