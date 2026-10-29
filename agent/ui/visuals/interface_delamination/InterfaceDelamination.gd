class_name InterfaceDelamination
extends VisualEffect

## Separates the rendered interface into material-like depth sheets. Panel surfaces stay near the
## screen while text edges, accent controls, and bright details drift at different parallax rates.

const DELAMINATION_SHADER: Shader = preload("res://agent/ui/visuals/interface_delamination/InterfaceDelamination.gdshader")
const ENERGY_DECAY_PER_SECOND := 0.39
const SPRING_STRENGTH := 58.0
const SPRING_DAMPING := 13.2
const MAX_SEPARATION_PX := 34.0
const ANCHOR_REFRESH_SECONDS := 0.18
const IDLE_EPSILON := 0.001

var screen_rect: ColorRect
var delamination_material: ShaderMaterial
var delamination_energy: float = 0.0
var layer_separation: float = 0.0
var separation_velocity: float = 0.0
var parallax_phase: float = 0.0
var parallax_direction: float = 1.0
var focus_control: Control
var chat_area_control: Control
var anchor_refresh_clock: float = ANCHOR_REFRESH_SECONDS


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "InterfaceDelaminationSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	delamination_material = ShaderMaterial.new()
	delamination_material.shader = DELAMINATION_SHADER
	delamination_material.set_shader_parameter("toolbar_height_px", 0.0)
	delamination_material.set_shader_parameter("max_separation_px", MAX_SEPARATION_PX)
	delamination_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	delamination_material.set_shader_parameter("focus_enabled", 0.0)
	delamination_material.set_shader_parameter("chat_area_enabled", 0.0)
	screen_rect.material = delamination_material
	add_child(screen_rect)
	gdf.events.theme_color_changed.connect(update_accent_color)
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.12


func fade_out_seconds() -> float:
	return 0.28


func on_agent_start(_session_id: int) -> void:
	reset_delamination()
	refresh_focus_control()
	pulse(0.52)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	pulse(1.0 if StringUtils.is_not_blank(error_message) else 0.76)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 1150 and (delamination_energy > 0.10 or layer_separation > 0.08):
		await get_tree().process_frame
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	delamination_energy = combine_energy(delamination_energy, stream_energy_for_length(chunk.length()))
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	request_anchor_refresh()
	pulse(0.66)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	request_anchor_refresh()
	pulse(0.96, -parallax_direction)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	pulse(1.0 if result.is_error else 0.80)
	pass


func on_chat_entry_add(_session_id: int, _entry: ChatEntry) -> void:
	request_anchor_refresh()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	anchor_refresh_clock += delta
	if anchor_refresh_clock >= ANCHOR_REFRESH_SECONDS and (layer_separation < 0.08 or not is_instance_valid(focus_control)):
		refresh_focus_control()
	update_focus_geometry()
	step_delamination(delta)
	apply_shader_state()
	pass


func pulse(strength: float, requested_direction: float = 0.0) -> void:
	if delamination_energy <= 0.12:
		parallax_direction = -parallax_direction if requested_direction == 0.0 else signf(requested_direction)
	delamination_energy = combine_energy(delamination_energy, strength)
	pass


func step_delamination(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var target := smoothstep(0.04, 0.72, delamination_energy)
	var acceleration := (target - layer_separation) * SPRING_STRENGTH - separation_velocity * SPRING_DAMPING
	separation_velocity += acceleration * safe_delta
	layer_separation = clampf(layer_separation + separation_velocity * safe_delta, 0.0, 1.0)
	if layer_separation == 0.0 or layer_separation == 1.0:
		separation_velocity *= 0.52
	parallax_phase = fmod(parallax_phase + safe_delta * lerpf(0.46, 1.48, layer_separation) * parallax_direction, TAU * 4.0)
	delamination_energy = move_toward(delamination_energy, 0.0, ENERGY_DECAY_PER_SECOND * safe_delta)
	if delamination_energy < IDLE_EPSILON:
		delamination_energy = 0.0
	if delamination_energy == 0.0 and layer_separation < IDLE_EPSILON and absf(separation_velocity) < IDLE_EPSILON:
		layer_separation = 0.0
		separation_velocity = 0.0
	pass


func apply_shader_state() -> void:
	if delamination_material == null:
		return
	delamination_material.set_shader_parameter("layer_separation", layer_separation)
	delamination_material.set_shader_parameter("parallax_phase", parallax_phase)
	delamination_material.set_shader_parameter("parallax_direction", parallax_direction)
	pass


func update_accent_color() -> void:
	if delamination_material != null:
		delamination_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	pass


func request_anchor_refresh() -> void:
	anchor_refresh_clock = ANCHOR_REFRESH_SECONDS
	pass


func refresh_focus_control() -> void:
	anchor_refresh_clock = 0.0
	focus_control = null
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
			focus_control = visible_bubbles[latest_focus_candidate_index(visible_bubbles.size())]
		return
	var preview_buttons: Array[Control] = []
	collect_preview_buttons(get_tree().root, preview_buttons)
	var visible_buttons := visible_controls(preview_buttons, Rect2(Vector2.ZERO, size))
	if not visible_buttons.is_empty():
		focus_control = visible_buttons[latest_focus_candidate_index(visible_buttons.size())]
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
		if child is BaseButton:
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
		if visible_rect.size.x >= 48.0 and visible_rect.size.y >= 20.0:
			result.append(candidate)
	result.sort_custom(func(first: Control, second: Control) -> bool:
		return first.global_position.y < second.global_position.y
	)
	return result


func update_focus_geometry() -> void:
	if delamination_material == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var viewport_rect := Rect2(Vector2.ZERO, size)
	delamination_material.set_shader_parameter("effect_area_rect", body_effect_rect(size, 0.0))
	if is_instance_valid(chat_area_control):
		var chat_rect := chat_area_control.get_global_rect().intersection(viewport_rect)
		if chat_rect.size.x >= 48.0 and chat_rect.size.y >= 20.0:
			delamination_material.set_shader_parameter("chat_area_rect", normalized_rect(chat_rect, size))
			delamination_material.set_shader_parameter("chat_area_enabled", 1.0)
		else:
			delamination_material.set_shader_parameter("chat_area_enabled", 0.0)
	else:
		delamination_material.set_shader_parameter("chat_area_enabled", 0.0)
	if not is_instance_valid(focus_control):
		delamination_material.set_shader_parameter("focus_enabled", 0.0)
		return
	var focus_rect := focus_control.get_global_rect().intersection(viewport_rect)
	if focus_rect.size.x < 24.0 or focus_rect.size.y < 16.0:
		delamination_material.set_shader_parameter("focus_enabled", 0.0)
		return
	delamination_material.set_shader_parameter("focus_rect", normalized_rect(focus_rect, size))
	delamination_material.set_shader_parameter("focus_enabled", 1.0)
	pass


func reset_delamination() -> void:
	delamination_energy = 0.0
	layer_separation = 0.0
	separation_velocity = 0.0
	parallax_phase = 0.0
	parallax_direction = 1.0
	anchor_refresh_clock = ANCHOR_REFRESH_SECONDS
	apply_shader_state()
	pass


static func combine_energy(current: float, incoming: float) -> float:
	var safe_current := clampf(current, 0.0, 1.0)
	var safe_incoming := clampf(incoming, 0.0, 1.0)
	return 1.0 - (1.0 - safe_current) * (1.0 - safe_incoming)


static func stream_energy_for_length(length: int) -> float:
	return clampf(float(length) * 0.0015, 0.003, 0.038)


static func latest_focus_candidate_index(visible_count: int) -> int:
	return visible_count - 1 if visible_count > 0 else -1


static func normalized_rect(rect: Rect2, viewport_size: Vector2) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4.ZERO
	return Vector4(rect.position.x / viewport_size.x, rect.position.y / viewport_size.y, rect.size.x / viewport_size.x, rect.size.y / viewport_size.y)


static func body_effect_rect(viewport_size: Vector2, toolbar_height: float) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4.ZERO
	var top := clampf(toolbar_height / viewport_size.y, 0.0, 1.0)
	return Vector4(0.0, top, 1.0, 1.0 - top)
