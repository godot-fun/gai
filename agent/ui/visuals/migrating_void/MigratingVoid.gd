class_name MigratingVoid
extends VisualEffect

## Makes absence into a moving layout object. Each transcript entry owns a complete journey before
## the next one begins, so a new event cannot steal the void from a bubble already in motion.

const VOID_SHADER: Shader = preload("res://agent/ui/visuals/migrating_void/MigratingVoid.gdshader")
const ENERGY_DECAY_PER_SECOND := 0.30
const VOID_SPRING := 48.0
const VOID_DAMPING := 12.4
const ROUTE_SPEED := 0.85
const VOID_WIDTH_PX := 248.0
const VOID_HEIGHT_PX := 92.0
const LAYOUT_REFRESH_SECONDS := 0.20
const IDLE_EPSILON := 0.001

var screen_rect: ColorRect
var void_material: ShaderMaterial
var void_energy: float = 0.0
var void_amount: float = 0.0
var void_velocity: float = 0.0
var route_phase: float = 0.0
var void_origin := Vector2(0.72, 0.58)
var void_destination := Vector2(0.12, 0.58)
var layout_refresh_clock: float = LAYOUT_REFRESH_SECONDS
var newest_bubble: Control
var active_bubble: Control
var pending_bubbles: Array[Control] = []
var seen_bubble_ids: Dictionary[int, bool] = {}
var has_initialized_bubble_targets: bool = false
var is_handing_off: bool = false
var chat_area_control: Control
var sidebar_area_control: Control


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "MigratingVoidSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	void_material = ShaderMaterial.new()
	void_material.shader = VOID_SHADER
	void_material.set_shader_parameter("void_color", Colors.surface)
	void_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	void_material.set_shader_parameter("effect_area_rect", effect_area_rect(size, float(AgentLayout.TOOLBAR_HEIGHT)))
	screen_rect.material = void_material
	add_child(screen_rect)
	resized.connect(on_resized)
	gdf.events.theme_color_changed.connect(update_theme_colors)
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.14


func fade_out_seconds() -> float:
	return 0.34


func on_agent_start(_session_id: int) -> void:
	reset_void()
	refresh_layout()
	pulse(0.58)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	pulse(1.0 if StringUtils.is_not_blank(error_message) else 0.74)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 1400 and (void_energy > 0.08 or void_amount > 0.05):
		await get_tree().process_frame
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	void_energy = combine_energy(void_energy, stream_energy_for_length(chunk.length()))
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	request_layout_refresh()
	pulse(0.68)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	request_layout_refresh()
	pulse(0.94)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	pulse(1.0 if result.is_error else 0.80)
	pass


func on_chat_entry_add(_session_id: int, _entry: ChatEntry) -> void:
	request_layout_refresh()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	layout_refresh_clock += delta
	if layout_refresh_clock >= LAYOUT_REFRESH_SECONDS:
		refresh_layout()
	step_void(delta)
	apply_shader_state()
	pass


func pulse(strength: float) -> void:
	void_energy = combine_energy(void_energy, strength)
	pass


func step_void(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var has_active_journey := is_instance_valid(active_bubble) and not is_handing_off
	var target_amount := smoothstep(0.04, 0.72, void_energy) if has_active_journey else 0.0
	var acceleration := (target_amount - void_amount) * VOID_SPRING - void_velocity * VOID_DAMPING
	void_velocity += acceleration * safe_delta
	void_amount = clampf(void_amount + void_velocity * safe_delta, 0.0, 1.0)
	if void_amount == 0.0 or void_amount == 1.0:
		void_velocity *= 0.52
	if has_active_journey:
		route_phase = minf(route_phase + safe_delta * lerpf(0.34, ROUTE_SPEED, void_amount), 1.0)
		if cycle_is_finished(route_phase):
			is_handing_off = true
	elif is_handing_off and void_amount < 0.025 and absf(void_velocity) < 0.12:
		finish_active_journey()
	void_energy = move_toward(void_energy, 0.0, ENERGY_DECAY_PER_SECOND * safe_delta)
	if void_energy < IDLE_EPSILON:
		void_energy = 0.0
	if void_energy == 0.0 and void_amount < IDLE_EPSILON and absf(void_velocity) < IDLE_EPSILON:
		void_amount = 0.0
		void_velocity = 0.0
	pass


func refresh_layout() -> void:
	layout_refresh_clock = 0.0
	newest_bubble = null
	chat_area_control = null
	sidebar_area_control = null
	if not is_inside_tree() or size.x <= 0.0 or size.y <= 0.0:
		return
	var root := get_tree().root
	var transcript_root := find_visible_control_named(root, "ChatListsContainer")
	if transcript_root != null:
		chat_area_control = transcript_root.get_parent() as Control
		var bubbles: Array[Control] = []
		collect_bubbles(transcript_root, bubbles)
		var clip_rect := chat_area_control.get_global_rect() if chat_area_control != null else Rect2(Vector2.ZERO, size)
		var visible_bubbles := visible_controls(bubbles, clip_rect)
		if not visible_bubbles.is_empty():
			newest_bubble = visible_bubbles[visible_bubbles.size() - 1]
			enqueue_visible_bubbles(visible_bubbles)
	var session_scroll := find_visible_control_named(root, "SessionListScroll")
	if session_scroll != null:
		sidebar_area_control = session_scroll
	update_route_geometry()
	pass


func update_route_geometry() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var viewport_rect := Rect2(Vector2.ZERO, size)
	if is_instance_valid(active_bubble):
		var bubble_rect := active_bubble.get_global_rect().intersection(viewport_rect)
		if bubble_rect.size.x >= 32.0 and bubble_rect.size.y >= 16.0:
			void_origin = clamp_route_point(bubble_rect.get_center() / size)
	if is_instance_valid(sidebar_area_control):
		var sidebar_rect := sidebar_area_control.get_global_rect().intersection(viewport_rect)
		if sidebar_rect.size.x >= 32.0 and sidebar_rect.size.y >= 32.0:
			void_destination = clamp_route_point(Vector2(sidebar_rect.get_center().x / size.x, void_origin.y))
	else:
		void_destination = clamp_route_point(Vector2(0.12, void_origin.y))
	pass


func apply_shader_state() -> void:
	if void_material == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var journey := route_progress(route_phase)
	var center := void_origin.lerp(void_destination, journey)
	void_material.set_shader_parameter("void_center", center)
	void_material.set_shader_parameter("void_size", void_size_normalized(size, VOID_WIDTH_PX, VOID_HEIGHT_PX))
	void_material.set_shader_parameter("void_amount", void_amount)
	void_material.set_shader_parameter("effect_area_rect", effect_area_rect(size, float(AgentLayout.TOOLBAR_HEIGHT)))
	pass


func request_layout_refresh() -> void:
	layout_refresh_clock = LAYOUT_REFRESH_SECONDS
	pass


func on_resized() -> void:
	request_layout_refresh()
	pass


func update_theme_colors() -> void:
	if void_material != null:
		void_material.set_shader_parameter("void_color", Colors.surface)
		void_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	pass


func reset_void() -> void:
	void_energy = 0.0
	void_amount = 0.0
	void_velocity = 0.0
	route_phase = 0.0
	void_origin = Vector2(0.72, 0.58)
	void_destination = Vector2(0.12, 0.58)
	newest_bubble = null
	active_bubble = null
	pending_bubbles.clear()
	seen_bubble_ids.clear()
	has_initialized_bubble_targets = false
	is_handing_off = false
	layout_refresh_clock = LAYOUT_REFRESH_SECONDS
	apply_shader_state()
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


func enqueue_visible_bubbles(visible_bubbles: Array[Control]) -> void:
	if not has_initialized_bubble_targets:
		has_initialized_bubble_targets = true
		for bubble: Control in visible_bubbles:
			seen_bubble_ids[bubble.get_instance_id()] = true
		active_bubble = visible_bubbles[visible_bubbles.size() - 1]
		route_phase = 0.0
		return
	for bubble: Control in visible_bubbles:
		var bubble_id := bubble.get_instance_id()
		if seen_bubble_ids.has(bubble_id):
			continue
		seen_bubble_ids[bubble_id] = true
		if bubble != active_bubble:
			pending_bubbles.append(bubble)
	if active_bubble == null and not is_handing_off:
		begin_next_bubble()
	pass


func finish_active_journey() -> void:
	active_bubble = null
	is_handing_off = false
	route_phase = 0.0
	begin_next_bubble()
	pass


func begin_next_bubble() -> void:
	while not pending_bubbles.is_empty():
		var candidate: Control = pending_bubbles.pop_front()
		if not is_instance_valid(candidate):
			continue
		active_bubble = candidate
		route_phase = 0.0
		return
	pass


static func combine_energy(current: float, incoming: float) -> float:
	var safe_current := clampf(current, 0.0, 1.0)
	var safe_incoming := clampf(incoming, 0.0, 1.0)
	return 1.0 - (1.0 - safe_current) * (1.0 - safe_incoming)


static func stream_energy_for_length(length: int) -> float:
	return clampf(float(length) * 0.0015, 0.003, 0.040)


static func route_progress(phase: float) -> float:
	var wrapped := fposmod(phase, 2.0)
	return 0.5 - cos(wrapped * PI) * 0.5


static func cycle_is_finished(phase: float) -> bool:
	return phase >= 1.0


static func void_size_normalized(viewport_size: Vector2, width_px: float, height_px: float) -> Vector2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(clampf(width_px / viewport_size.x, 0.04, 0.34), clampf(height_px / viewport_size.y, 0.025, 0.20))


static func effect_area_rect(viewport_size: Vector2, toolbar_height: float) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4.ZERO
	var top := clampf(toolbar_height / viewport_size.y, 0.0, 1.0)
	return Vector4(0.0, top, 1.0, 1.0 - top)


static func clamp_route_point(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 0.08, 0.92), clampf(point.y, 0.14, 0.90))
