class_name SoapBubbles
extends VisualEffect

## Soap bubbles (肥皂泡): bubbles float over the interface with live thin-film colors. Streamed
## answers blow new bubbles up from the bottom and stir the films; each tool call inflates a
## bubble at its own spot that pops when the tool succeeds. Films drain and thin while they
## float, darkening at the top before they burst on their own. A failed tool tints every film
## red and bursts them all; the end of the run pops whatever is left, one after another.

const BUBBLE_SHADER: Shader = preload("res://agent/ui/visuals/soap_bubbles/SoapBubbles.gdshader")
const MAX_BUBBLES := 8
const STREAM_RADIUS_MIN := 0.07
const STREAM_RADIUS_MAX := 0.12
const TOOL_RADIUS := 0.085
const TOOL_START_RADIUS := 0.02
const INFLATE_PER_SECOND := 0.12
const LIFETIME_MIN := 9.0
const LIFETIME_MAX := 16.0
const POP_PER_SECOND := 3.6
const END_POP_STAGGER := 0.12
const BUOYANCY := 0.014
const RISE_SPEED := 0.09
const WANDER := 0.014
const DAMPING_PER_SECOND := 0.6
const GUST_SPEED := 0.12
const SPAWN_GAIN := 4.0
const TURBULENCE_GAIN := 5.0
const TURBULENCE_DECAY_PER_SECOND := 0.25
const RUN_TURBULENCE := 0.2
const END_SETTLE_MSEC := 1800
const DEFAULT_ASPECT := 16.0 / 9.0
const DARK_FILM_GAIN := 1.05
const LIGHT_FILM_GAIN := 1.25


class Bubble extends RefCounted:
	## Center in viewport-height units: x in [0, aspect], y in [0, 1].
	var position: Vector2
	var velocity: Vector2 = Vector2.ZERO
	var radius: float
	var target_radius: float
	var noise_seed: float
	var age: float = 0.0
	var lifetime: float
	var pop: float = -1.0
	var pop_delay: float = -1.0
	var pop_angle: float = 0.0
	var error: float = 0.0
	var key: String = ""


var screen_rect: ColorRect
var bubble_material: ShaderMaterial
var bubbles: Array[Bubble] = []
var turbulence: float = 0.0
var turbulence_floor: float = 0.0
var spawn_budget: float = 0.0
var bubble_time: float = 0.0
var spawning: bool = false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "BubbleSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble_material = ShaderMaterial.new()
	bubble_material.shader = BUBBLE_SHADER
	bubble_material.set_shader_parameter("toolbar_height_px", float(AgentLayout.TOOLBAR_HEIGHT))
	screen_rect.material = bubble_material
	add_child(screen_rect)
	update_theme_presentation()
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.2


func fade_out_seconds() -> float:
	return 0.4


func on_agent_start(_session_id: int) -> void:
	bubbles.clear()
	spawning = true
	turbulence_floor = RUN_TURBULENCE
	turbulence = RUN_TURBULENCE
	spawn_budget = 0.0
	for index in range(3):
		var bubble := spawn_rising(rng.randf_range(STREAM_RADIUS_MIN, STREAM_RADIUS_MAX))
		if bubble != null:
			bubble.position.y -= float(index) * 0.18
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	spawning = false
	turbulence_floor = 0.0
	var tint := 1.0 if StringUtils.is_not_blank(error_message) else 0.0
	var delay := 0.0
	for bubble: Bubble in bubbles:
		if bubble.pop >= 0.0:
			continue
		bubble.error = maxf(bubble.error, tint)
		bubble.pop_delay = delay
		delay += END_POP_STAGGER
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < END_SETTLE_MSEC and not bubbles.is_empty():
		await get_tree().process_frame
	pass


func on_turn_start(_session_id: int) -> void:
	var gust := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 0.1)).normalized() * GUST_SPEED
	for bubble: Bubble in bubbles:
		bubble.velocity += gust * rng.randf_range(0.6, 1.2)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := SimulationEffect.stream_energy_for_length(chunk.length())
	turbulence = minf(turbulence + energy * TURBULENCE_GAIN, 1.0)
	if stream_kind != OpenAiClient.STREAM_KIND_REASONING and spawning:
		spawn_budget += energy * SPAWN_GAIN
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	turbulence = minf(turbulence + 0.3, 1.0)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	var anchor := SimulationEffect.tool_anchor(tool_name)
	var bubble := add_bubble(Vector2(anchor.x * current_aspect(), anchor.y), TOOL_START_RADIUS, TOOL_RADIUS)
	bubble.key = tool_call_id
	bubble.lifetime = LIFETIME_MAX * 2.0
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if result.is_error:
		for bubble: Bubble in bubbles:
			bubble.error = 1.0
			start_pop(bubble)
		return
	var bubble := find_bubble(tool_call_id)
	if bubble != null:
		start_pop(bubble)
	pass


## Adds a bubble, bursting the oldest intact one when every slot is taken.
func add_bubble(position: Vector2, radius: float, target_radius: float) -> Bubble:
	if bubbles.size() >= MAX_BUBBLES:
		var oldest := -1
		for index in range(bubbles.size()):
			if bubbles[index].pop < 0.0:
				oldest = index
				break
		bubbles.remove_at(maxi(oldest, 0))
	var bubble := Bubble.new()
	bubble.position = position
	bubble.radius = radius
	bubble.target_radius = target_radius
	bubble.noise_seed = rng.randf()
	bubble.lifetime = rng.randf_range(LIFETIME_MIN, LIFETIME_MAX)
	bubbles.append(bubble)
	return bubble


## Blows a bubble up from the bottom edge; returns null when every slot is busy.
func spawn_rising(radius: float) -> Bubble:
	if bubbles.size() >= MAX_BUBBLES:
		return null
	var aspect := current_aspect()
	var bubble := add_bubble(Vector2(rng.randf_range(0.12, 0.88) * aspect, 1.0 + radius * 0.6), radius * 0.6, radius)
	bubble.velocity = Vector2(rng.randf_range(-0.03, 0.03), -RISE_SPEED)
	return bubble


func find_bubble(key: String) -> Bubble:
	for bubble: Bubble in bubbles:
		if bubble.key == key and bubble.pop < 0.0:
			return bubble
	return null


func start_pop(bubble: Bubble) -> void:
	if bubble.pop >= 0.0:
		return
	bubble.pop = 0.0
	bubble.pop_angle = rng.randf() * TAU
	pass


func current_aspect() -> float:
	return size.x / size.y if size.y > 0.0 else DEFAULT_ASPECT


func current_top() -> float:
	return clampf(float(AgentLayout.TOOLBAR_HEIGHT) / size.y, 0.0, 0.3) if size.y > 0.0 else 0.06


func _process(delta: float) -> void:
	if not visible:
		return
	step_bubbles(minf(delta, 1.0 / 20.0))
	apply_shader_state()
	pass


func step_bubbles(delta: float) -> void:
	bubble_time += delta
	turbulence = maxf(move_toward(turbulence, turbulence_floor, TURBULENCE_DECAY_PER_SECOND * delta), turbulence_floor)
	while spawn_budget >= 1.0:
		spawn_budget -= 1.0
		spawn_rising(rng.randf_range(STREAM_RADIUS_MIN, STREAM_RADIUS_MAX))
	spawn_budget = minf(spawn_budget, 1.0)
	var aspect := current_aspect()
	var top := current_top()
	var damping := exp(-DAMPING_PER_SECOND * delta)
	for bubble: Bubble in bubbles:
		var phase := bubble_time + bubble.noise_seed * 40.0
		bubble.velocity.y -= BUOYANCY * delta
		bubble.velocity += Vector2(sin(phase * 0.7), cos(phase * 0.53)) * WANDER * (1.0 + turbulence) * delta
		bubble.velocity *= damping
		bubble.radius = move_toward(bubble.radius, bubble.target_radius, INFLATE_PER_SECOND * delta)
	separate_bubbles()
	for index in range(bubbles.size() - 1, -1, -1):
		var bubble := bubbles[index]
		bubble.position += bubble.velocity * delta
		keep_inside(bubble, aspect, top)
		bubble.age += delta
		if bubble.pop_delay >= 0.0:
			bubble.pop_delay -= delta
			if bubble.pop_delay < 0.0:
				start_pop(bubble)
		if bubble.pop < 0.0 and bubble.age >= bubble.lifetime:
			start_pop(bubble)
		if bubble.pop >= 0.0:
			bubble.pop += POP_PER_SECOND * delta
			if bubble.pop >= 1.0:
				bubbles.remove_at(index)
	pass


## Soft pairwise push so overlapping bubbles slide apart instead of interpenetrating.
func separate_bubbles() -> void:
	for a in range(bubbles.size()):
		for b in range(a + 1, bubbles.size()):
			var first := bubbles[a]
			var second := bubbles[b]
			var offset := second.position - first.position
			var reach := first.radius + second.radius
			var distance := offset.length()
			if distance >= reach or distance <= 0.0001:
				continue
			var push := offset / distance * (reach - distance) * 0.5
			first.position -= push * 0.5
			second.position += push * 0.5
			first.velocity -= push
			second.velocity += push
	pass


## Walls bounce softly; a bubble still rising from below the bottom edge is let through.
func keep_inside(bubble: Bubble, aspect: float, top: float) -> void:
	var r := bubble.radius
	if bubble.position.x < r:
		bubble.position.x = r
		bubble.velocity.x = absf(bubble.velocity.x) * 0.5
	elif bubble.position.x > aspect - r:
		bubble.position.x = aspect - r
		bubble.velocity.x = -absf(bubble.velocity.x) * 0.5
	if bubble.position.y < top + r:
		bubble.position.y = top + r
		bubble.velocity.y = absf(bubble.velocity.y) * 0.4
	elif bubble.position.y > 1.0 - r and bubble.velocity.y > 0.0:
		bubble.velocity.y = -absf(bubble.velocity.y) * 0.4
	pass


func apply_shader_state() -> void:
	if bubble_material == null:
		return
	var aspect := current_aspect()
	var shapes := PackedVector4Array()
	var states := PackedVector4Array()
	shapes.resize(MAX_BUBBLES)
	states.resize(MAX_BUBBLES)
	for index in range(mini(bubbles.size(), MAX_BUBBLES)):
		var bubble := bubbles[index]
		shapes[index] = Vector4(bubble.position.x / aspect, bubble.position.y, bubble.radius, bubble.noise_seed)
		states[index] = Vector4(clampf(bubble.age / bubble.lifetime, 0.0, 1.0), bubble.pop, bubble.pop_angle, bubble.error)
	bubble_material.set_shader_parameter("bubble_count", mini(bubbles.size(), MAX_BUBBLES))
	bubble_material.set_shader_parameter("bubble_shape", shapes)
	bubble_material.set_shader_parameter("bubble_state", states)
	bubble_material.set_shader_parameter("bubble_time", bubble_time)
	bubble_material.set_shader_parameter("turbulence", turbulence)
	pass


func update_theme_presentation() -> void:
	if bubble_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	bubble_material.set_shader_parameter("error_color", Colors.error)
	bubble_material.set_shader_parameter("film_gain", DARK_FILM_GAIN if dark else LIGHT_FILM_GAIN)
	bubble_material.set_shader_parameter("light_mode", 0.0 if dark else 1.0)
	pass
