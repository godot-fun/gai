class_name SnapDissolve
extends VisualEffect

## Snap dissolve (灭霸响指): the live interface crumbles into ash on the wind. Each running tool
## takes a bite out of the window, its grains drifting away while it works, and they fly home
## when it finishes; a failed tool leaves red embers. Streamed text peels loose flakes off the
## ink. When the run ends the whole window is snapped away from right to left, and the fade-out
## brings it back.

const SNAP_SHADER: Shader = preload("res://agent/ui/visuals/snap_dissolve/SnapDissolve.gdshader")
const MAX_ZONES := 8
const ZONE_RADIUS := 0.12
const ZONE_JITTER := 0.05
const DISSOLVE_PER_SECOND := 1.1
const REFORM_PER_SECOND := 0.85
const RED_DECAY_PER_SECOND := 0.25
const FLAKE_GAIN := 8.0
const FLAKE_DECAY_PER_SECOND := 0.6
const END_PROGRESS_MAX := 1.35
const END_SNAP_SECONDS := 1.9
const END_HOLD_MSEC := 250


class Zone extends RefCounted:
	var key: String
	## Center in screen UV.
	var center: Vector2
	## Reach in viewport-height units.
	var radius: float
	var progress: float = 0.0
	var target: float = 1.0
	var red: float = 0.0
	var noise_seed: float = 0.0


var screen_rect: ColorRect
var snap_material: ShaderMaterial
var zones: Array[Zone] = []
var flake_rate: float = 0.0
var end_progress: float = 0.0
var end_target: float = 0.0
var end_red: float = 0.0
var shader_time: float = 0.0


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "SnapSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	snap_material = ShaderMaterial.new()
	snap_material.shader = SNAP_SHADER
	screen_rect.material = snap_material
	add_child(screen_rect)
	update_theme_presentation()
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.12


func fade_out_seconds() -> float:
	return 0.6


func on_agent_start(_session_id: int) -> void:
	zones.clear()
	flake_rate = 0.0
	end_progress = 0.0
	end_target = 0.0
	end_red = 0.0
	apply_shader_state()
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	for zone: Zone in zones:
		zone.target = 0.0
	end_target = END_PROGRESS_MAX
	end_red = 1.0 if StringUtils.is_not_blank(error_message) else 0.0
	if not is_inside_tree():
		return
	var limit_msec := int(END_SNAP_SECONDS * 1000.0) + 400
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < limit_msec and end_progress < END_PROGRESS_MAX:
		await get_tree().process_frame
	await get_tree().create_timer(END_HOLD_MSEC / 1000.0).timeout
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty() or stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		return
	flake_rate = minf(flake_rate + SimulationEffect.stream_energy_for_length(chunk.length()) * FLAKE_GAIN, 1.0)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	if find_zone(tool_call_id) != null:
		return
	make_room_for_zone()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tool_call_id)
	var zone := Zone.new()
	zone.key = tool_call_id
	zone.center = SimulationEffect.tool_anchor(tool_name) + Vector2(rng.randf_range(-ZONE_JITTER, ZONE_JITTER), rng.randf_range(-ZONE_JITTER, ZONE_JITTER))
	zone.radius = ZONE_RADIUS * rng.randf_range(0.8, 1.2)
	zone.noise_seed = rng.randf()
	zones.append(zone)
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	var zone := find_zone(tool_call_id)
	if zone == null:
		return
	zone.target = 0.0
	if result.is_error:
		zone.red = 1.0
	pass


func find_zone(key: String) -> Zone:
	for zone: Zone in zones:
		if zone.key == key:
			return zone
	return null


## Evicts the healing bite closest to whole, or the oldest bite when every tool is still running.
func make_room_for_zone() -> void:
	if zones.size() < MAX_ZONES:
		return
	var evict_index := -1
	for index in range(zones.size()):
		if zones[index].target <= 0.0 and (evict_index < 0 or zones[index].progress < zones[evict_index].progress):
			evict_index = index
	zones.remove_at(evict_index if evict_index >= 0 else 0)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	step_snap(minf(delta, 1.0 / 20.0))
	apply_shader_state()
	pass


func step_snap(delta: float) -> void:
	shader_time += delta
	for index in range(zones.size() - 1, -1, -1):
		var zone := zones[index]
		var rate := DISSOLVE_PER_SECOND if zone.target > zone.progress else REFORM_PER_SECOND
		zone.progress = move_toward(zone.progress, zone.target, rate * delta)
		if zone.target <= 0.0:
			zone.red = move_toward(zone.red, 0.0, RED_DECAY_PER_SECOND * delta)
		if zone.target <= 0.0 and zone.progress <= 0.0:
			zones.remove_at(index)
	flake_rate = move_toward(flake_rate, 0.0, FLAKE_DECAY_PER_SECOND * delta)
	end_progress = move_toward(end_progress, end_target, END_PROGRESS_MAX / END_SNAP_SECONDS * delta)
	pass


func has_work() -> bool:
	return not zones.is_empty() or end_progress > 0.0 or flake_rate > 0.001


func apply_shader_state() -> void:
	if snap_material == null:
		return
	screen_rect.visible = has_work()
	if not screen_rect.visible:
		return
	var shapes := PackedVector4Array()
	var effects := PackedVector4Array()
	shapes.resize(MAX_ZONES)
	effects.resize(MAX_ZONES)
	for index in range(mini(zones.size(), MAX_ZONES)):
		var zone := zones[index]
		shapes[index] = Vector4(zone.center.x, zone.center.y, zone.radius, zone.progress)
		effects[index] = Vector4(zone.red, zone.noise_seed, 0.0, 0.0)
	snap_material.set_shader_parameter("zone_count", mini(zones.size(), MAX_ZONES))
	snap_material.set_shader_parameter("zones", shapes)
	snap_material.set_shader_parameter("zone_fx", effects)
	snap_material.set_shader_parameter("end_progress", end_progress)
	snap_material.set_shader_parameter("end_red", end_red)
	snap_material.set_shader_parameter("flake_rate", flake_rate)
	snap_material.set_shader_parameter("time", shader_time)
	pass


func update_theme_presentation() -> void:
	if snap_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	snap_material.set_shader_parameter("bg_color", Colors.app_background)
	snap_material.set_shader_parameter("light_mode", 0.0 if dark else 1.0)
	snap_material.set_shader_parameter("ash_color", Color(0.62, 0.57, 0.52) if dark else Color(0.30, 0.27, 0.24))
	snap_material.set_shader_parameter("ember_color", Color(1.0, 0.58, 0.22) if dark else Color(0.86, 0.42, 0.12))
	snap_material.set_shader_parameter("error_color", Colors.error)
	pass
