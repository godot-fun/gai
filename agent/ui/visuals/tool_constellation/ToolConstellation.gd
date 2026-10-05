class_name ToolConstellation
extends VisualEffect

## Event-driven map of the agent core, invoked tools, and their execution history.

const MAX_NODES := 12
const PACKET_COUNT := 4
const CORE_RADIUS := 62.0
const NODE_RADIUS := 31.0
const STAR_COUNT := 72
const CURVE_STEPS := 28

enum ExecutionState { RUNNING, SUCCESS, FAILED }

var nodes: Array[Dictionary] = []
var active_calls: Dictionary[String, int] = {}
var turn_index: int = 0
var elapsed: float = 0.0
var core_pulse: float = 0.0
var fade_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.TOOL_CONSTELLATION


func set_visual_visible(show: bool, animated: bool) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	if show:
		visible = true
		modulate.a = 0.0 if animated else 1.0
		if animated:
			fade_tween = create_tween()
			fade_tween.tween_property(self, "modulate:a", 1.0, 0.3)
		return
	if not animated:
		visible = false
		modulate.a = 1.0
		return
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	fade_tween.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
	)
	pass


func reset_visual() -> void:
	nodes.clear()
	active_calls.clear()
	turn_index = 0
	elapsed = 0.0
	core_pulse = 0.0
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	core_pulse = 1.0
	queue_redraw()
	pass


func on_agent_end(error_message: String) -> float:
	var final_state := ExecutionState.SUCCESS if StringUtils.is_blank(error_message) else ExecutionState.FAILED
	for node: Dictionary in nodes:
		if int(node["state"]) == ExecutionState.RUNNING:
			node["state"] = final_state
			node["settle"] = 0.0
	active_calls.clear()
	core_pulse = 1.0
	queue_redraw()
	return 0.8


func on_turn_start() -> void:
	turn_index += 1
	core_pulse = 1.0
	queue_redraw()
	pass


func on_turn_end() -> void:
	core_pulse = maxf(core_pulse, 0.45)
	pass


func on_chat_entry_add(_entry: ChatEntry) -> void:
	core_pulse = 1.0
	pass


func on_tool_execution_start(tool_call_id: String, tool_name: String, args: Dictionary[String, Variant]) -> void:
	if nodes.size() >= MAX_NODES:
		remove_oldest_settled_node()
	var node := make_node(tool_call_id, tool_name, args, nodes.size(), turn_index)
	nodes.append(node)
	active_calls[tool_call_id] = nodes.size() - 1
	core_pulse = 1.0
	queue_redraw()
	pass


func on_tool_execution_end(tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if not active_calls.has(tool_call_id):
		return
	var index: int = active_calls[tool_call_id]
	if index < 0 or index >= nodes.size():
		active_calls.erase(tool_call_id)
		return
	nodes[index]["state"] = ExecutionState.FAILED if result.is_error else ExecutionState.SUCCESS
	nodes[index]["settle"] = 0.0
	active_calls.erase(tool_call_id)
	core_pulse = 1.0
	queue_redraw()
	pass


func on_theme_changed() -> void:
	queue_redraw()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	core_pulse = move_toward(core_pulse, 0.0, delta * 1.8)
	for node: Dictionary in nodes:
		node["growth"] = move_toward(float(node["growth"]), 1.0, delta * 3.2)
		if int(node["state"]) != ExecutionState.RUNNING:
			node["settle"] = move_toward(float(node["settle"]), 1.0, delta * 1.6)
	queue_redraw()
	pass


func _draw() -> void:
	if size.x < 180.0 or size.y < 180.0:
		return
	var center := size * 0.5
	draw_star_field(center)
	draw_orbits(center)
	draw_execution_graph(center)
	for index in range(nodes.size()):
		draw_connection(nodes[index], center, node_position(index, nodes.size(), center))
	for index in range(nodes.size()):
		draw_tool_node(nodes[index], node_position(index, nodes.size(), center))
	draw_core(center)
	pass


func draw_orbits(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	var base_radius := minf(minf(size.x, size.y) * 0.24, 260.0)
	for orbit_index in range(3):
		var radius := base_radius + orbit_index * 92.0
		var rotation := elapsed * (0.035 + orbit_index * 0.018) * (-1.0 if orbit_index % 2 else 1.0)
		for arc_index in range(3):
			var start := rotation + float(arc_index) * TAU / 3.0 + orbit_index * 0.31
			draw_arc(center, radius, start, start + 0.72, 28, Color(accent, 0.11 - orbit_index * 0.018), 1.3, true)
			draw_circle(center + Vector2.from_angle(start + 0.72) * radius, 2.2, Color(accent, 0.34))
	pass


func draw_star_field(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	for index in range(STAR_COUNT):
		var position := Vector2(fmod(float(index * 197 + 83), maxf(size.x, 1.0)), fmod(float(index * 113 + 47), maxf(size.y, 1.0)))
		if position.distance_to(center) < CORE_RADIUS * 1.7:
			continue
		var twinkle := 0.5 + 0.5 * sin(elapsed * (0.7 + float(index % 5) * 0.13) + index)
		draw_circle(position, 0.7 + float(index % 4) * 0.35, Color(accent, 0.06 + twinkle * 0.16))
	pass


func draw_execution_graph(center: Vector2) -> void:
	for index in range(1, nodes.size()):
		var previous := node_position(index - 1, nodes.size(), center)
		var current := node_position(index, nodes.size(), center)
		var same_turn := int(nodes[index - 1]["turn"]) == int(nodes[index]["turn"])
		var color := ThemeColor.accent_theme_color() if same_turn else ColorBase.secondary_text
		for dash in range(9):
			if dash % 2 != index % 2:
				continue
			draw_line(previous.lerp(current, float(dash) / 9.0), previous.lerp(current, float(dash + 1) / 9.0), Color(color, 0.11 if same_turn else 0.07), 1.3, true)
	pass


func draw_core(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	var breath := (sin(elapsed * 2.4) + 1.0) * 0.5
	var pulse_radius := CORE_RADIUS + core_pulse * 34.0 + breath * 5.0
	for glow_index in range(4):
		draw_circle(center, pulse_radius + glow_index * 9.0, Color(accent, 0.035 - glow_index * 0.006))
	for ring_index in range(3):
		var radius := CORE_RADIUS + 12.0 + ring_index * 9.0
		var start := elapsed * (0.55 + ring_index * 0.18) * (-1.0 if ring_index % 2 else 1.0)
		draw_arc(center, radius, start, start + PI * (0.75 + ring_index * 0.12), 42, Color(accent, 0.66 - ring_index * 0.13), 2.5 - ring_index * 0.4, true)
	draw_circle(center, CORE_RADIUS, Color(ColorBase.deep_surface, 0.97))
	draw_circle(center, CORE_RADIUS - 8.0, Color(accent, 0.15 + breath * 0.07))
	draw_circle(center, 8.0 + breath * 2.0, Color(accent, 0.78))
	draw_centered_text(center + Vector2(0.0, 28.0), "AGENT CORE", Fonts.semibold(), Typography.label_medium_size, ColorBase.primary_text)
	draw_centered_text(center + Vector2(0.0, 45.0), "TURN %02d" % maxi(turn_index, 1), Fonts.regular(), Typography.label_small_size, Color(accent, 0.76))
	pass


func draw_connection(node: Dictionary, center: Vector2, position: Vector2) -> void:
	var growth: float = node["growth"]
	var state: int = node["state"]
	var accent := ThemeColor.accent_theme_color()
	var color := accent if state == ExecutionState.RUNNING else (ColorBase.success if state == ExecutionState.SUCCESS else ColorBase.error)
	var points := curved_path(center, position, int(node["sequence"]))
	var visible_points := partial_path(points, growth)
	if state == ExecutionState.FAILED:
		draw_broken_curve(visible_points, Color(color, 0.72))
	else:
		draw_polyline(visible_points, Color(color, 0.07), 11.0, true)
		draw_polyline(visible_points, Color(color, 0.18 if state == ExecutionState.SUCCESS else 0.52), 3.0, true)
	if state == ExecutionState.RUNNING and growth > 0.1:
		for packet_index in range(PACKET_COUNT):
			var progress := fmod(elapsed * 0.48 + float(packet_index) / float(PACKET_COUNT), 1.0)
			var packet_position := path_point(points, progress * growth)
			draw_circle(packet_position, 8.0, Color(accent, 0.07))
			draw_circle(packet_position, 3.8, Color(accent, 0.95))
	elif state == ExecutionState.SUCCESS:
		var return_progress := clampf(float(node["settle"]), 0.0, 1.0)
		var result_position := path_point(points, 1.0 - return_progress)
		draw_circle(result_position, 12.0 * (1.0 - return_progress * 0.4), Color(ColorBase.success, 0.08))
		draw_circle(result_position, 5.0, Color(ColorBase.success, 0.95))
	pass


func draw_tool_node(node: Dictionary, position: Vector2) -> void:
	var state: int = node["state"]
	var accent := ThemeColor.accent_theme_color()
	var state_color := accent if state == ExecutionState.RUNNING else (ColorBase.success if state == ExecutionState.SUCCESS else ColorBase.error)
	var node_radius := NODE_RADIUS * float(node["growth"])
	if state == ExecutionState.RUNNING:
		for scanner in range(2):
			var scan_start := elapsed * (1.7 + scanner * 0.35) + scanner * PI
			draw_arc(position, node_radius + 11.0 + scanner * 7.0, scan_start, scan_start + PI * 0.72, 24, Color(state_color, 0.82 - scanner * 0.25), 3.0 - scanner * 0.7, true)
	elif state == ExecutionState.FAILED:
		for ripple in range(3):
			var ripple_radius := node_radius + 9.0 + fmod(elapsed * 18.0 + ripple * 15.0, 42.0)
			draw_arc(position, ripple_radius, 0.25, PI * 1.72, 28, Color(state_color, 0.24 - ripple * 0.045), 2.4, true)
	draw_circle(position, node_radius + 13.0, Color(state_color, 0.13 if state == ExecutionState.RUNNING else 0.07))
	var hex := hexagon_points(position, node_radius)
	draw_colored_polygon(hex, Color(ColorBase.deep_surface, 0.97))
	var outline := PackedVector2Array(hex)
	outline.append(hex[0])
	draw_polyline(outline, Color(state_color, 0.84), 2.4, true)
	draw_centered_text(position + Vector2(0.0, 6.0), tool_glyph(String(node["name"])), Fonts.bold(), Typography.title_small_size, state_color)
	var label_position := position + Vector2(0.0, node_radius + Margin.ma_6)
	draw_centered_text(label_position, public_tool_name(String(node["name"])), Fonts.semibold(), Typography.label_medium_size, ColorBase.primary_text)
	var status_text := "RUNNING" if state == ExecutionState.RUNNING else ("COMPLETE" if state == ExecutionState.SUCCESS else "FAILED")
	draw_centered_text(label_position + Vector2(0.0, Margin.ma_4), status_text, Fonts.medium(), Typography.label_small_size, Color(state_color, 0.9))
	if state == ExecutionState.RUNNING and int(node["arg_count"]) > 0:
		var packet_label := "%d args" % int(node["arg_count"])
		draw_centered_text(label_position + Vector2(0.0, Margin.ma_8), packet_label, Fonts.regular(), Typography.label_small_size, ColorBase.secondary_text)
	pass


func draw_broken_curve(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 4:
		return
	var broken := PackedVector2Array(points)
	var midpoint_index := points.size() / 2
	for index in range(midpoint_index - 2, midpoint_index + 2):
		broken[index] += (points[index] - points[index - 1]).normalized().orthogonal() * (8.0 if index % 2 else -8.0)
	draw_polyline(broken, Color(color, 0.08), 12.0, true)
	draw_polyline(broken, color, 3.0, true)
	pass


func draw_centered_text(position: Vector2, text: String, font: Font, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, position - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	pass


func node_position(index: int, count: int, center: Vector2) -> Vector2:
	var angle := -PI * 0.5 + float(index) * 2.399963
	var max_radius := minf(minf(size.x * 0.36, size.y * 0.39), 430.0)
	var radius := minf(max_radius, 235.0 + (index % 3) * 92.0)
	var squash := clampf(size.y / maxf(size.x, 1.0) * 1.38, 0.68, 0.92)
	return center + Vector2(cos(angle) * radius, sin(angle) * radius * squash)


func curved_path(from: Vector2, to: Vector2, sequence: int) -> PackedVector2Array:
	var midpoint := from.lerp(to, 0.5)
	var bend := (to - from).normalized().orthogonal() * (34.0 + float(sequence % 3) * 15.0) * (-1.0 if sequence % 2 else 1.0)
	var control := midpoint + bend
	var points := PackedVector2Array()
	for step in range(CURVE_STEPS + 1):
		var amount := float(step) / CURVE_STEPS
		var inverse := 1.0 - amount
		points.append(from * inverse * inverse + control * 2.0 * inverse * amount + to * amount * amount)
	return points


static func partial_path(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var visible_count := clampi(int(ceil(amount * float(points.size() - 1))) + 1, 2, points.size())
	return points.slice(0, visible_count)


static func path_point(points: PackedVector2Array, amount: float) -> Vector2:
	var scaled := clampf(amount, 0.0, 1.0) * float(points.size() - 1)
	var index := mini(int(floor(scaled)), points.size() - 2)
	return points[index].lerp(points[index + 1], scaled - index)


static func hexagon_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		points.append(center + Vector2.from_angle(-PI * 0.5 + index * TAU / 6.0) * radius)
	return points


func remove_oldest_settled_node() -> void:
	var remove_index := 0
	for index in range(nodes.size()):
		if int(nodes[index]["state"]) != ExecutionState.RUNNING:
			remove_index = index
			break
	nodes.remove_at(remove_index)
	remap_active_calls()
	pass


func remap_active_calls() -> void:
	active_calls.clear()
	for index in range(nodes.size()):
		if int(nodes[index]["state"]) == ExecutionState.RUNNING:
			active_calls[String(nodes[index]["id"])] = index
	pass


static func make_node(tool_call_id: String, tool_name: String, args: Dictionary[String, Variant], sequence: int, turn: int) -> Dictionary:
	return {
		"id": tool_call_id,
		"name": tool_name,
		"arg_count": args.size(),
		"sequence": sequence,
		"turn": turn,
		"state": ExecutionState.RUNNING,
		"growth": 0.0,
		"settle": 0.0,
	}


static func public_tool_name(tool_name: String) -> String:
	var readable := tool_name.replace("_", " ").replace("-", " ").strip_edges()
	return readable.capitalize() if not readable.is_empty() else "Tool"


static func tool_glyph(tool_name: String) -> String:
	var normalized := tool_name.to_lower()
	if "read" in normalized:
		return "R"
	if "write" in normalized or "edit" in normalized:
		return "W"
	if "shell" in normalized or "bash" in normalized or "exec" in normalized:
		return ">_"
	if "search" in normalized or "grep" in normalized or "find" in normalized:
		return "?"
	if "web" in normalized or "fetch" in normalized:
		return "@"
	return public_tool_name(tool_name).left(2).to_upper()
