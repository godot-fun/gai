class_name ReadingLoupe
extends VisualEffect

## One irreversible loupe zoom onto the latest chat bubble. After the shot is close
## enough to read, the loupe scans left to right and back again so every glyph passes
## through the frame. A new chat entry retargets the scan; the run's end is the only
## pullback.

const READING_LOUPE_SHADER: Shader = preload("res://agent/ui/visuals/reading_loupe/ReadingLoupe.gdshader")
const MAX_ZOOM := 2.4
const MIN_FRAME_ZOOM := 1.55
const FRAME_PADDING := 0.04
const APPROACH_POWER := 1.0
const AMBIENT_APPROACH_PER_SECOND := 0.04
const REASONING_APPROACH_PER_SECOND := 0.12
const APPROACH_SPRING := 8.4
const APPROACH_DAMPING := 9.6
const RELEASE_SPRING := 24.0
const RELEASE_DAMPING := 12.0
const FOCUS_SPEED := 0.12
const SCAN_ONE_WAY_SECONDS := 3.2
const ANCHOR_REFRESH_SECONDS := 0.16
const IDLE_EPSILON := 0.0008
const PULLBACK_WAIT_MSEC := 1800


var screen_rect: ColorRect
var loupe_material: ShaderMaterial
var approach: float = 0.0
var target_approach: float = 0.0
var approach_velocity: float = 0.0
var reasoning_rate: float = 0.0
var focus_uv := Vector2(0.5, 0.58)
var target_focus_uv := Vector2(0.5, 0.58)
var scan_t: float = 0.0
var scan_direction: float = 1.0
var frame_zoom: float = 1.0
var frame_control: Control
var frame_id: int = 0
var chat_area_control: Control
var releasing: bool = false
var retargeting: bool = false
var anchor_refresh_clock: float = ANCHOR_REFRESH_SECONDS


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "ReadingLoupeSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loupe_material = ShaderMaterial.new()
	loupe_material.shader = READING_LOUPE_SHADER
	screen_rect.material = loupe_material
	add_child(screen_rect)
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.18


func fade_out_seconds() -> float:
	return 0.32


func on_agent_start(_session_id: int) -> void:
	reset_shot()
	refresh_frame_control()
	update_focus_targets()
	add_approach(0.22)
	pass


func on_agent_end(_session_id: int, _error_message: String) -> void:
	begin_pullback()
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < PULLBACK_WAIT_MSEC and approach > 0.04:
		await get_tree().process_frame
	pass


func on_turn_start(_session_id: int) -> void:
	add_approach(0.018)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty() or releasing:
		return
	var chunk_energy := stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		reasoning_rate = combine_energy(reasoning_rate, clampf(chunk_energy * 6.5, 0.08, 1.0))
		add_approach(chunk_energy * 0.52)
		return
	add_approach(chunk_energy * 0.22)
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	request_anchor_refresh()
	add_approach(0.032)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	request_anchor_refresh()
	add_approach(0.028)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, _result: AgentToolResult) -> void:
	request_anchor_refresh()
	pass


func on_chat_entry_add(_session_id: int, _entry: ChatEntry) -> void:
	refresh_frame_control()
	update_focus_targets()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	anchor_refresh_clock += delta
	if anchor_refresh_clock >= ANCHOR_REFRESH_SECONDS:
		refresh_frame_control()
	update_focus_targets()
	step_shot(delta)
	apply_shader_state()
	pass


func add_approach(amount: float) -> void:
	if releasing or amount <= 0.0:
		return
	target_approach = clampf(target_approach + amount, 0.0, 1.0)
	pass


func begin_pullback() -> void:
	releasing = true
	target_approach = 0.0
	reasoning_rate = 0.0
	pass


func step_shot(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	if releasing:
		step_release(safe_delta)
	else:
		step_approach(safe_delta)
		if retargeting:
			if not focus_is_traveling(focus_uv, target_focus_uv):
				retargeting = false
				step_scan(safe_delta)
		else:
			step_scan(safe_delta)
	focus_uv = step_focus(focus_uv, target_focus_uv, safe_delta)
	pass


func step_approach(delta: float) -> void:
	target_approach = clampf(target_approach + (AMBIENT_APPROACH_PER_SECOND + reasoning_rate * REASONING_APPROACH_PER_SECOND) * delta, 0.0, 1.0)
	var acceleration := (target_approach - approach) * APPROACH_SPRING - approach_velocity * APPROACH_DAMPING
	approach_velocity += acceleration * delta
	var next_approach := approach + approach_velocity * delta
	if next_approach < approach:
		next_approach = approach
		approach_velocity = maxf(approach_velocity, 0.0)
	approach = clampf(next_approach, 0.0, 1.0)
	if is_equal_approx(approach, target_approach):
		approach_velocity = 0.0
	reasoning_rate = move_toward(reasoning_rate, 0.0, 0.55 * delta)
	if reasoning_rate < IDLE_EPSILON:
		reasoning_rate = 0.0
	pass


func step_release(delta: float) -> void:
	var acceleration := (0.0 - approach) * RELEASE_SPRING - approach_velocity * RELEASE_DAMPING
	approach_velocity += acceleration * delta
	approach = clampf(approach + approach_velocity * delta, 0.0, 1.0)
	if approach < IDLE_EPSILON and absf(approach_velocity) < 0.02:
		approach = 0.0
		approach_velocity = 0.0
	pass


func step_scan(delta: float) -> void:
	var next := scan_step(scan_t, scan_direction, delta, SCAN_ONE_WAY_SECONDS)
	scan_t = next.x
	scan_direction = next.y
	pass


func apply_shader_state() -> void:
	if loupe_material == null:
		return
	loupe_material.set_shader_parameter("zoom_scale", zoom_for_approach(approach, frame_zoom))
	loupe_material.set_shader_parameter("focus_uv", focus_uv)
	loupe_material.set_shader_parameter("lateral_uv", Vector2.ZERO)
	loupe_material.set_shader_parameter("defocus", 0.0)
	pass


func request_anchor_refresh() -> void:
	anchor_refresh_clock = ANCHOR_REFRESH_SECONDS
	pass


func refresh_frame_control() -> void:
	anchor_refresh_clock = 0.0
	var previous_id := frame_id
	frame_control = null
	chat_area_control = null
	if not is_inside_tree():
		return
	var transcript_root := find_visible_control_named(get_tree().root, "ChatListsContainer")
	if transcript_root != null:
		chat_area_control = transcript_root.get_parent() as Control
		var bubbles: Array[Control] = []
		collect_bubbles(transcript_root, bubbles)
		var clip_rect := chat_area_control.get_global_rect() if chat_area_control != null else Rect2(Vector2.ZERO, size)
		var visible_bubbles := visible_controls(bubbles, clip_rect)
		if not visible_bubbles.is_empty():
			frame_control = visible_bubbles[visible_bubbles.size() - 1]
	else:
		var preview_buttons: Array[Control] = []
		collect_preview_buttons(get_tree().root, preview_buttons)
		var visible_buttons := visible_controls(preview_buttons, Rect2(Vector2.ZERO, size))
		if not visible_buttons.is_empty():
			frame_control = visible_buttons[visible_buttons.size() - 1]
	frame_id = frame_control.get_instance_id() if is_instance_valid(frame_control) else 0
	if scan_should_reset(previous_id, frame_id):
		scan_t = 0.0
		scan_direction = 1.0
		retargeting = true
	pass


func update_focus_targets() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if not is_instance_valid(frame_control):
		return
	var viewport_rect := Rect2(Vector2.ZERO, size)
	var frame_rect := frame_control.get_global_rect().intersection(viewport_rect)
	if frame_rect.size.x < 8.0 or frame_rect.size.y < 8.0:
		return
	frame_zoom = fit_zoom_for_rect(frame_rect, size)
	var live_zoom := zoom_for_approach(approach, frame_zoom)
	target_focus_uv = scan_focus_uv(frame_rect, size, live_zoom, scan_t)
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


func collect_preview_buttons(node: Node, buttons: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is BaseButton and (child as BaseButton).global_position.y > float(AgentLayout.TOOLBAR_HEIGHT):
			buttons.append(child as Control)
		collect_preview_buttons(child, buttons)
	pass


func visible_controls(candidates: Array[Control], clip_rect: Rect2) -> Array[Control]:
	var viewport_rect := Rect2(Vector2.ZERO, size).intersection(clip_rect)
	var result: Array[Control] = []
	for candidate: Control in candidates:
		if not candidate.is_visible_in_tree():
			continue
		var visible_rect := candidate.get_global_rect().intersection(viewport_rect)
		if visible_rect.size.x >= 24.0 and visible_rect.size.y >= 12.0:
			result.append(candidate)
	result.sort_custom(func(first: Control, second: Control) -> bool:
		return first.global_position.y < second.global_position.y
	)
	return result


func reset_shot() -> void:
	approach = 0.0
	target_approach = 0.0
	approach_velocity = 0.0
	reasoning_rate = 0.0
	focus_uv = Vector2(0.5, 0.58)
	target_focus_uv = focus_uv
	scan_t = 0.0
	scan_direction = 1.0
	frame_zoom = 1.0
	frame_id = 0
	releasing = false
	retargeting = false
	anchor_refresh_clock = ANCHOR_REFRESH_SECONDS
	apply_shader_state()
	pass


static func combine_energy(current: float, incoming: float) -> float:
	var safe_current := clampf(current, 0.0, 1.0)
	var safe_incoming := clampf(incoming, 0.0, 1.0)
	return 1.0 - (1.0 - safe_current) * (1.0 - safe_incoming)


static func stream_energy_for_length(length: int) -> float:
	return clampf(float(length) * 0.0016, 0.003, 0.040)


static func zoom_for_approach(amount: float, target_zoom: float) -> float:
	var weight := pow(clampf(amount, 0.0, 1.0), APPROACH_POWER)
	var safe_target := clampf(target_zoom, 1.0, MAX_ZOOM)
	return lerpf(1.0, safe_target, weight)


static func fit_zoom_for_rect(rect: Rect2, viewport: Vector2, padding: float = FRAME_PADDING) -> float:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0 or viewport.x <= 0.0 or viewport.y <= 0.0:
		return 1.0
	var inner := clampf(1.0 - 2.0 * padding, 0.2, 1.0)
	var size_uv := rect.size / viewport
	var zoom_x := inner / maxf(size_uv.x, 0.001)
	var zoom_y := inner / maxf(size_uv.y, 0.001)
	var cover := maxf(zoom_x, zoom_y)
	return clampf(maxf(cover, MIN_FRAME_ZOOM), 1.0, MAX_ZOOM)


static func step_focus(current: Vector2, target: Vector2, delta: float, speed: float = FOCUS_SPEED) -> Vector2:
	return current.move_toward(target, maxf(speed, 0.0) * maxf(delta, 0.0))


static func focus_is_traveling(current: Vector2, target: Vector2, arrive_epsilon: float = 0.004) -> bool:
	return current.distance_to(target) > arrive_epsilon


static func scan_step(current_t: float, direction: float, delta: float, one_way_seconds: float) -> Vector2:
	var period := maxf(one_way_seconds, 0.05)
	var signed := 1.0 if direction >= 0.0 else -1.0
	var next_t := clampf(current_t + signed * delta / period, 0.0, 1.0)
	var next_dir := signed
	if next_t >= 1.0:
		next_t = 1.0
		next_dir = -1.0
	elif next_t <= 0.0:
		next_t = 0.0
		next_dir = 1.0
	return Vector2(next_t, next_dir)


static func scan_should_reset(previous_id: int, next_id: int) -> bool:
	return next_id != 0 and next_id != previous_id


static func scan_focus_uv(rect: Rect2, viewport: Vector2, zoom: float, amount: float) -> Vector2:
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return Vector2(0.5, 0.5)
	var left := rect.position.x / viewport.x
	var right := rect.end.x / viewport.x
	var half := 0.5 / maxf(zoom, 1.0)
	var start_x := left + half
	var end_x := right - half
	if end_x < start_x:
		start_x = (left + right) * 0.5
		end_x = start_x
	return Vector2(lerpf(start_x, end_x, clampf(amount, 0.0, 1.0)), rect.get_center().y / viewport.y)


static func view_center_uv(focus: Vector2, lateral: Vector2, zoom: float) -> Vector2:
	var safe_zoom := maxf(zoom, 1.0)
	var half := Vector2(0.5, 0.5) / safe_zoom
	return (focus + lateral).clamp(half, Vector2.ONE - half)


static func sample_uv(screen_uv: Vector2, focus: Vector2, lateral: Vector2, zoom: float) -> Vector2:
	return view_center_uv(focus, lateral, zoom) + (screen_uv - Vector2(0.5, 0.5)) / maxf(zoom, 1.0)
