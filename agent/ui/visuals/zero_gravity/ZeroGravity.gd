class_name ZeroGravity
extends VisualEffect

## Treats visible chat entries as rigid screen-space bodies. Each body keeps its typography intact,
## receives semantic mass and event impulses, coasts while gravity is absent, then springs back to
## its live Control rect when the field collapses.

const ZERO_GRAVITY_SHADER: Shader = preload("res://agent/ui/visuals/zero_gravity/ZeroGravity.gdshader")
const MAX_CHAT_BODY_COUNT := 10
const MAX_SIDEBAR_BODY_COUNT := 8
const MAX_SIDEBAR_TRANSITION_COUNT := 4
const MAX_BODY_COUNT := MAX_CHAT_BODY_COUNT + MAX_SIDEBAR_BODY_COUNT + MAX_SIDEBAR_TRANSITION_COUNT
const SIDEBAR_MOTION_SCALE := 0.58
const SIDEBAR_MASS_SCALE := 0.78
const SIDEBAR_ENTER_SPEED := 4.2
const SIDEBAR_EXIT_SPEED := 2.4
const SIDEBAR_STICKY_DISTANCE_PX := 56.0
const ENERGY_DECAY_PER_SECOND := 0.34
const MOMENTUM_DECAY_PER_SECOND := 0.17
const FIELD_SPRING := 54.0
const FIELD_DAMPING := 12.8
const CENTER_SPRING := 9.5
const CENTER_DAMPING := 5.8
const MIN_RADIUS_PX := 260.0
const MAX_RADIUS_PX := 460.0
const BODY_REFRESH_SECONDS := 0.14
const SIDEBAR_REEVALUATE_SECONDS := 0.32
const SIDEBAR_ACTIVE_THRESHOLD := 0.03
const MAX_BODY_OFFSET_PX := 132.0
const IDLE_EPSILON := 0.001


class FloatingBodyState extends RefCounted:
	var control: Control
	var rect := Rect2()
	var offset := Vector2.ZERO
	var velocity := Vector2.ZERO
	var rotation: float = 0.0
	var angular_velocity: float = 0.0
	var mass: float = 1.0
	var seed: float = 0.5
	var is_sidebar: bool = false
	var motion_scale: float = 1.0
	var participation: float = 1.0
	var target_participation: float = 1.0

	func _init(p_control: Control, p_mass: float, p_seed: float, p_is_sidebar: bool = false, p_motion_scale: float = 1.0) -> void:
		control = p_control
		mass = p_mass
		seed = p_seed
		is_sidebar = p_is_sidebar
		motion_scale = p_motion_scale
		pass


var screen_rect: ColorRect
var zero_gravity_material: ShaderMaterial
var field_energy: float = 0.0
var field_strength: float = 0.0
var drift_momentum: float = 0.0
var field_velocity: float = 0.0
var field_center := Vector2(1.12, 0.58)
var field_center_velocity := Vector2.ZERO
var trail_center := field_center
var anchor_center := Vector2(0.68, 0.58)
var motion_phase: float = 0.0
var gravity_direction: float = 1.0
var reaction_impulse := Vector2.ZERO
var bodies: Array[FloatingBodyState] = []
var body_refresh_clock: float = BODY_REFRESH_SECONDS
var body_refresh_requested: bool = true
var sidebar_reevaluation_clock: float = 0.0
var chat_anchor_control: Control


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "ZeroGravitySurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zero_gravity_material = ShaderMaterial.new()
	zero_gravity_material.shader = ZERO_GRAVITY_SHADER
	zero_gravity_material.set_shader_parameter("effect_area_rect", body_effect_rect(size, float(AgentLayout.TOOLBAR_HEIGHT)))
	screen_rect.material = zero_gravity_material
	add_child(screen_rect)
	resized.connect(update_effect_area)
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.14


func fade_out_seconds() -> float:
	return 0.36


func on_agent_start(_session_id: int) -> void:
	reset_zero_gravity()
	refresh_bodies()
	field_center = clamp_field_center(anchor_center + Vector2(0.28 * gravity_direction, -0.04))
	trail_center = field_center
	pulse(0.58)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	pulse(1.0 if StringUtils.is_not_blank(error_message) else 0.76)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 1450 and (field_energy > 0.10 or field_strength > 0.08 or has_moving_bodies()):
		await get_tree().process_frame
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var chunk_energy := stream_energy_for_length(chunk.length())
	field_energy = combine_energy(field_energy, chunk_energy)
	drift_momentum = combine_energy(drift_momentum, chunk_energy * 0.78)
	# Text streams left-to-right, so its arrival gives detached bodies a small opposite impulse.
	reaction_impulse += Vector2(-chunk_energy * 95.0, gravity_direction * chunk_energy * 34.0)
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	request_body_refresh()
	pulse(0.70)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	request_body_refresh()
	pulse(0.94, -gravity_direction)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	pulse(1.0 if result.is_error else 0.82)
	pass


func on_chat_entry_add(_session_id: int, _entry: ChatEntry) -> void:
	request_body_refresh()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	body_refresh_clock += delta
	sidebar_reevaluation_clock += delta
	if should_reevaluate_sidebar(field_strength, drift_momentum, sidebar_reevaluation_clock):
		refresh_bodies()
	elif body_refresh_clock >= BODY_REFRESH_SECONDS:
		if body_refresh_requested:
			refresh_bodies()
		else:
			body_refresh_clock = 0.0
			update_body_rects()
	step_field(delta)
	step_bodies(delta)
	apply_shader_state()
	pass


func pulse(strength: float, requested_direction: float = 0.0) -> void:
	if field_energy <= 0.12:
		gravity_direction = -gravity_direction if requested_direction == 0.0 else signf(requested_direction)
	field_energy = combine_energy(field_energy, strength)
	drift_momentum = combine_energy(drift_momentum, strength * 0.86)
	var lateral_impulse := sin(motion_phase * 1.37 + strength * 2.1) * 18.0
	reaction_impulse += Vector2(lateral_impulse, gravity_direction * strength * 72.0)
	for body: FloatingBodyState in bodies:
		var membership := body.participation if body.is_sidebar else 1.0
		var impulse_scale := (0.82 + body.seed * 0.36) * body.motion_scale * membership / body.mass
		body.velocity += reaction_impulse * impulse_scale * 0.22
		body.angular_velocity += (body.seed - 0.5) * strength * 0.032 / body.mass
	pass


func step_field(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var target_strength := smoothstep(0.04, 0.72, field_energy)
	var acceleration := (target_strength - field_strength) * FIELD_SPRING - field_velocity * FIELD_DAMPING
	field_velocity += acceleration * safe_delta
	field_strength = clampf(field_strength + field_velocity * safe_delta, 0.0, 1.0)
	if field_strength == 0.0 or field_strength == 1.0:
		field_velocity *= 0.52
	motion_phase = fmod(motion_phase + safe_delta * lerpf(0.32, 1.08, field_strength) * gravity_direction, TAU * 8.0)
	var orbit := Vector2(sin(motion_phase * 0.57) * 0.13, cos(motion_phase * 0.43) * 0.065)
	var desired_center := clamp_field_center(anchor_center + orbit)
	var center_acceleration := (desired_center - field_center) * CENTER_SPRING - field_center_velocity * CENTER_DAMPING
	field_center_velocity += center_acceleration * safe_delta
	field_center = clamp_field_center(field_center + field_center_velocity * safe_delta)
	var trail_blend := 1.0 - exp(-safe_delta * lerpf(1.0, 2.3, field_strength))
	trail_center = trail_center.lerp(field_center, trail_blend)
	field_energy = move_toward(field_energy, 0.0, ENERGY_DECAY_PER_SECOND * safe_delta)
	drift_momentum = move_toward(drift_momentum, 0.0, MOMENTUM_DECAY_PER_SECOND * safe_delta)
	reaction_impulse = reaction_impulse.move_toward(Vector2.ZERO, safe_delta * 52.0)
	if field_energy < IDLE_EPSILON:
		field_energy = 0.0
	if field_energy == 0.0 and field_strength < IDLE_EPSILON and absf(field_velocity) < IDLE_EPSILON:
		field_strength = 0.0
		field_velocity = 0.0
	pass


func step_bodies(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var release_strength := maxf(field_strength, drift_momentum * 0.86)
	for body: FloatingBodyState in bodies:
		if not is_instance_valid(body.control):
			continue
		var participation_speed := SIDEBAR_ENTER_SPEED if body.target_participation > body.participation else SIDEBAR_EXIT_SPEED
		body.participation = move_toward(body.participation, body.target_participation, participation_speed * safe_delta)
		var contact := field_contact_for_body(body) * body.participation
		var released := clampf(release_strength * contact, 0.0, 1.0)
		var attachment := lerpf(20.0, 1.45, released)
		var damping := lerpf(8.2, 0.72, released)
		var shared_drift := Vector2(sin(motion_phase * 0.31) * 9.0, gravity_direction * 74.0) * released * body.motion_scale
		var acceleration := (shared_drift + reaction_impulse * contact * body.motion_scale - body.offset * attachment - body.velocity * damping) / body.mass
		body.velocity += acceleration * safe_delta
		body.offset += body.velocity * safe_delta
		var max_offset := MAX_BODY_OFFSET_PX * body.motion_scale
		if body.offset.length() > max_offset:
			body.offset = body.offset.limit_length(max_offset)
			body.velocity *= 0.72
		var angular_attachment := lerpf(17.0, 2.4, released)
		var angular_damping := lerpf(8.5, 1.1, released)
		var torque := (body.seed - 0.5) * released * 0.025 * body.motion_scale
		var angular_acceleration := (torque - body.rotation * angular_attachment - body.angular_velocity * angular_damping) / body.mass
		body.angular_velocity += angular_acceleration * safe_delta
		body.rotation = clampf(body.rotation + body.angular_velocity * safe_delta, -0.055, 0.055)
		if released < 0.01 and body.offset.length() < 0.08 and body.velocity.length() < 0.08:
			body.offset = Vector2.ZERO
			body.velocity = Vector2.ZERO
		if released < 0.01 and absf(body.rotation) < 0.0005 and absf(body.angular_velocity) < 0.0005:
			body.rotation = 0.0
			body.angular_velocity = 0.0
	retire_settled_sidebar_bodies()
	pass


func apply_shader_state() -> void:
	if zero_gravity_material == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var rects := PackedVector4Array()
	var motions := PackedVector4Array()
	rects.resize(MAX_BODY_COUNT)
	motions.resize(MAX_BODY_COUNT)
	var active_count := mini(bodies.size(), MAX_BODY_COUNT)
	for index in range(active_count):
		var body := bodies[index]
		var normalized := normalized_rect(body.rect, size)
		var activity := clampf(maxf(body.offset.length() / 8.0, maxf(body.velocity.length() / 24.0, field_strength * field_contact_for_body(body))), 0.0, 1.0)
		rects[index] = normalized
		motions[index] = Vector4(body.offset.x / size.x, body.offset.y / size.y, body.rotation, activity)
	zero_gravity_material.set_shader_parameter("body_count", active_count)
	zero_gravity_material.set_shader_parameter("body_rects", rects)
	zero_gravity_material.set_shader_parameter("body_motions", motions)
	pass


func refresh_bodies() -> void:
	body_refresh_clock = 0.0
	sidebar_reevaluation_clock = 0.0
	body_refresh_requested = false
	if not is_inside_tree() or size.x <= 0.0 or size.y <= 0.0:
		return
	var root := get_tree().root
	var transcript_root := find_visible_control_named(root, "ChatListsContainer")
	var candidates: Array[Control] = []
	var visible_bubbles: Array[Control] = []
	if transcript_root != null:
		collect_bubbles(transcript_root, candidates)
		var clip_control := transcript_root.get_parent() as Control
		var clip_rect := clip_control.get_global_rect() if clip_control != null else Rect2(Vector2.ZERO, size)
		visible_bubbles = visible_controls(candidates, clip_rect)
		if visible_bubbles.size() > MAX_CHAT_BODY_COUNT:
			visible_bubbles = visible_bubbles.slice(visible_bubbles.size() - MAX_CHAT_BODY_COUNT)
	chat_anchor_control = visible_bubbles[visible_bubbles.size() - 1] if not visible_bubbles.is_empty() else null
	var sidebar_rows: Array[Control] = []
	var sidebar := find_visible_control_named(root, "Sidebar")
	var session_scroll := find_visible_control_named(root, "SessionListScroll")
	if sidebar != null and session_scroll != null:
		collect_session_rows(sidebar, sidebar_rows)
		sidebar_rows = visible_controls(sidebar_rows, session_scroll.get_global_rect())
		sidebar_rows = nearest_controls_to_y(sidebar_rows, field_center.y * size.y, MAX_SIDEBAR_BODY_COUNT)
	var retained: Array[FloatingBodyState] = []
	var outgoing_sidebar: Array[FloatingBodyState] = []
	for existing: FloatingBodyState in bodies:
		if existing.is_sidebar and is_instance_valid(existing.control) and not sidebar_rows.has(existing.control):
			existing.target_participation = 0.0
			outgoing_sidebar.append(existing)
	outgoing_sidebar.sort_custom(func(first: FloatingBodyState, second: FloatingBodyState) -> bool:
		return first.participation > second.participation
	)
	for index in range(mini(outgoing_sidebar.size(), MAX_SIDEBAR_TRANSITION_COUNT)):
		retained.append(outgoing_sidebar[index])
	for control: Control in sidebar_rows:
		var body := find_body_for_control(control)
		if body == null:
			var seed := instance_seed(control.get_instance_id())
			body = FloatingBodyState.new(control, semantic_mass(control, control.get_global_rect()) * SIDEBAR_MASS_SCALE, seed, true, SIDEBAR_MOTION_SCALE)
			body.participation = 0.0
		body.target_participation = 1.0
		retained.append(body)
	for control: Control in visible_bubbles:
		var body := find_body_for_control(control)
		if body == null:
			var seed := instance_seed(control.get_instance_id())
			body = FloatingBodyState.new(control, semantic_mass(control, control.get_global_rect()), seed)
		retained.append(body)
	bodies = retained
	update_body_rects()
	pass


func update_body_rects() -> void:
	var viewport_rect := Rect2(Vector2.ZERO, size)
	for body: FloatingBodyState in bodies:
		if not is_instance_valid(body.control):
			continue
		body.rect = body.control.get_global_rect().intersection(viewport_rect)
		body.mass = semantic_mass(body.control, body.rect) * (SIDEBAR_MASS_SCALE if body.is_sidebar else 1.0)
	if is_instance_valid(chat_anchor_control):
		anchor_center = clamp_field_center(chat_anchor_control.get_global_rect().get_center() / size)
	pass


func find_body_for_control(control: Control) -> FloatingBodyState:
	for body: FloatingBodyState in bodies:
		if body.control == control:
			return body
	return null


func field_contact_for_point(point: Vector2) -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 0.0
	var radius := lerpf(MIN_RADIUS_PX, MAX_RADIUS_PX, field_strength)
	var secondary_center := clamp_field_center(field_center + Vector2(cos(motion_phase * 0.41) * 0.21, sin(motion_phase * 0.37 + 0.8) * 0.13))
	var tertiary_center := clamp_field_center(field_center + Vector2(cos(motion_phase * 0.29 + 2.4) * 0.27, sin(motion_phase * 0.33 + 2.1) * 0.17))
	var primary := ellipse_contact(point, field_center * size, radius, 0.72)
	var secondary := ellipse_contact(point, secondary_center * size, radius * 0.80, 0.72) * 0.88
	var tertiary := ellipse_contact(point, tertiary_center * size, radius * 0.66, 0.72) * 0.74
	var trail := ellipse_contact(point, trail_center * size, radius * 0.92, 0.72) * 0.24
	return maxf(maxf(primary, secondary), maxf(tertiary, trail))


func field_contact_for_body(body: FloatingBodyState) -> float:
	if not body.is_sidebar:
		return field_contact_for_point(body.rect.get_center())
	if size.y <= 0.0:
		return 0.0
	var radius := lerpf(MIN_RADIUS_PX, MAX_RADIUS_PX, field_strength) * 0.76
	var secondary_y := clamp_field_center(field_center + Vector2(0.0, sin(motion_phase * 0.37 + 0.8) * 0.13)).y * size.y
	var tertiary_y := clamp_field_center(field_center + Vector2(0.0, sin(motion_phase * 0.33 + 2.1) * 0.17)).y * size.y
	var point_y := body.rect.get_center().y
	var primary := axis_contact(point_y, field_center.y * size.y, radius)
	var secondary := axis_contact(point_y, secondary_y, radius * 0.80) * 0.88
	var tertiary := axis_contact(point_y, tertiary_y, radius * 0.66) * 0.74
	return maxf(primary, maxf(secondary, tertiary))


func has_moving_bodies() -> bool:
	for body: FloatingBodyState in bodies:
		if body.offset.length() > 0.8 or body.velocity.length() > 1.0 or absf(body.rotation) > 0.006:
			return true
	return false


func retire_settled_sidebar_bodies() -> void:
	for index in range(bodies.size() - 1, -1, -1):
		var body := bodies[index]
		if body.is_sidebar and body.target_participation <= 0.0 and body.participation <= 0.001 and body.offset.length() < 0.08 and body.velocity.length() < 0.08 and absf(body.rotation) < 0.0005:
			bodies.remove_at(index)
	pass


func update_effect_area() -> void:
	if zero_gravity_material != null:
		zero_gravity_material.set_shader_parameter("effect_area_rect", body_effect_rect(size, float(AgentLayout.TOOLBAR_HEIGHT)))
	request_body_refresh()
	pass


func request_body_refresh() -> void:
	body_refresh_clock = BODY_REFRESH_SECONDS
	sidebar_reevaluation_clock = 0.0
	body_refresh_requested = true
	pass


func find_visible_control_named(node: Node, target_name: String) -> Control:
	if node is Control and node.name == target_name and (node as Control).is_visible_in_tree():
		return node as Control
	for child: Node in node.get_children():
		var result := find_visible_control_named(child, target_name)
		if result != null:
			return result
	return null


func collect_bubbles(node: Node, result: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is BubbleContainer:
			result.append(child as Control)
		collect_bubbles(child, result)
	pass


func collect_session_rows(node: Node, result: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is SessionRow:
			result.append(child as Control)
		collect_session_rows(child, result)
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


func nearest_controls_to_y(candidates: Array[Control], target_y: float, limit: int) -> Array[Control]:
	if candidates.size() <= limit:
		return candidates
	var ranked := candidates.duplicate()
	ranked.sort_custom(func(first: Control, second: Control) -> bool:
		return sidebar_selection_distance(first, target_y) < sidebar_selection_distance(second, target_y)
	)
	var selected: Array[Control] = []
	for index in range(limit):
		selected.append(ranked[index])
	selected.sort_custom(func(first: Control, second: Control) -> bool:
		return first.global_position.y < second.global_position.y
	)
	return selected


func sidebar_selection_distance(control: Control, target_y: float) -> float:
	var distance := absf(control.get_global_rect().get_center().y - target_y)
	var existing := find_body_for_control(control)
	if existing != null and existing.is_sidebar and existing.participation > 0.05:
		distance = maxf(0.0, distance - SIDEBAR_STICKY_DISTANCE_PX)
	return distance


func reset_zero_gravity() -> void:
	field_energy = 0.0
	field_strength = 0.0
	drift_momentum = 0.0
	field_velocity = 0.0
	field_center = Vector2(1.12, 0.58)
	field_center_velocity = Vector2.ZERO
	trail_center = field_center
	anchor_center = Vector2(0.68, 0.58)
	motion_phase = 0.0
	gravity_direction = 1.0
	reaction_impulse = Vector2.ZERO
	bodies.clear()
	chat_anchor_control = null
	body_refresh_clock = BODY_REFRESH_SECONDS
	body_refresh_requested = true
	apply_shader_state()
	pass


static func combine_energy(current: float, incoming: float) -> float:
	var safe_current := clampf(current, 0.0, 1.0)
	var safe_incoming := clampf(incoming, 0.0, 1.0)
	return 1.0 - (1.0 - safe_current) * (1.0 - safe_incoming)


static func stream_energy_for_length(length: int) -> float:
	return clampf(float(length) * 0.0016, 0.003, 0.042)


static func should_reevaluate_sidebar(strength: float, momentum: float, elapsed: float) -> bool:
	return elapsed >= SIDEBAR_REEVALUATE_SECONDS and maxf(strength, momentum) >= SIDEBAR_ACTIVE_THRESHOLD


static func semantic_mass_for_path(script_path: String, height: float) -> float:
	var lowered := script_path.to_lower()
	var base_mass := 1.0
	if "thinking" in lowered:
		base_mass = 0.68
	elif "tool" in lowered or "result" in lowered or "gitdiff" in lowered or "web" in lowered or "explorer" in lowered:
		base_mass = 1.46
	elif "error" in lowered:
		base_mass = 1.28
	elif "user" in lowered:
		base_mass = 1.12
	var height_mass := clampf(sqrt(maxf(height, 20.0) / 92.0), 0.72, 1.62)
	return base_mass * height_mass


static func instance_seed(instance_id: int) -> float:
	return fmod(float(instance_id) * 0.61803398875, 1.0)


static func ellipse_contact(point: Vector2, center: Vector2, radius: float, vertical_ratio: float) -> float:
	if radius <= 0.0:
		return 0.0
	var delta := point - center
	var normalized_distance := Vector2(delta.x / radius, delta.y / maxf(radius * vertical_ratio, 1.0)).length()
	return 1.0 - smoothstep(0.72, 1.28, normalized_distance)


static func axis_contact(value: float, center: float, radius: float) -> float:
	if radius <= 0.0:
		return 0.0
	return 1.0 - smoothstep(0.72, 1.28, absf(value - center) / radius)


static func clamp_field_center(center: Vector2) -> Vector2:
	return Vector2(clampf(center.x, 0.08, 0.94), clampf(center.y, 0.14, 0.90))


static func normalized_rect(rect: Rect2, viewport_size: Vector2) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4.ZERO
	return Vector4(rect.position.x / viewport_size.x, rect.position.y / viewport_size.y, rect.size.x / viewport_size.x, rect.size.y / viewport_size.y)


static func body_effect_rect(viewport_size: Vector2, toolbar_height: float) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4.ZERO
	var top := clampf(toolbar_height / viewport_size.y, 0.0, 1.0)
	return Vector4(0.0, top, 1.0, 1.0 - top)


static func semantic_mass(control: Control, rect: Rect2) -> float:
	var script_path := ""
	var script := control.get_script() as Script
	if script != null:
		script_path = script.resource_path
	return semantic_mass_for_path(script_path, rect.size.y)
