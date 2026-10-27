class_name ImpossibleRoom
extends VisualEffect

## Makes the application surface behave like an impossible moving room. The toolbar remains
## visually anchored while the content below it slides as a perspective plane, then settles with
## spring inertia. Transcript sentences and tool lifecycle events provide the physical impulses.

const ROOM_SHADER: Shader = preload("res://agent/ui/visuals/impossible_room/ImpossibleRoom.gdshader")
const SPRING_STRENGTH := 74.0
const SPRING_DAMPING := 13.5
const MAX_DISPLACEMENT_PX := 148.0
const MAX_VELOCITY_PX := 1180.0
const IDLE_EPSILON := 0.025
const ANCHOR_REFRESH_SECONDS := 0.18
const ANCHOR_MARGIN_PX := 8.0
const INERTIA_CONTROL_COUNT := 3
const OCCLUSION_DURATION_SECONDS := 1.4
const OCCLUSION_EDGE_GAP_PX := 72.0
const OCCLUSION_MIN_IMPULSE := 700.0
const INERTIA_STRENGTHS: Array[float] = [44.0, 27.0, 16.0]
const INERTIA_DAMPING: Array[float] = [11.8, 9.0, 6.8]

var screen_rect: ColorRect
var room_material: ShaderMaterial
var displacement_px: float = 0.0
var velocity_px: float = 0.0
var impact: float = 0.0
var event_direction: float = 1.0
var anchor_refresh_clock: float = 0.0
var anchor_control: Control
var inertia_controls: Array[Control] = []
var inertia_displacements: Array[float] = [0.0, 0.0, 0.0]
var inertia_velocities: Array[float] = [0.0, 0.0, 0.0]
var occluder_control: Control
var occlusion_clock: float = OCCLUSION_DURATION_SECONDS
var occlusion_direction: float = 1.0
var occlusion_source_rect := Rect2()
var occlusion_anchor_rect := Rect2()


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "MovingRoomSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room_material = ShaderMaterial.new()
	room_material.shader = ROOM_SHADER
	room_material.set_shader_parameter("toolbar_height_px", float(AgentLayout.TOOLBAR_HEIGHT))
	room_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	room_material.set_shader_parameter("anchor_enabled", 0.0)
	room_material.set_shader_parameter("inertia_enabled", Vector3.ZERO)
	room_material.set_shader_parameter("occluder_enabled", 0.0)
	screen_rect.material = room_material
	add_child(screen_rect)
	gdf.events.theme_color_changed.connect(update_accent_color)
	pass


func fade_in_seconds() -> float:
	return 0.16


func fade_out_seconds() -> float:
	return 0.22


func on_agent_start(_session_id: int) -> void:
	reset_motion()
	refresh_anchor_control()
	kick(510.0)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	if StringUtils.is_not_blank(error_message):
		kick(920.0, -event_direction)
	else:
		kick(650.0)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 1150 and (absf(displacement_px) > 0.8 or absf(velocity_px) > 8.0):
		await get_tree().process_frame
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty() or stream_kind != OpenAiClient.STREAM_KIND_REASONING:
		return
	# Reasoning creates restrained pressure instead of one kick per streamed token.
	velocity_px = clampf(velocity_px + event_direction * minf(float(chunk.length()) * 1.8, 24.0), -MAX_VELOCITY_PX, MAX_VELOCITY_PX)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	refresh_anchor_control()
	kick(860.0)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	# A result pushes the room back across its previous path. Failures deliberately overshoot.
	kick(1040.0 if result.is_error else 720.0, -event_direction)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	anchor_refresh_clock += delta
	if anchor_refresh_clock >= ANCHOR_REFRESH_SECONDS and not occlusion_is_active() and (not is_instance_valid(anchor_control) or absf(displacement_px) < 3.0):
		refresh_anchor_control()
	update_anchor_shader()
	if not RuntimeManager.runtimes.is_empty():
		var sentence := ChatEntryCursor.take_next_sentence()
		if not sentence.is_empty():
			kick(impulse_for_sentence(sentence.text))
	step_motion(delta)
	apply_shader_state()
	pass


func step_motion(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var acceleration := -displacement_px * SPRING_STRENGTH - velocity_px * SPRING_DAMPING
	velocity_px = clampf(velocity_px + acceleration * safe_delta, -MAX_VELOCITY_PX, MAX_VELOCITY_PX)
	displacement_px = clampf(displacement_px + velocity_px * safe_delta, -MAX_DISPLACEMENT_PX, MAX_DISPLACEMENT_PX)
	impact = move_toward(impact, 0.0, safe_delta * 2.7)
	if absf(displacement_px) < IDLE_EPSILON and absf(velocity_px) < IDLE_EPSILON:
		displacement_px = 0.0
		velocity_px = 0.0
	step_inertia_controls(safe_delta)
	occlusion_clock = minf(occlusion_clock + safe_delta, OCCLUSION_DURATION_SECONDS)
	pass


func step_inertia_controls(delta: float) -> void:
	for index in range(INERTIA_CONTROL_COUNT):
		var acceleration := (displacement_px - inertia_displacements[index]) * INERTIA_STRENGTHS[index] - inertia_velocities[index] * INERTIA_DAMPING[index]
		inertia_velocities[index] += acceleration * delta
		inertia_displacements[index] = clampf(inertia_displacements[index] + inertia_velocities[index] * delta, -MAX_DISPLACEMENT_PX, MAX_DISPLACEMENT_PX)
	pass


func kick(impulse: float, direction: float = 0.0) -> void:
	if direction == 0.0:
		event_direction = -event_direction
	else:
		event_direction = signf(direction)
	velocity_px = clampf(velocity_px + event_direction * impulse, -MAX_VELOCITY_PX, MAX_VELOCITY_PX)
	impact = clampf(impact + impulse / MAX_VELOCITY_PX, 0.0, 1.0)
	if impulse >= OCCLUSION_MIN_IMPULSE and not occlusion_is_active():
		begin_occlusion(event_direction)
	pass


func occlusion_is_active() -> bool:
	return occlusion_clock < OCCLUSION_DURATION_SECONDS


## Freezes both rectangles for the entire shot. Later layout and lifecycle events may move or
## replace the underlying Controls, but they cannot interrupt or recast an active crossing.
func begin_occlusion(direction: float) -> void:
	if not is_instance_valid(anchor_control) or not is_instance_valid(occluder_control) or size.x <= 0.0 or size.y <= 0.0:
		return
	var viewport_rect := Rect2(Vector2.ZERO, size)
	var source_rect := occluder_control.get_global_rect().intersection(viewport_rect).grow(6.0).intersection(viewport_rect)
	var target_rect := anchor_control.get_global_rect().intersection(viewport_rect)
	if source_rect.size.x < 24.0 or source_rect.size.y < 18.0 or target_rect.size.x < 12.0 or target_rect.size.y < 12.0:
		return
	occlusion_source_rect = source_rect
	occlusion_anchor_rect = target_rect
	occlusion_direction = direction
	occlusion_clock = 0.0
	pass


func apply_shader_state() -> void:
	if room_material == null:
		return
	room_material.set_shader_parameter("displacement_px", displacement_px)
	room_material.set_shader_parameter("velocity", velocity_px / MAX_VELOCITY_PX)
	room_material.set_shader_parameter("impact", impact)
	room_material.set_shader_parameter("inertia_displacement_px", Vector3(inertia_displacements[0], inertia_displacements[1], inertia_displacements[2]))
	update_occlusion_shader()
	pass


func update_accent_color() -> void:
	if room_material != null:
		room_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	pass


## Selects the latest visible chat bubble. The preview scene has no transcript, so its closest
## body button becomes a fallback that still demonstrates one real control staying in the air.
func refresh_anchor_control() -> void:
	anchor_refresh_clock = 0.0
	if not is_inside_tree():
		anchor_control = null
		inertia_controls.clear()
		return
	var root := get_tree().root
	anchor_control = find_anchor_candidate(root)
	refresh_inertia_controls(root)
	occluder_control = find_occluder_candidate(root)
	pass


## Selects a second real surface to cross in front of the pinned performer. Another chat bubble
## reads most clearly; compact buttons are used only by the visual preview or an empty transcript.
func find_occluder_candidate(root: Node) -> Control:
	var bubble_candidates: Array[Control] = []
	var button_candidates: Array[Control] = []
	collect_anchor_candidates(root, bubble_candidates, button_candidates)
	var viewport_rect := Rect2(Vector2.ZERO, size)
	var candidates := bubble_candidates.filter(func(candidate: Control) -> bool: return candidate != anchor_control)
	if candidates.is_empty():
		candidates = button_candidates.filter(func(candidate: Control) -> bool: return candidate != anchor_control)
	var best: Control
	var best_score := -INF
	var anchor_center := anchor_control.get_global_rect().get_center() if is_instance_valid(anchor_control) else viewport_rect.get_center()
	for candidate: Control in candidates:
		if not candidate.is_visible_in_tree():
			continue
		var rect := candidate.get_global_rect().intersection(viewport_rect)
		if rect.size.x < 24.0 or rect.size.y < 18.0 or rect.get_area() > viewport_rect.get_area() * 0.45:
			continue
		var score := minf(rect.get_area(), 48000.0) * 0.01 - absf(rect.get_center().y - anchor_center.y)
		if score > best_score:
			best = candidate
			best_score = score
	return best


func find_anchor_candidate(root: Node) -> Control:
	var bubble_candidates: Array[Control] = []
	var button_candidates: Array[Control] = []
	collect_anchor_candidates(root, bubble_candidates, button_candidates)
	var viewport_rect := Rect2(Vector2.ZERO, size)
	var candidates := bubble_candidates if not bubble_candidates.is_empty() else button_candidates
	var best: Control
	var best_score := -INF
	for candidate: Control in candidates:
		if not candidate.is_visible_in_tree():
			continue
		var visible_rect := candidate.get_global_rect().intersection(viewport_rect)
		if visible_rect.size.x < 12.0 or visible_rect.size.y < 12.0:
			continue
		var center_distance := visible_rect.get_center().distance_to(viewport_rect.get_center())
		var score := visible_rect.end.y * 4.0 + visible_rect.get_area() * 0.002 - center_distance
		if score > best_score:
			best = candidate
			best_score = score
	return best


func collect_anchor_candidates(node: Node, bubbles: Array[Control], buttons: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is BubbleContainer:
			bubbles.append(child as Control)
		elif child is BaseButton and (child as BaseButton).global_position.y > float(AgentLayout.TOOLBAR_HEIGHT):
			buttons.append(child as Control)
		collect_anchor_candidates(child, bubbles, buttons)
	pass


func refresh_inertia_controls(root: Node) -> void:
	var candidates: Array[Control] = []
	collect_inertia_candidates(root, candidates)
	var viewport_rect := Rect2(Vector2.ZERO, size)
	candidates = candidates.filter(func(candidate: Control) -> bool:
		if candidate == anchor_control or not candidate.is_visible_in_tree():
			return false
		var rect := candidate.get_global_rect().intersection(viewport_rect)
		return rect.size.x >= 10.0 and rect.size.y >= 10.0
	)
	candidates.sort_custom(func(first: Control, second: Control) -> bool:
		return inertia_candidate_score(first, viewport_rect) > inertia_candidate_score(second, viewport_rect)
	)
	inertia_controls.clear()
	for index in range(mini(INERTIA_CONTROL_COUNT, candidates.size())):
		inertia_controls.append(candidates[index])
	pass


func collect_inertia_candidates(node: Node, candidates: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is BaseButton or child is VScrollBar:
			candidates.append(child as Control)
		collect_inertia_candidates(child, candidates)
	pass


func inertia_candidate_score(candidate: Control, viewport_rect: Rect2) -> float:
	var rect := candidate.get_global_rect().intersection(viewport_rect)
	var center_distance := rect.get_center().distance_to(viewport_rect.get_center())
	return rect.get_area() * 0.02 - center_distance + rect.position.y * 0.5


func update_anchor_shader() -> void:
	if room_material == null:
		return
	update_inertia_shader()
	if not is_instance_valid(anchor_control) or size.x <= 0.0 or size.y <= 0.0:
		room_material.set_shader_parameter("anchor_enabled", 0.0)
		return
	var visible_rect := anchor_control.get_global_rect().intersection(Rect2(Vector2.ZERO, size)).grow(ANCHOR_MARGIN_PX)
	visible_rect = visible_rect.intersection(Rect2(Vector2.ZERO, size))
	if visible_rect.size.x < 12.0 or visible_rect.size.y < 12.0:
		room_material.set_shader_parameter("anchor_enabled", 0.0)
		return
	room_material.set_shader_parameter("anchor_rect_uv", normalized_anchor_rect(visible_rect, size))
	room_material.set_shader_parameter("anchor_enabled", 1.0)
	pass


func update_inertia_shader() -> void:
	if room_material == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var enabled := Vector3.ZERO
	var viewport_rect := Rect2(Vector2.ZERO, size)
	for index in range(INERTIA_CONTROL_COUNT):
		if index >= inertia_controls.size() or not is_instance_valid(inertia_controls[index]):
			continue
		var rect := inertia_controls[index].get_global_rect().intersection(viewport_rect).grow(4.0).intersection(viewport_rect)
		if rect.size.x < 10.0 or rect.size.y < 10.0:
			continue
		room_material.set_shader_parameter("inertia_rect_%d_uv" % index, normalized_anchor_rect(rect, size))
		enabled[index] = 1.0
	room_material.set_shader_parameter("inertia_enabled", enabled)
	pass


func update_occlusion_shader() -> void:
	if room_material == null:
		return
	var progress := clampf(occlusion_clock / OCCLUSION_DURATION_SECONDS, 0.0, 1.0)
	if progress >= 1.0 or size.x <= 0.0 or size.y <= 0.0:
		room_material.set_shader_parameter("occluder_enabled", 0.0)
		return
	if occlusion_source_rect.size.x < 24.0 or occlusion_source_rect.size.y < 18.0 or occlusion_anchor_rect.size.x < 12.0 or occlusion_anchor_rect.size.y < 12.0:
		room_material.set_shader_parameter("occluder_enabled", 0.0)
		return
	var offset := occlusion_offset_px(occlusion_source_rect, occlusion_anchor_rect, progress, occlusion_direction)
	room_material.set_shader_parameter("occluder_rect_uv", normalized_anchor_rect(occlusion_source_rect, size))
	room_material.set_shader_parameter("occluder_offset_px", offset)
	room_material.set_shader_parameter("occluder_enabled", occlusion_opacity(progress))
	pass


func reset_motion() -> void:
	displacement_px = 0.0
	velocity_px = 0.0
	impact = 0.0
	event_direction = 1.0
	anchor_refresh_clock = ANCHOR_REFRESH_SECONDS
	occlusion_clock = OCCLUSION_DURATION_SECONDS
	occlusion_source_rect = Rect2()
	occlusion_anchor_rect = Rect2()
	for index in range(INERTIA_CONTROL_COUNT):
		inertia_displacements[index] = 0.0
		inertia_velocities[index] = 0.0
	apply_shader_state()
	pass


static func impulse_for_sentence(text: String) -> float:
	return clampf(300.0 + sqrt(float(text.strip_edges().length())) * 54.0, 360.0, 780.0)


static func normalized_anchor_rect(rect: Rect2, viewport_size: Vector2) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4.ZERO
	return Vector4(rect.position.x / viewport_size.x, rect.position.y / viewport_size.y, rect.size.x / viewport_size.x, rect.size.y / viewport_size.y)


static func occlusion_offset_px(source_rect: Rect2, anchor_rect: Rect2, progress: float, direction: float) -> Vector2:
	var signed_direction := 1.0 if direction >= 0.0 else -1.0
	var travel_half := anchor_rect.size.x * 0.5 + source_rect.size.x * 0.5 + OCCLUSION_EDGE_GAP_PX
	var eased_progress := smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0))
	var desired_center := anchor_rect.get_center() + Vector2(lerpf(-travel_half, travel_half, eased_progress) * signed_direction, sin(eased_progress * PI) * -10.0)
	return desired_center - source_rect.get_center()


static func occlusion_opacity(progress: float) -> float:
	var safe_progress := clampf(progress, 0.0, 1.0)
	return smoothstep(0.0, 0.13, safe_progress) * (1.0 - smoothstep(0.82, 1.0, safe_progress))
