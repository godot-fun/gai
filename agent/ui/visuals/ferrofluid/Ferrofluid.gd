class_name Ferrofluid
extends VisualEffect

## Ferrofluid (磁流体): a pool of magnetic fluid in the active theme accent lines the bottom of the
## interface, its mirror surface reflecting the chat above. Streamed text magnetizes it into
## Rosensweig spikes that lean toward a magnet sweeping along with the stream. A running tool lifts
## a tendril that reaches for the tool's spot and drops back when the tool succeeds; a failed tool
## reverses the field, snaps the tendril and flings droplets that rain back into the pool.

const FERROFLUID_SHADER: Shader = preload("res://agent/ui/visuals/ferrofluid/Ferrofluid.gdshader")
const MAX_DROPLETS := 8
const POOL_PX := 20.0
const MAX_SPIKE_PX := 104.0
const SPIKE_SPACING_PX := 32.0
const RUN_SPIKE := 0.22
const STREAM_SPIKE_GAIN := 6.0
const SPIKE_DECAY_PER_SECOND := 0.4
const POOL_FILL_PER_SECOND := 1.6
const MAGNET_FOLLOW_RATE := 3.0
const MAGNET_DECAY_PER_SECOND := 0.6
const CARET_STEP := 0.004
const TENDRIL_STIFFNESS := 70.0
const TENDRIL_DAMPING := 9.0
const CHAOS_DECAY_PER_SECOND := 0.7
## Viewport heights per second squared.
const GRAVITY := 2.2
const SPLASH_DROPLETS := 2
const FLING_DROPLETS := 6
const END_SETTLE_MSEC := 1600
const IDLE_EPSILON := 0.001


class Droplet extends RefCounted:
	## Screen UV.
	var center: Vector2
	## Viewport heights per second.
	var velocity: Vector2
	var radius_px: float


var surface_rect: ColorRect
var fluid_material: ShaderMaterial
var pool: float = 0.0
var pool_target: float = 0.0
var spike: float = 0.0
var spike_floor: float = 0.0
var magnet_x: float = 0.5
var magnet_target_x: float = 0.5
var magnet_strength: float = 0.0
var caret_x: float = 0.2
var tendril_anchor: Vector2 = Vector2(0.5, 0.5)
var tendril: float = 0.0
var tendril_velocity: float = 0.0
var tendril_goal: float = 0.0
var running_tools: Dictionary[String, Vector2] = {}
var chaos: float = 0.0
var droplets: Array[Droplet] = []
var field_time: float = 0.0


func _ready() -> void:
	super._ready()
	surface_rect = ColorRect.new()
	surface_rect.name = "FerrofluidSurface"
	surface_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fluid_material = ShaderMaterial.new()
	fluid_material.shader = FERROFLUID_SHADER
	fluid_material.set_shader_parameter("spike_spacing_px", SPIKE_SPACING_PX)
	surface_rect.material = fluid_material
	add_child(surface_rect)
	update_theme_presentation()
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.15


func fade_out_seconds() -> float:
	return 0.3


func on_agent_start(_session_id: int) -> void:
	pool = 0.0
	pool_target = 1.0
	spike = 0.0
	spike_floor = RUN_SPIKE
	magnet_strength = 0.4
	tendril = 0.0
	tendril_velocity = 0.0
	tendril_goal = 0.0
	running_tools.clear()
	chaos = 0.0
	droplets.clear()
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	if StringUtils.is_not_blank(error_message):
		fling(Vector2(0.5, 0.85))
	running_tools.clear()
	tendril_goal = 0.0
	spike_floor = 0.0
	pool_target = 0.0
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < END_SETTLE_MSEC and not fluid_is_drained():
		await get_tree().process_frame
	pass


func on_turn_start(_session_id: int) -> void:
	magnet_strength = maxf(magnet_strength, 0.6)
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := SimulationEffect.stream_energy_for_length(chunk.length())
	spike = minf(spike + energy * STREAM_SPIKE_GAIN, 1.0)
	magnet_strength = minf(magnet_strength + energy * 4.0, 1.0)
	caret_x = 0.1 + fposmod(caret_x - 0.1 + CARET_STEP * float(chunk.length()) * 0.25, 0.8)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	var anchor := SimulationEffect.tool_anchor(tool_name)
	running_tools[tool_call_id] = anchor
	tendril_anchor = anchor
	tendril_goal = 1.0
	magnet_strength = 1.0
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	running_tools.erase(tool_call_id)
	if result.is_error:
		fling(tendril_tip())
		chaos = 1.0
		tendril = 0.0
		tendril_velocity = 0.0
	else:
		splash()
	if running_tools.is_empty():
		tendril_goal = 0.0
	else:
		tendril_anchor = running_tools.values()[running_tools.size() - 1]
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	step_fluid(delta)
	apply_shader_state()
	pass


func step_fluid(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	field_time += safe_delta
	pool = move_toward(pool, pool_target, POOL_FILL_PER_SECOND * safe_delta)
	spike = move_toward(spike, spike_floor, SPIKE_DECAY_PER_SECOND * safe_delta)
	if pool_target <= 0.0:
		spike = move_toward(spike, 0.0, SPIKE_DECAY_PER_SECOND * 2.0 * safe_delta)
	chaos = move_toward(chaos, 0.0, CHAOS_DECAY_PER_SECOND * safe_delta)
	magnet_strength = move_toward(magnet_strength, 0.35 if pool_target > 0.0 else 0.0, MAGNET_DECAY_PER_SECOND * safe_delta)
	magnet_target_x = tendril_anchor.x if not running_tools.is_empty() else caret_x
	magnet_x = lerpf(magnet_x, magnet_target_x, 1.0 - exp(-MAGNET_FOLLOW_RATE * safe_delta))
	var accel := -TENDRIL_STIFFNESS * (tendril - tendril_goal) - TENDRIL_DAMPING * tendril_velocity
	tendril_velocity += accel * safe_delta
	tendril = maxf(tendril + tendril_velocity * safe_delta, 0.0)
	if tendril <= 0.0 and tendril_goal <= 0.0 and absf(tendril_velocity) < 0.05:
		tendril_velocity = 0.0
	for index in range(droplets.size() - 1, -1, -1):
		var drop := droplets[index]
		drop.velocity.y += GRAVITY * safe_delta
		drop.center += drop.velocity * safe_delta * Vector2(view_height_ratio(), 1.0)
		if drop.velocity.y > 0.0 and drop.center.y > 1.0 - POOL_PX / maxf(view_size().y, 1.0):
			droplets.remove_at(index)
	pass


func fluid_is_drained() -> bool:
	return pool <= IDLE_EPSILON and tendril <= IDLE_EPSILON and droplets.is_empty()


func tendril_base() -> Vector2:
	return Vector2(tendril_anchor.x, 1.0)


func tendril_tip() -> Vector2:
	return tendril_base().lerp(tendril_anchor, clampf(tendril, 0.0, 1.15))


func splash() -> void:
	var base := tendril_base() - Vector2(0.0, POOL_PX / maxf(view_size().y, 1.0))
	for index in range(SPLASH_DROPLETS):
		spawn_droplet(base, Vector2((float(index) - 0.5) * 0.5, -0.9), 8.0)
	pass


func fling(origin: Vector2) -> void:
	for index in range(FLING_DROPLETS):
		var angle := -PI * 0.5 + (float(index) / float(FLING_DROPLETS - 1) - 0.5) * PI * 0.9
		spawn_droplet(origin, Vector2.from_angle(angle) * randf_range(0.7, 1.2), randf_range(9.0, 16.0))
	pass


func spawn_droplet(center: Vector2, velocity: Vector2, radius_px: float) -> void:
	if droplets.size() >= MAX_DROPLETS:
		droplets.remove_at(0)
	var drop := Droplet.new()
	drop.center = center
	drop.velocity = velocity
	drop.radius_px = radius_px
	droplets.append(drop)
	pass


func view_size() -> Vector2:
	return size if size.y > 0.0 else Vector2(1600.0, 900.0)


## Converts horizontal motion in viewport heights into UV.
func view_height_ratio() -> float:
	var view := view_size()
	return view.y / maxf(view.x, 1.0)


func apply_shader_state() -> void:
	if fluid_material == null:
		return
	var drops := PackedVector4Array()
	drops.resize(MAX_DROPLETS)
	for index in range(droplets.size()):
		drops[index] = Vector4(droplets[index].center.x, droplets[index].center.y, droplets[index].radius_px, 0.0)
	var tip := tendril_tip()
	var base := tendril_base()
	fluid_material.set_shader_parameter("field_time", field_time)
	fluid_material.set_shader_parameter("pool_px", POOL_PX * pool)
	fluid_material.set_shader_parameter("spike_px", MAX_SPIKE_PX * spike * pool)
	fluid_material.set_shader_parameter("magnet_x", magnet_x)
	fluid_material.set_shader_parameter("magnet_strength", magnet_strength)
	fluid_material.set_shader_parameter("chaos", chaos)
	fluid_material.set_shader_parameter("tendril", Vector4(base.x, base.y, tip.x, tip.y))
	fluid_material.set_shader_parameter("droplet_count", droplets.size())
	fluid_material.set_shader_parameter("droplets", drops)
	pass


func update_theme_presentation() -> void:
	if fluid_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	var accent := VisualColor.appearance_color(ThemeColor.accent_theme_color())
	var fluid := accent.darkened(0.82 if dark else 0.72)
	var ambient := fluid.lerp(accent, 0.34)
	var highlight := accent.lerp(Color.WHITE, 0.62 if dark else 0.28)
	fluid_material.set_shader_parameter("fluid_color", fluid)
	fluid_material.set_shader_parameter("ambient_color", ambient)
	fluid_material.set_shader_parameter("rim_color", accent)
	fluid_material.set_shader_parameter("highlight_color", highlight)
	fluid_material.set_shader_parameter("reflection_gain", 0.45 if dark else 0.3)
	fluid_material.set_shader_parameter("shadow_gain", 0.35 if dark else 0.22)
	fluid_material.set_shader_parameter("backlight_gain", 0.32 if dark else 0.0)
	pass
