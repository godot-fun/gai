class_name StainedGlass
extends VisualEffect

## Stained glass (彩绘玻璃): lead came divides the interface into a cathedral window and the run
## fills it with light. Streamed answers light more and more panes in jewel tones, reasoning lets
## clouds drift over the sun, and finished messages flare the whole window. Each tool call lights
## its own pane, which glows when the tool succeeds and cracks into red shards when it fails. The
## end of the run lights every pane at once before the window fades.

const GLASS_SHADER: Shader = preload("res://agent/ui/visuals/stained_glass/StainedGlass.gdshader")
const MAX_PANES := 8
const PANE_MERGE_DISTANCE := 0.02
const START_FILL := 0.1
const RUN_FILL_CAP := 0.85
const FILL_GAIN := 0.18
const FILL_PER_SECOND := 0.35
const CLOUD_GAIN := 4.0
const CLOUD_DECAY_PER_SECOND := 0.35
const SUN_SPEED := 0.05
const FLARE_DECAY_PER_SECOND := 1.1
const HOLD_GLOW := 0.55
const REST_GLOW := 0.25
const GLOW_DECAY_PER_SECOND := 0.8
const FAILURE_DECAY_PER_SECOND := 0.7
const PRESENCE_PER_SECOND := 2.5
const END_SETTLE_MSEC := 1300
const DARK_TINT := 0.5
const LIGHT_TINT := 0.62


class Pane extends RefCounted:
	## Screen UV.
	var center: Vector2
	var glow: float = HOLD_GLOW
	var error: float = 0.0
	var holding: bool = true
	var key: String = ""


var screen_rect: ColorRect
var glass_material: ShaderMaterial
var panes: Array[Pane] = []
var presence: float = 0.0
var presence_target: float = 0.0
var fill: float = 0.0
var fill_target: float = 0.0
var fill_cap: float = RUN_FILL_CAP
var cloud: float = 0.0
var flare: float = 0.0
var failure_tint: float = 0.0
var sun_phase: float = 0.0
var glass_time: float = 0.0


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "GlassWindow"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glass_material = ShaderMaterial.new()
	glass_material.shader = GLASS_SHADER
	screen_rect.material = glass_material
	add_child(screen_rect)
	gdf.events.theme_changed.connect(update_theme_presentation)
	gdf.events.theme_color_changed.connect(update_theme_presentation)
	update_theme_presentation()
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.2


func fade_out_seconds() -> float:
	return 0.5


func on_agent_start(_session_id: int) -> void:
	panes.clear()
	presence_target = 1.0
	fill = 0.0
	fill_target = START_FILL
	fill_cap = RUN_FILL_CAP
	cloud = 0.0
	flare = 0.0
	failure_tint = 0.0
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	fill_cap = 1.0
	fill_target = 1.0
	flare = 1.0
	cloud = 0.0
	for pane: Pane in panes:
		pane.holding = false
	if StringUtils.is_not_blank(error_message):
		failure_tint = 1.0
	if not is_inside_tree():
		presence_target = 0.0
		return
	await get_tree().create_timer(END_SETTLE_MSEC / 1000.0).timeout
	presence_target = 0.0
	pass


func on_turn_start(_session_id: int) -> void:
	sun_phase += 0.6
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := SimulationEffect.stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		cloud = minf(cloud + energy * CLOUD_GAIN, 1.0)
	else:
		fill_target = minf(fill_target + energy * FILL_GAIN, fill_cap)
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	flare = 1.0
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	light_pane(tool_call_id, SimulationEffect.tool_anchor(tool_name))
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var pane := find_pane(tool_call_id)
	if pane == null:
		pane = light_pane(tool_call_id, SimulationEffect.tool_anchor(tool_name))
	pane.holding = false
	pane.glow = 1.0
	if result.is_error:
		pane.error = 1.0
		failure_tint = 1.0
	pass


## Lights the pane under [param center]; a pane already lit at that spot is relit in place.
func light_pane(key: String, center: Vector2) -> Pane:
	for pane: Pane in panes:
		if pane.center.distance_to(center) < PANE_MERGE_DISTANCE:
			pane.key = key
			pane.glow = HOLD_GLOW
			pane.error = 0.0
			pane.holding = true
			return pane
	if panes.size() >= MAX_PANES:
		panes.pop_front()
	var pane := Pane.new()
	pane.center = center
	pane.key = key
	panes.append(pane)
	return pane


func find_pane(key: String) -> Pane:
	for pane: Pane in panes:
		if pane.key == key:
			return pane
	return null


func _process(delta: float) -> void:
	if not visible:
		return
	step_glass(minf(delta, 1.0 / 20.0))
	apply_shader_state()
	pass


func step_glass(delta: float) -> void:
	glass_time += delta
	sun_phase += SUN_SPEED * delta
	presence = move_toward(presence, presence_target, PRESENCE_PER_SECOND * delta)
	fill = move_toward(fill, fill_target, FILL_PER_SECOND * delta)
	cloud = move_toward(cloud, 0.0, CLOUD_DECAY_PER_SECOND * delta)
	flare = move_toward(flare, 0.0, FLARE_DECAY_PER_SECOND * delta)
	failure_tint = move_toward(failure_tint, 0.0, FAILURE_DECAY_PER_SECOND * delta)
	for pane: Pane in panes:
		if pane.holding:
			pane.glow = HOLD_GLOW + 0.2 * sin(glass_time * 5.0)
		else:
			pane.glow = maxf(move_toward(pane.glow, REST_GLOW, GLOW_DECAY_PER_SECOND * delta), REST_GLOW)
	pass


func sun_position() -> Vector2:
	return Vector2(0.5 + 0.38 * sin(sun_phase), 0.12 + 0.06 * cos(sun_phase * 1.3))


func apply_shader_state() -> void:
	if glass_material == null:
		return
	var points := PackedVector4Array()
	points.resize(MAX_PANES)
	for index in range(mini(panes.size(), MAX_PANES)):
		var pane := panes[index]
		points[index] = Vector4(pane.center.x, pane.center.y, pane.glow, pane.error)
	glass_material.set_shader_parameter("pane_count", mini(panes.size(), MAX_PANES))
	glass_material.set_shader_parameter("pane_point", points)
	glass_material.set_shader_parameter("presence", presence)
	glass_material.set_shader_parameter("fill", fill)
	glass_material.set_shader_parameter("cloud", cloud)
	glass_material.set_shader_parameter("flare", flare)
	glass_material.set_shader_parameter("failure_tint", failure_tint)
	glass_material.set_shader_parameter("sun", sun_position())
	glass_material.set_shader_parameter("glass_time", glass_time)
	pass


func update_theme_presentation() -> void:
	if glass_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	glass_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	glass_material.set_shader_parameter("error_color", Colors.error)
	glass_material.set_shader_parameter("tint_strength", DARK_TINT if dark else LIGHT_TINT)
	glass_material.set_shader_parameter("light_mode", 0.0 if dark else 1.0)
	pass
