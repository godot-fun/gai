class_name WarpSpeed
extends VisualEffect

## Hyperspace jump (超空间跃迁): a starfield flies at the viewer. Reasoning cruises, streamed
## answers stretch the stars into streaks, and every running tool punches the ship into warp
## toward that tool's corner of the window. A finished tool drops out of warp with a ring of
## light; a failed one jolts the camera red. The end of the run brakes the stars to a halt.

const STAR_COUNT := 340
const NEAR_Z := 0.04
const IDLE_SPEED := 0.05
const CRUISE_SPEED := 0.14
const REASONING_SPEED := 0.2
const MAX_STREAM_BOOST := 0.55
const STREAM_BOOST_GAIN := 6.0
const STREAM_BOOST_DECAY_PER_SECOND := 0.35
const WARP_SPEED := 2.4
const SPEED_RESPONSE := 2.2
const WARP_RESPONSE := 4.5
const STREAK_SECONDS := 0.085
const STEER_SHARE := 0.22
const STEER_RESPONSE := 1.6
const FLASH_DECAY_PER_SECOND := 1.8
const SHAKE_DECAY_PER_SECOND := 2.6
const SHAKE_PX := 9.0
const END_BRAKE_MSEC := 1300
const END_STOP_SPEED := 0.012

var stars: PackedVector3Array = PackedVector3Array()
var speed: float = IDLE_SPEED
var target_speed: float = IDLE_SPEED
var stream_boost: float = 0.0
var reasoning: bool = false
var running: bool = false
var active_tools: Dictionary[String, Vector2] = {}
var steer: Vector2 = Vector2.ZERO
var steer_target: Vector2 = Vector2.ZERO
var jump_flash: float = 0.0
var drop_flash: float = 0.0
var drop_color: Color = Color.WHITE
var shake: float = 0.0
var failure_tint: float = 0.0
var star_color: Color = Color(0.92, 0.95, 1.0)
var accent_color: Color = Color(0.4, 0.7, 1.0)


func _ready() -> void:
	super._ready()
	sync_palette()
	pass


func fade_out_seconds() -> float:
	return 0.5


func on_agent_start(_session_id: int) -> void:
	seed_stars()
	running = true
	reasoning = false
	stream_boost = 0.0
	active_tools.clear()
	steer = Vector2.ZERO
	steer_target = Vector2.ZERO
	jump_flash = 0.0
	drop_flash = 0.0
	shake = 0.0
	failure_tint = 0.0
	speed = IDLE_SPEED
	update_target_speed()
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	running = false
	active_tools.clear()
	steer_target = Vector2.ZERO
	if StringUtils.is_not_blank(error_message):
		failure_tint = 1.0
		shake = 1.0
		flash_drop(Colors.error)
	update_target_speed()
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < END_BRAKE_MSEC and speed > END_STOP_SPEED:
		await get_tree().process_frame
	pass


func on_turn_start(_session_id: int) -> void:
	reasoning = false
	update_target_speed()
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	reasoning = stream_kind == OpenAiClient.STREAM_KIND_REASONING
	if not reasoning:
		stream_boost = minf(stream_boost + SimulationEffect.stream_energy_for_length(chunk.length()) * STREAM_BOOST_GAIN, MAX_STREAM_BOOST)
	update_target_speed()
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	active_tools[tool_call_id] = SimulationEffect.tool_anchor(tool_name)
	steer_target = active_tools[tool_call_id] - Vector2(0.5, 0.5)
	jump_flash = 1.0
	update_target_speed()
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	active_tools.erase(tool_call_id)
	if result.is_error:
		failure_tint = 1.0
		shake = 1.0
		flash_drop(Colors.error)
	else:
		flash_drop(accent_color)
	steer_target = active_tools.values().back() - Vector2(0.5, 0.5) if not active_tools.is_empty() else Vector2.ZERO
	update_target_speed()
	pass


func flash_drop(color: Color) -> void:
	drop_flash = 1.0
	drop_color = color
	pass


func update_target_speed() -> void:
	if not running:
		target_speed = 0.0
	elif not active_tools.is_empty():
		target_speed = WARP_SPEED
	else:
		target_speed = (REASONING_SPEED if reasoning else CRUISE_SPEED) + stream_boost
	pass


## 0 while cruising, 1 at full warp.
func warp_amount() -> float:
	return clampf((speed - CRUISE_SPEED - MAX_STREAM_BOOST) / (WARP_SPEED - CRUISE_SPEED - MAX_STREAM_BOOST), 0.0, 1.0)


func _process(delta: float) -> void:
	if not visible:
		return
	step_stars(minf(delta, 1.0 / 20.0))
	queue_redraw()
	pass


func step_stars(delta: float) -> void:
	if stars.is_empty():
		seed_stars()
	if running and stream_boost > 0.0:
		stream_boost = move_toward(stream_boost, 0.0, STREAM_BOOST_DECAY_PER_SECOND * delta)
		update_target_speed()
	var response := WARP_RESPONSE if target_speed > speed else SPEED_RESPONSE
	speed = lerpf(speed, target_speed, 1.0 - exp(-response * delta))
	steer = steer.lerp(steer_target, 1.0 - exp(-STEER_RESPONSE * delta))
	jump_flash = move_toward(jump_flash, 0.0, FLASH_DECAY_PER_SECOND * delta)
	drop_flash = move_toward(drop_flash, 0.0, FLASH_DECAY_PER_SECOND * delta)
	shake = move_toward(shake, 0.0, SHAKE_DECAY_PER_SECOND * delta)
	failure_tint = move_toward(failure_tint, 0.0, 0.8 * delta)
	for index in range(stars.size()):
		var star := stars[index]
		star.z -= speed * delta
		if star.z < NEAR_Z or absf(star.x / star.z) > 2.2 or absf(star.y / star.z) > 2.2:
			star = spawn_star(randf_range(0.75, 1.0))
		stars[index] = star
	pass


func seed_stars() -> void:
	stars.resize(STAR_COUNT)
	for index in range(STAR_COUNT):
		stars[index] = spawn_star(randf_range(NEAR_Z * 2.0, 1.0))
	pass


static func spawn_star(depth: float) -> Vector3:
	var spread := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	while spread.length_squared() < 0.0009:
		spread = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	return Vector3(spread.x, spread.y, depth)


func vanishing_point() -> Vector2:
	var jitter := Vector2.from_angle(randf() * TAU) * shake * shake * SHAKE_PX if shake > 0.0 else Vector2.ZERO
	return size * 0.5 + steer * size * STEER_SHARE + jitter


func project(vanish: Vector2, focal: float, star: Vector3, depth: float) -> Vector2:
	return vanish + Vector2(star.x, star.y) / depth * focal


func _draw() -> void:
	if size.x < 64.0 or size.y < 64.0 or stars.is_empty():
		return
	var vanish := vanishing_point()
	var focal := size.length() * 0.25
	var warp := warp_amount()
	var base := star_color.lerp(Colors.error, failure_tint * 0.7)
	var streak := base.lerp(accent_color, 0.35 + warp * 0.5).lerp(Colors.error, failure_tint * 0.7)
	draw_core_glow(vanish, warp)
	for star: Vector3 in stars:
		var head := project(vanish, focal, star, star.z)
		var tail_depth := minf(star.z + speed * STREAK_SECONDS * (1.0 + warp * 1.6), 1.2)
		var tail := project(vanish, focal, star, tail_depth)
		var nearness := 1.0 - star.z
		var alpha := 0.08 + pow(nearness, 1.2) * 0.86
		var width := lerpf(0.7, 2.8, nearness)
		if head.distance_squared_to(tail) < 2.25:
			draw_circle(head, width * 0.6, VisualColor.stroke(base, alpha))
			continue
		var colors := PackedColorArray([VisualColor.stroke(streak, 0.0), VisualColor.stroke(streak.lerp(base, nearness), alpha)])
		draw_polyline_colors(PackedVector2Array([tail, head]), colors, width, true)
	draw_flash_ring(vanish, jump_flash, accent_color, 0.55)
	draw_flash_ring(vanish, drop_flash, drop_color, 0.4)
	pass


## A small bright eye at the vanishing point while in warp; never a full-surface wash.
func draw_core_glow(vanish: Vector2, warp: float) -> void:
	if warp <= 0.01:
		return
	for ring in range(4):
		var radius := lerpf(110.0, 18.0, float(ring) / 3.0) * (0.7 + warp * 0.3)
		draw_circle(vanish, radius, VisualColor.stroke(accent_color, 0.035 * warp * float(ring + 1)))
	draw_circle(vanish, 5.0 * warp, VisualColor.stroke(star_color, 0.8 * warp))
	pass


func draw_flash_ring(vanish: Vector2, flash: float, color: Color, alpha: float) -> void:
	if flash <= 0.0:
		return
	var grow := 1.0 - flash
	var radius := ease(grow, 0.4) * size.length() * 0.55
	draw_arc(vanish, radius, 0.0, TAU, 96, VisualColor.stroke(color, alpha * flash), 2.0 + 10.0 * flash, true)
	draw_arc(vanish, radius * 0.82, 0.0, TAU, 96, VisualColor.stroke(color, alpha * 0.35 * flash), 1.5, true)
	pass


func sync_palette() -> void:
	star_color = Color(0.92, 0.95, 1.0) if ThemeColor.is_dark_theme() else Colors.primary_text
	accent_color = VisualColor.appearance_color(ThemeColor.accent_theme_color())
	pass
