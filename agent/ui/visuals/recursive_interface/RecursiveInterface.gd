class_name RecursiveInterface
extends VisualEffect

## Turns the latest chat bubble into a temporary portal containing the complete interface. The
## shader explicitly remaps the portal inside each sampled copy, producing four levels of true
## screen-within-screen recursion without persistent feedback or generated overlay decoration.

const RECURSIVE_SHADER: Shader = preload("res://agent/ui/visuals/recursive_interface/RecursiveInterface.gdshader")
const ENERGY_DECAY_PER_SECOND := 0.38
const ANCHOR_REFRESH_SECONDS := 0.18
const PORTAL_MARGIN_PX := 5.0
const PORTAL_COUNT := 8
const PORTAL_STRENGTHS_NEAR := Vector4(1.0, 0.72, 0.51, 0.36)
const PORTAL_STRENGTHS_FAR := Vector4(0.25, 0.17, 0.11, 0.07)
const IDLE_EPSILON := 0.001

var screen_rect: ColorRect
var recursive_material: ShaderMaterial
var recursion_energy: float = 0.0
var recursion_phase: float = 0.0
var recursion_direction: float = 1.0
var anchor_controls: Array[Control] = []
var anchor_refresh_clock: float = ANCHOR_REFRESH_SECONDS


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "RecursiveInterfaceSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	recursive_material = ShaderMaterial.new()
	recursive_material.shader = RECURSIVE_SHADER
	recursive_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	recursive_material.set_shader_parameter("portal_enabled_near", Vector4.ZERO)
	recursive_material.set_shader_parameter("portal_enabled_far", Vector4.ZERO)
	recursive_material.set_shader_parameter("portal_strengths_near", PORTAL_STRENGTHS_NEAR)
	recursive_material.set_shader_parameter("portal_strengths_far", PORTAL_STRENGTHS_FAR)
	screen_rect.material = recursive_material
	add_child(screen_rect)
	gdf.events.theme_color_changed.connect(update_accent_color)
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.14


func fade_out_seconds() -> float:
	return 0.28


func on_agent_start(_session_id: int) -> void:
	reset_recursion()
	refresh_anchor_control()
	pulse(0.48)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	pulse(1.0 if StringUtils.is_not_blank(error_message) else 0.76)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 1000 and recursion_energy > 0.14:
		await get_tree().process_frame
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	recursion_energy = combine_energy(recursion_energy, stream_energy_for_length(chunk.length()))
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	request_anchor_refresh()
	pulse(0.62)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	request_anchor_refresh()
	pulse(0.90, 1.0)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	pulse(1.0 if result.is_error else 0.74, -1.0)
	pass


func on_chat_entry_add(_session_id: int, _entry: ChatEntry) -> void:
	request_anchor_refresh()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	anchor_refresh_clock += delta
	if anchor_refresh_clock >= ANCHOR_REFRESH_SECONDS:
		refresh_anchor_control()
	update_portal_rect()
	step_recursion(delta)
	apply_shader_state()
	pass


func pulse(strength: float, requested_direction: float = 0.0) -> void:
	# An active recursive journey is never replaced. New events deepen it; direction changes are
	# accepted only when the previous journey has almost completely settled.
	if recursion_energy <= 0.14:
		if requested_direction == 0.0:
			recursion_direction = -recursion_direction
		else:
			recursion_direction = signf(requested_direction)
	recursion_energy = combine_energy(recursion_energy, strength)
	pass


func step_recursion(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var phase_speed := lerpf(0.48, 1.65, recursion_energy)
	recursion_phase = fmod(recursion_phase + safe_delta * phase_speed * recursion_direction, TAU * 4.0)
	recursion_energy = move_toward(recursion_energy, 0.0, ENERGY_DECAY_PER_SECOND * safe_delta)
	if recursion_energy < IDLE_EPSILON:
		recursion_energy = 0.0
	pass


func apply_shader_state() -> void:
	if recursive_material == null:
		return
	recursive_material.set_shader_parameter("recursion_energy", recursion_energy)
	recursive_material.set_shader_parameter("recursion_phase", recursion_phase)
	recursive_material.set_shader_parameter("recursion_direction", recursion_direction)
	pass


func update_accent_color() -> void:
	if recursive_material != null:
		recursive_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	pass


func request_anchor_refresh() -> void:
	anchor_refresh_clock = ANCHOR_REFRESH_SECONDS
	pass


func refresh_anchor_control() -> void:
	anchor_refresh_clock = 0.0
	if not is_inside_tree():
		anchor_controls.clear()
		return
	anchor_controls = find_anchor_candidates(get_tree().root)
	pass


func find_anchor_candidates(root: Node) -> Array[Control]:
	var bubble_candidates: Array[Control] = []
	var button_candidates: Array[Control] = []
	collect_anchor_candidates(root, bubble_candidates, button_candidates)
	var viewport_rect := Rect2(Vector2.ZERO, size)
	var visible_bubbles: Array[Control] = []
	for bubble: Control in bubble_candidates:
		if not bubble.is_visible_in_tree():
			continue
		var bubble_rect := bubble.get_global_rect().intersection(viewport_rect)
		if bubble_rect.size.x >= 64.0 and bubble_rect.size.y >= 28.0:
			visible_bubbles.append(bubble)
	var result: Array[Control] = []
	for index: int in portal_candidate_indices(visible_bubbles.size()):
		result.append(visible_bubbles[index])
	if not result.is_empty():
		return result
	# Preview scenes have no transcript. Use up to four visible body buttons so the multi-portal
	# composition can still be evaluated without changing production selection rules.
	for index in range(button_candidates.size() - 1, -1, -1):
		var button := button_candidates[index]
		var button_rect := button.get_global_rect().intersection(viewport_rect)
		if button.is_visible_in_tree() and button_rect.size.x >= 36.0 and button_rect.size.y >= 20.0:
			result.append(button)
			if result.size() >= PORTAL_COUNT:
				break
	return result


func collect_anchor_candidates(node: Node, bubbles: Array[Control], buttons: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is BubbleContainer:
			bubbles.append(child as Control)
		elif child is BaseButton and (child as BaseButton).global_position.y > float(AgentLayout.TOOLBAR_HEIGHT):
			buttons.append(child as Control)
		collect_anchor_candidates(child, bubbles, buttons)
	pass


func update_portal_rect() -> void:
	if recursive_material == null:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		recursive_material.set_shader_parameter("portal_enabled_near", Vector4.ZERO)
		recursive_material.set_shader_parameter("portal_enabled_far", Vector4.ZERO)
		return
	var viewport_rect := Rect2(Vector2.ZERO, size)
	var enabled_near := Vector4.ZERO
	var enabled_far := Vector4.ZERO
	for index in range(PORTAL_COUNT):
		if index >= anchor_controls.size() or not is_instance_valid(anchor_controls[index]):
			continue
		var visible_rect := anchor_controls[index].get_global_rect().intersection(viewport_rect).grow(PORTAL_MARGIN_PX).intersection(viewport_rect)
		if visible_rect.size.x < 36.0 or visible_rect.size.y < 20.0:
			continue
		recursive_material.set_shader_parameter("portal_rect_%d_uv" % index, normalized_rect(visible_rect, size))
		if index < 4:
			enabled_near[index] = 1.0
		else:
			enabled_far[index - 4] = 1.0
	recursive_material.set_shader_parameter("portal_enabled_near", enabled_near)
	recursive_material.set_shader_parameter("portal_enabled_far", enabled_far)
	pass


func reset_recursion() -> void:
	recursion_energy = 0.0
	recursion_phase = 0.0
	recursion_direction = 1.0
	anchor_refresh_clock = ANCHOR_REFRESH_SECONDS
	apply_shader_state()
	pass


static func combine_energy(current: float, incoming: float) -> float:
	var safe_current := clampf(current, 0.0, 1.0)
	var safe_incoming := clampf(incoming, 0.0, 1.0)
	return 1.0 - (1.0 - safe_current) * (1.0 - safe_incoming)


static func stream_energy_for_length(length: int) -> float:
	return clampf(float(length) * 0.0014, 0.003, 0.032)


static func portal_candidate_indices(visible_count: int) -> Array[int]:
	var result: Array[int] = []
	# Index visible_count - 1 is the newest bubble and remains untouched. Walk upward through the
	# preceding eight bubbles, ordered from strongest portal to weakest.
	for offset in range(2, mini(visible_count + 1, PORTAL_COUNT + 2)):
		result.append(visible_count - offset)
	return result


static func normalized_rect(rect: Rect2, viewport_size: Vector2) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4.ZERO
	return Vector4(rect.position.x / viewport_size.x, rect.position.y / viewport_size.y, rect.size.x / viewport_size.x, rect.size.y / viewport_size.y)
