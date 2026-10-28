class_name Ghost
extends VisualEffect

## Reveals an otherwise invisible body by lifting text and fine interface detail away from their
## surfaces. The body itself has no color or outline; only detached details and their slowly
## healing source positions provide evidence that it exists.

const GHOST_SHADER: Shader = preload("res://agent/ui/visuals/ghost/Ghost.gdshader")
const ENERGY_DECAY_PER_SECOND := 0.34
const PRESENCE_SPRING := 54.0
const PRESENCE_DAMPING := 12.8
const POSITION_SPRING := 9.5
const POSITION_DAMPING := 5.8
const MIN_RADIUS_PX := 174.0
const MAX_RADIUS_PX := 304.0
const ANCHOR_REFRESH_SECONDS := 0.20
const IDLE_EPSILON := 0.001

var screen_rect: ColorRect
var presence_material: ShaderMaterial
var presence_energy: float = 0.0
var presence_strength: float = 0.0
var strength_velocity: float = 0.0
var presence_center := Vector2(1.12, 0.58)
var center_velocity := Vector2.ZERO
var trail_center := presence_center
var anchor_center := Vector2(0.68, 0.58)
var motion_phase: float = 0.0
var travel_direction: float = 1.0
var anchor_control: Control
var anchor_refresh_clock: float = ANCHOR_REFRESH_SECONDS
var anchor_refresh_requested: bool = true


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "GhostSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	presence_material = ShaderMaterial.new()
	presence_material.shader = GHOST_SHADER
	presence_material.set_shader_parameter("effect_area_rect", body_effect_rect(size, float(AgentLayout.TOOLBAR_HEIGHT)))
	screen_rect.material = presence_material
	add_child(screen_rect)
	resized.connect(update_effect_area)
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.14


func fade_out_seconds() -> float:
	return 0.34


func on_agent_start(_session_id: int) -> void:
	reset_presence()
	refresh_anchor_control()
	presence_center = clamp_presence_center(anchor_center + Vector2(0.34 * travel_direction, -0.04))
	trail_center = presence_center
	pulse(0.58)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	pulse(1.0 if StringUtils.is_not_blank(error_message) else 0.76)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 1200 and (presence_energy > 0.10 or presence_strength > 0.08):
		await get_tree().process_frame
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	presence_energy = combine_energy(presence_energy, stream_energy_for_length(chunk.length()))
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	request_anchor_refresh()
	pulse(0.70)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	request_anchor_refresh()
	pulse(0.94, -travel_direction)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	pulse(1.0 if result.is_error else 0.82)
	pass


func on_chat_entry_add(_session_id: int, _entry: ChatEntry) -> void:
	request_anchor_refresh()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	anchor_refresh_clock += delta
	if anchor_refresh_clock >= ANCHOR_REFRESH_SECONDS:
		if anchor_refresh_requested or not is_instance_valid(anchor_control):
			refresh_anchor_control()
		else:
			anchor_refresh_clock = 0.0
			update_anchor_geometry()
	step_presence(delta)
	apply_shader_state()
	pass


func pulse(strength: float, requested_direction: float = 0.0) -> void:
	if presence_energy <= 0.12:
		travel_direction = -travel_direction if requested_direction == 0.0 else signf(requested_direction)
	presence_energy = combine_energy(presence_energy, strength)
	pass


func step_presence(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var target_strength := smoothstep(0.04, 0.72, presence_energy)
	var strength_acceleration := (target_strength - presence_strength) * PRESENCE_SPRING - strength_velocity * PRESENCE_DAMPING
	strength_velocity += strength_acceleration * safe_delta
	presence_strength = clampf(presence_strength + strength_velocity * safe_delta, 0.0, 1.0)
	if presence_strength == 0.0 or presence_strength == 1.0:
		strength_velocity *= 0.52
	motion_phase = fmod(motion_phase + safe_delta * lerpf(0.38, 1.22, presence_strength) * travel_direction, TAU * 8.0)
	var orbit := Vector2(sin(motion_phase * 0.71) * 0.16, cos(motion_phase * 0.47) * 0.075)
	var desired_center := clamp_presence_center(anchor_center + orbit)
	var center_acceleration := (desired_center - presence_center) * POSITION_SPRING - center_velocity * POSITION_DAMPING
	center_velocity += center_acceleration * safe_delta
	presence_center = clamp_presence_center(presence_center + center_velocity * safe_delta)
	var trail_blend := 1.0 - exp(-safe_delta * lerpf(1.2, 2.6, presence_strength))
	trail_center = trail_center.lerp(presence_center, trail_blend)
	presence_energy = move_toward(presence_energy, 0.0, ENERGY_DECAY_PER_SECOND * safe_delta)
	if presence_energy < IDLE_EPSILON:
		presence_energy = 0.0
	if presence_energy == 0.0 and presence_strength < IDLE_EPSILON and absf(strength_velocity) < IDLE_EPSILON:
		presence_strength = 0.0
		strength_velocity = 0.0
	pass


func apply_shader_state() -> void:
	if presence_material == null:
		return
	presence_material.set_shader_parameter("presence_strength", presence_strength)
	presence_material.set_shader_parameter("presence_center", presence_center)
	presence_material.set_shader_parameter("trail_center", trail_center)
	presence_material.set_shader_parameter("motion_velocity", center_velocity)
	presence_material.set_shader_parameter("motion_phase", motion_phase)
	presence_material.set_shader_parameter("radius_px", lerpf(MIN_RADIUS_PX, MAX_RADIUS_PX, presence_strength))
	pass


func update_effect_area() -> void:
	if presence_material != null:
		presence_material.set_shader_parameter("effect_area_rect", body_effect_rect(size, float(AgentLayout.TOOLBAR_HEIGHT)))
	pass


func request_anchor_refresh() -> void:
	anchor_refresh_clock = ANCHOR_REFRESH_SECONDS
	anchor_refresh_requested = true
	pass


func refresh_anchor_control() -> void:
	anchor_refresh_clock = 0.0
	anchor_refresh_requested = false
	anchor_control = null
	if not is_inside_tree() or size.x <= 0.0 or size.y <= 0.0:
		return
	var transcript_root := find_visible_control_named(get_tree().root, "ChatListsContainer")
	if transcript_root == null:
		anchor_center = Vector2(0.68, 0.58)
		return
	var bubbles: Array[Control] = []
	collect_bubbles(transcript_root, bubbles)
	var clip_control := transcript_root.get_parent() as Control
	var clip_rect := clip_control.get_global_rect() if clip_control != null else Rect2(Vector2.ZERO, size)
	var visible_bubbles := visible_controls(bubbles, clip_rect)
	if visible_bubbles.is_empty():
		return
	anchor_control = visible_bubbles[visible_bubbles.size() - 1]
	update_anchor_geometry()
	pass


func update_anchor_geometry() -> void:
	if not is_instance_valid(anchor_control) or size.x <= 0.0 or size.y <= 0.0:
		return
	var anchor_rect := anchor_control.get_global_rect().intersection(Rect2(Vector2.ZERO, size))
	if anchor_rect.size.x >= 24.0 and anchor_rect.size.y >= 16.0:
		anchor_center = clamp_presence_center(anchor_rect.get_center() / size)
	pass


func find_visible_control_named(node: Node, target_name: String) -> Control:
	if node is Control and node.name == target_name and (node as Control).is_visible_in_tree():
		return node as Control
	for child: Node in node.get_children():
		var result := find_visible_control_named(child, target_name)
		if result != null:
			return result
	return null


func collect_bubbles(node: Node, bubbles: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is BubbleContainer:
			bubbles.append(child as Control)
		collect_bubbles(child, bubbles)
	pass


func visible_controls(candidates: Array[Control], clip_rect: Rect2) -> Array[Control]:
	var viewport_rect := Rect2(Vector2.ZERO, size).intersection(clip_rect)
	var result: Array[Control] = []
	for candidate: Control in candidates:
		if not candidate.is_visible_in_tree():
			continue
		var visible_rect := candidate.get_global_rect().intersection(viewport_rect)
		if visible_rect.size.x >= 48.0 and visible_rect.size.y >= 20.0:
			result.append(candidate)
	result.sort_custom(func(first: Control, second: Control) -> bool:
		return first.global_position.y < second.global_position.y
	)
	return result


func reset_presence() -> void:
	presence_energy = 0.0
	presence_strength = 0.0
	strength_velocity = 0.0
	presence_center = Vector2(1.12, 0.58)
	center_velocity = Vector2.ZERO
	trail_center = presence_center
	anchor_center = Vector2(0.68, 0.58)
	motion_phase = 0.0
	travel_direction = 1.0
	anchor_refresh_clock = ANCHOR_REFRESH_SECONDS
	anchor_refresh_requested = true
	apply_shader_state()
	pass


static func combine_energy(current: float, incoming: float) -> float:
	var safe_current := clampf(current, 0.0, 1.0)
	var safe_incoming := clampf(incoming, 0.0, 1.0)
	return 1.0 - (1.0 - safe_current) * (1.0 - safe_incoming)


static func stream_energy_for_length(length: int) -> float:
	return clampf(float(length) * 0.0016, 0.003, 0.042)


static func clamp_presence_center(center: Vector2) -> Vector2:
	return Vector2(clampf(center.x, 0.10, 0.92), clampf(center.y, 0.16, 0.88))


static func body_effect_rect(viewport_size: Vector2, toolbar_height: float) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4.ZERO
	var top := clampf(toolbar_height / viewport_size.y, 0.0, 1.0)
	return Vector4(0.0, top, 1.0, 1.0 - top)
