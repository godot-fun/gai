class_name TopologicalFold
extends VisualEffect

## Temporarily rewrites the vertical distance between two transcript entries. Their surrounding
## screen regions bend toward one crease while the newest visible message remains untouched.

const FOLD_SHADER: Shader = preload("res://agent/ui/visuals/topological_fold/TopologicalFold.gdshader")
const ENERGY_DECAY_PER_SECOND := 0.34
const FOLD_SPRING_STRENGTH := 62.0
const FOLD_SPRING_DAMPING := 13.8
const SIDEBAR_FOLD_STRENGTH := 0.62
const ANCHOR_REFRESH_SECONDS := 0.18
const MIN_ANCHOR_GAP_PX := 92.0
const IDLE_EPSILON := 0.001

var screen_rect: ColorRect
var fold_material: ShaderMaterial
var fold_energy: float = 0.0
var fold_amount: float = 0.0
var fold_velocity: float = 0.0
var fold_phase: float = 0.0
var upper_anchor: Control
var lower_anchor: Control
var chat_area_control: Control
var sidebar_upper_anchor: Control
var sidebar_lower_anchor: Control
var sidebar_area_control: Control
var anchor_refresh_clock: float = ANCHOR_REFRESH_SECONDS


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "TopologicalFoldSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fold_material = ShaderMaterial.new()
	fold_material.shader = FOLD_SHADER
	fold_material.set_shader_parameter("toolbar_height_px", float(AgentLayout.TOOLBAR_HEIGHT))
	fold_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	fold_material.set_shader_parameter("anchors_enabled", 0.0)
	fold_material.set_shader_parameter("sidebar_enabled", 0.0)
	fold_material.set_shader_parameter("sidebar_fold_strength", SIDEBAR_FOLD_STRENGTH)
	screen_rect.material = fold_material
	add_child(screen_rect)
	gdf.events.theme_color_changed.connect(update_accent_color)
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.12


func fade_out_seconds() -> float:
	return 0.30


func on_agent_start(_session_id: int) -> void:
	reset_fold()
	refresh_fold_anchors()
	pulse(0.58)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	pulse(1.0 if StringUtils.is_not_blank(error_message) else 0.78)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 1250 and (fold_energy > 0.10 or fold_amount > 0.08):
		await get_tree().process_frame
	pass


func on_message_update(_session_id: int, chunk: String, _stream_kind: String) -> void:
	if chunk.is_empty():
		return
	fold_energy = combine_energy(fold_energy, stream_energy_for_length(chunk.length()))
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	request_anchor_refresh()
	pulse(0.68)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	request_anchor_refresh()
	pulse(0.96)
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
	if anchor_refresh_clock >= ANCHOR_REFRESH_SECONDS and (fold_amount < 0.08 or not any_fold_region_is_valid()):
		refresh_fold_anchors()
	update_fold_geometry()
	step_fold(delta)
	apply_shader_state()
	pass


func pulse(strength: float) -> void:
	fold_energy = combine_energy(fold_energy, strength)
	pass


func step_fold(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var target := smoothstep(0.06, 0.72, fold_energy)
	var acceleration := (target - fold_amount) * FOLD_SPRING_STRENGTH - fold_velocity * FOLD_SPRING_DAMPING
	fold_velocity += acceleration * safe_delta
	fold_amount = clampf(fold_amount + fold_velocity * safe_delta, 0.0, 1.0)
	if fold_amount == 0.0 or fold_amount == 1.0:
		fold_velocity *= 0.52
	fold_phase = fmod(fold_phase + safe_delta * lerpf(0.7, 2.2, fold_amount), TAU * 4.0)
	fold_energy = move_toward(fold_energy, 0.0, ENERGY_DECAY_PER_SECOND * safe_delta)
	if fold_energy < IDLE_EPSILON:
		fold_energy = 0.0
	if fold_energy == 0.0 and fold_amount < IDLE_EPSILON and absf(fold_velocity) < IDLE_EPSILON:
		fold_amount = 0.0
		fold_velocity = 0.0
	pass


func apply_shader_state() -> void:
	if fold_material == null:
		return
	fold_material.set_shader_parameter("fold_amount", fold_amount)
	fold_material.set_shader_parameter("fold_phase", fold_phase)
	pass


func update_accent_color() -> void:
	if fold_material != null:
		fold_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	pass


func request_anchor_refresh() -> void:
	anchor_refresh_clock = ANCHOR_REFRESH_SECONDS
	pass


func refresh_fold_anchors() -> void:
	anchor_refresh_clock = 0.0
	upper_anchor = null
	lower_anchor = null
	chat_area_control = null
	sidebar_upper_anchor = null
	sidebar_lower_anchor = null
	sidebar_area_control = null
	if not is_inside_tree():
		return
	var bubbles: Array[Control] = []
	var candidates: Array[Control] = []
	var transcript_root := find_visible_control_named(get_tree().root, "ChatListsContainer")
	if transcript_root != null:
		chat_area_control = transcript_root.get_parent() as Control
		collect_transcript_bubbles(transcript_root, bubbles)
		var chat_clip_rect := chat_area_control.get_global_rect() if chat_area_control != null else Rect2(Vector2.ZERO, size)
		candidates = visible_candidates(bubbles, chat_clip_rect)
	else:
		# The preview scene has no transcript. Its buttons provide an isolated demonstration, but
		# production never falls back to sidebar or toolbar buttons when a chat viewport exists.
		var preview_buttons: Array[Control] = []
		collect_preview_buttons(get_tree().root, preview_buttons)
		candidates = visible_candidates(preview_buttons, Rect2(Vector2.ZERO, size))
	var indices := fold_candidate_indices(candidates.size())
	if indices.x < 0:
		upper_anchor = null
		lower_anchor = null
	else:
		upper_anchor = candidates[indices.x]
		lower_anchor = candidates[indices.y]
	refresh_sidebar_anchors()
	pass


func refresh_sidebar_anchors() -> void:
	var sidebar := find_visible_control_named(get_tree().root, "Sidebar")
	var session_scroll := find_visible_control_named(get_tree().root, "SessionListScroll")
	if sidebar == null or session_scroll == null:
		return
	# Keep the new-session button stable. The first version's pleasant fold lived inside the
	# scrolling session sheet rather than stretching the complete sidebar shell.
	sidebar_area_control = session_scroll
	var rows: Array[Control] = []
	collect_session_rows(sidebar, rows)
	var candidates := visible_candidates(rows, session_scroll.get_global_rect())
	var indices := sidebar_candidate_indices(candidates.size())
	if indices.x < 0:
		return
	sidebar_upper_anchor = candidates[indices.x]
	sidebar_lower_anchor = candidates[indices.y]
	pass


func find_visible_control_named(node: Node, target_name: String) -> Control:
	if node is Control and node.name == target_name and (node as Control).is_visible_in_tree():
		return node as Control
	for child: Node in node.get_children():
		var result := find_visible_control_named(child, target_name)
		if result != null:
			return result
	return null


func collect_transcript_bubbles(node: Node, bubbles: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is BubbleContainer:
			bubbles.append(child as Control)
		collect_transcript_bubbles(child, bubbles)
	pass


func collect_session_rows(node: Node, rows: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is SessionRow:
			rows.append(child as Control)
		collect_session_rows(child, rows)
	pass


func collect_preview_buttons(node: Node, buttons: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is BaseButton and (child as BaseButton).global_position.y > float(AgentLayout.TOOLBAR_HEIGHT):
			buttons.append(child as Control)
		collect_preview_buttons(child, buttons)
	pass


func visible_candidates(candidates: Array[Control], clip_rect: Rect2) -> Array[Control]:
	var viewport_rect := Rect2(Vector2.ZERO, size).intersection(clip_rect)
	var result: Array[Control] = []
	for candidate: Control in candidates:
		if not candidate.is_visible_in_tree():
			continue
		var visible_rect := candidate.get_global_rect().intersection(viewport_rect)
		if visible_rect.size.x >= 64.0 and visible_rect.size.y >= 24.0:
			result.append(candidate)
	result.sort_custom(func(first: Control, second: Control) -> bool:
		return first.global_position.y < second.global_position.y
	)
	return result


func chat_anchors_are_valid() -> bool:
	return is_instance_valid(upper_anchor) and is_instance_valid(lower_anchor)


func sidebar_anchors_are_valid() -> bool:
	return is_instance_valid(sidebar_upper_anchor) and is_instance_valid(sidebar_lower_anchor)


func any_fold_region_is_valid() -> bool:
	return chat_anchors_are_valid() or sidebar_anchors_are_valid()


func update_fold_geometry() -> void:
	if fold_material == null:
		return
	fold_material.set_shader_parameter("anchors_enabled", 0.0)
	fold_material.set_shader_parameter("sidebar_enabled", 0.0)
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var viewport_rect := Rect2(Vector2.ZERO, size)
	update_chat_fold_geometry(viewport_rect)
	update_sidebar_fold_geometry(viewport_rect)
	pass


func update_chat_fold_geometry(viewport_rect: Rect2) -> void:
	var chat_area_rect := chat_area_control.get_global_rect().intersection(viewport_rect) if is_instance_valid(chat_area_control) else Rect2()
	var upper_rect := Rect2()
	var lower_rect := Rect2()
	if chat_anchors_are_valid():
		upper_rect = upper_anchor.get_global_rect().intersection(viewport_rect)
		lower_rect = lower_anchor.get_global_rect().intersection(viewport_rect)
		if upper_rect.get_center().y > lower_rect.get_center().y:
			var swap_rect := upper_rect
			upper_rect = lower_rect
			lower_rect = swap_rect
		if chat_area_rect.size.x <= 0.0:
			chat_area_rect = Rect2(Vector2(minf(upper_rect.position.x, lower_rect.position.x), 0.0), Vector2(maxf(upper_rect.end.x, lower_rect.end.x) - minf(upper_rect.position.x, lower_rect.position.x), size.y))
	if chat_area_rect.size.x < 64.0 or chat_area_rect.size.y < 64.0:
		return
	if not chat_anchors_are_valid() or lower_rect.get_center().y - upper_rect.get_center().y < MIN_ANCHOR_GAP_PX:
		var fallback_rects := fallback_chat_anchor_rects(chat_area_rect)
		upper_rect = fallback_rects[0]
		lower_rect = fallback_rects[1]
	fold_material.set_shader_parameter("upper_anchor_rect", normalized_rect(upper_rect, size))
	fold_material.set_shader_parameter("lower_anchor_rect", normalized_rect(lower_rect, size))
	fold_material.set_shader_parameter("chat_area_rect", normalized_rect(chat_area_rect, size))
	fold_material.set_shader_parameter("anchors_enabled", 1.0)
	pass


func update_sidebar_fold_geometry(viewport_rect: Rect2) -> void:
	if not sidebar_anchors_are_valid() or not is_instance_valid(sidebar_area_control):
		return
	var upper_rect := sidebar_upper_anchor.get_global_rect().intersection(viewport_rect)
	var lower_rect := sidebar_lower_anchor.get_global_rect().intersection(viewport_rect)
	if upper_rect.get_center().y > lower_rect.get_center().y:
		var swap_rect := upper_rect
		upper_rect = lower_rect
		lower_rect = swap_rect
	if lower_rect.get_center().y - upper_rect.get_center().y < MIN_ANCHOR_GAP_PX:
		return
	var sidebar_rect := sidebar_area_control.get_global_rect().intersection(viewport_rect)
	fold_material.set_shader_parameter("sidebar_upper_anchor_rect", normalized_rect(upper_rect, size))
	fold_material.set_shader_parameter("sidebar_lower_anchor_rect", normalized_rect(lower_rect, size))
	fold_material.set_shader_parameter("sidebar_area_rect", normalized_rect(sidebar_rect, size))
	fold_material.set_shader_parameter("sidebar_enabled", 1.0)
	pass


func reset_fold() -> void:
	fold_energy = 0.0
	fold_amount = 0.0
	fold_velocity = 0.0
	fold_phase = 0.0
	anchor_refresh_clock = ANCHOR_REFRESH_SECONDS
	apply_shader_state()
	pass


static func combine_energy(current: float, incoming: float) -> float:
	var safe_current := clampf(current, 0.0, 1.0)
	var safe_incoming := clampf(incoming, 0.0, 1.0)
	return 1.0 - (1.0 - safe_current) * (1.0 - safe_incoming)


static func stream_energy_for_length(length: int) -> float:
	return clampf(float(length) * 0.0015, 0.003, 0.036)


static func fold_candidate_indices(visible_count: int) -> Vector2i:
	# The newest entry is deliberately excluded. The lower endpoint is the penultimate entry and
	# the upper endpoint reaches up to four entries into the visible transcript.
	if visible_count < 3:
		return Vector2i(-1, -1)
	var lower_index := visible_count - 2
	var upper_index := maxi(0, lower_index - 4)
	return Vector2i(upper_index, lower_index)


static func sidebar_candidate_indices(visible_count: int) -> Vector2i:
	if visible_count < 2:
		return Vector2i(-1, -1)
	var lower_index := visible_count - 2 if visible_count > 2 else 1
	var upper_index := maxi(0, lower_index - 4)
	return Vector2i(upper_index, lower_index)


static func fallback_chat_anchor_rects(chat_area_rect: Rect2) -> Array[Rect2]:
	var anchor_height := clampf(chat_area_rect.size.y * 0.07, 36.0, 72.0)
	var upper_center_y := chat_area_rect.position.y + chat_area_rect.size.y * 0.30
	var lower_center_y := chat_area_rect.position.y + chat_area_rect.size.y * 0.70
	var result: Array[Rect2] = []
	result.append(Rect2(Vector2(chat_area_rect.position.x, upper_center_y - anchor_height * 0.5), Vector2(chat_area_rect.size.x, anchor_height)))
	result.append(Rect2(Vector2(chat_area_rect.position.x, lower_center_y - anchor_height * 0.5), Vector2(chat_area_rect.size.x, anchor_height)))
	return result


static func normalized_rect(rect: Rect2, viewport_size: Vector2) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4.ZERO
	return Vector4(rect.position.x / viewport_size.x, rect.position.y / viewport_size.y, rect.size.x / viewport_size.x, rect.size.y / viewport_size.y)
