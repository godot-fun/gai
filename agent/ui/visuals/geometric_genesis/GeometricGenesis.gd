class_name GeometricGenesis
extends VisualEffect

## Builds one persistent compass-and-straightedge seal per agent turn. Seals use a
## golden-angle layout, so short runs remain sparse while long runs fill the viewport.

const MAX_SEALS := 64
const GOLDEN_ANGLE := 2.399963229728653
const DRAW_SPEED := 1.18
const SETTLE_SPEED := 2.4
const COMPLETION_SECONDS := 1.35
const COORDINATE_REVEAL_SECONDS := 2.8
const SIDE_SEQUENCE: Array[int] = [3, 4, 5, 4, 5, 6, 5, 6, 7, 6, 7, 8, 7, 8, 9, 8]

enum SealState { CONSTRUCTING, COMPLETE }
enum ToolState { RUNNING, SUCCESS, FAILED }
enum GeometryKind { STAR, ROSETTE, RADIAL, NESTED, WEAVE, ELLIPSE, PARABOLA, ROSE, LISSAJOUS, SPIRAL }

var seals: Array[Dictionary] = []
var active_seal: Dictionary = {}
var active_tools: Dictionary[String, Dictionary] = {}
var elapsed: float = 0.0
var reasoning_energy: float = 0.0
var completion: float = 0.0
var completing: bool = false
var ended_with_error: bool = false
var turn_serial: int = 0
var coordinate_reveal: float = 0.0
var formula_layout: Dictionary[int, Rect2] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.GEOMETRIC_GENESIS


func fade_in_seconds() -> float:
	return 0.35


func fade_out_seconds() -> float:
	return 0.5


func reset_visual() -> void:
	seals.clear()
	active_seal = {}
	active_tools.clear()
	elapsed = 0.0
	reasoning_energy = 0.0
	completion = 0.0
	completing = false
	ended_with_error = false
	turn_serial = 0
	coordinate_reveal = 0.0
	formula_layout.clear()
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	reasoning_energy = 0.35
	queue_redraw()
	pass


func on_agent_end(error_message: String) -> float:
	if not active_seal.is_empty():
		finish_active_seal()
	ended_with_error = StringUtils.is_not_blank(error_message)
	completing = true
	return COMPLETION_SECONDS


func on_turn_start() -> void:
	if not active_seal.is_empty():
		finish_active_seal()
	if seals.size() >= MAX_SEALS:
		active_seal = {}
		return
	turn_serial += 1
	active_seal = make_seal(turn_serial, seals.size())
	seals.append(active_seal)
	reasoning_energy = 1.0
	queue_redraw()
	pass


func on_turn_end() -> void:
	finish_active_seal()
	pass


func on_message_update(chunk: String, stream_kind: String) -> void:
	ensure_seal()
	if chunk.is_empty() or active_seal.is_empty():
		return
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		reasoning_energy = minf(1.0, reasoning_energy + float(chunk.length()) / 180.0)
		active_seal["phase"] = fmod(float(active_seal["phase"]) + float(chunk.length()) * 0.004, 1.0)
	else:
		active_seal["answer_energy"] = minf(1.0, float(active_seal["answer_energy"]) + 0.08)
	queue_redraw()
	pass


func on_tool_execution_start(tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	ensure_seal()
	if active_seal.is_empty():
		return
	var motif := {
		"id": tool_call_id,
		"name": tool_name,
		"state": ToolState.RUNNING,
		"growth": 0.0,
		"pulse": 1.0,
		"slot": (active_seal["motifs"] as Array).size(),
	}
	(active_seal["motifs"] as Array).append(motif)
	active_tools[tool_call_id] = motif
	reasoning_energy = 1.0
	queue_redraw()
	pass


func on_tool_execution_end(tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if not active_tools.has(tool_call_id):
		return
	var motif: Dictionary = active_tools[tool_call_id]
	motif["state"] = ToolState.FAILED if result.is_error else ToolState.SUCCESS
	motif["pulse"] = 1.0
	active_tools.erase(tool_call_id)
	queue_redraw()
	pass


func on_theme_changed() -> void:
	queue_redraw()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	coordinate_reveal = minf(1.0, coordinate_reveal + delta / COORDINATE_REVEAL_SECONDS)
	reasoning_energy = move_toward(reasoning_energy, 0.12, delta * 0.55)
	var changed := completing
	for seal: Dictionary in seals:
		var old_growth: float = seal["growth"]
		if coordinate_reveal >= 0.52:
			seal["growth"] = move_toward(old_growth, 1.0, delta * DRAW_SPEED)
		var old_settle: float = seal["settle"]
		var settle_target := 1.0 if int(seal["state"]) == SealState.COMPLETE else 0.0
		seal["settle"] = move_toward(old_settle, settle_target, delta * SETTLE_SPEED)
		changed = changed or old_growth != float(seal["growth"]) or old_settle != float(seal["settle"])
		for motif: Dictionary in seal["motifs"]:
			var old_motif_growth: float = motif["growth"]
			motif["growth"] = move_toward(old_motif_growth, 1.0, delta * 2.1)
			motif["pulse"] = move_toward(float(motif["pulse"]), 0.0, delta * 1.6)
			changed = changed or old_motif_growth != float(motif["growth"])
	if completing:
		completion = minf(1.0, completion + delta / COMPLETION_SECONDS)
	if changed or reasoning_energy > 0.13 or coordinate_reveal < 1.0:
		queue_redraw()
	pass


func _draw() -> void:
	if size.x < 160.0 or size.y < 160.0:
		return
	var center := size * 0.5
	draw_coordinate_plane(center)
	draw_origin(center)
	prepare_formula_layout(center)
	for index in range(seals.size()):
		var position := seal_position(index, center)
		draw_coordinate_projection(index, position, center)
		draw_seal(seals[index], position, seal_radius(index))
	if completing:
		draw_completion_wave(center)
	# Annotations are a dedicated top layer. Later geometry must never paint over an
	# earlier proof, and keeping layout separate avoids moving already placed formulas.
	for index in range(seals.size()):
		draw_construction_formula(seals[index], seal_position(index, center), seal_radius(index))
	pass


func prepare_formula_layout(origin: Vector2) -> void:
	var occupied: Array[Rect2] = []
	var geometry_zones: Array[Rect2] = []
	# Reserve the complete deterministic construction field. A formula placed now will
	# not be covered by a shape that appears many turns later.
	for index in range(MAX_SEALS):
		var position := seal_position(index, origin)
		var radius := seal_radius(index) * 1.28
		geometry_zones.append(Rect2(position - Vector2(radius, radius), Vector2(radius, radius) * 2.0))
	# Once assigned, an annotation is locked in place. Reflowing every historical label
	# when one new turn arrives reads as a full-screen hitch even at a stable frame rate.
	for key: int in formula_layout.keys():
		var stable_rect := clamp_formula_rect(formula_layout[key])
		formula_layout[key] = stable_rect
		occupied.append(stable_rect)
	for seal: Dictionary in seals:
		var index: int = seal["index"]
		if formula_layout.has(index):
			continue
		var position := seal_position(index, origin)
		var rect := find_formula_rect(position, seal_radius(index), occupied, geometry_zones)
		formula_layout[index] = rect
		occupied.append(rect)
	pass


func find_formula_rect(center: Vector2, radius: float, occupied: Array[Rect2], geometry_zones: Array[Rect2] = []) -> Rect2:
	const FORMULA_SIZE := Vector2(330.0, 43.0)
	const GAP := 52.0
	var candidates: Array[Vector2] = [
		center + Vector2(radius + GAP, -FORMULA_SIZE.y * 0.5),
		center + Vector2(-radius - GAP - FORMULA_SIZE.x, -FORMULA_SIZE.y * 0.5),
		center + Vector2(-FORMULA_SIZE.x * 0.5, -radius - GAP - FORMULA_SIZE.y),
		center + Vector2(-FORMULA_SIZE.x * 0.5, radius + GAP),
	]
	for candidate: Vector2 in candidates:
		var rect := clamp_formula_rect(Rect2(candidate, FORMULA_SIZE))
		if not formula_rect_overlaps(rect, occupied) and not formula_rect_overlaps(rect, geometry_zones):
			return rect
	# Search concentric rings around the owner. The angular offset prevents every label
	# from preferring the same four diagonals when the canvas becomes dense.
	for ring in range(1, 15):
		var distance := radius + 36.0 + float(ring) * 38.0
		for slot in range(16):
			var angle := float(slot) * TAU / 16.0 + float(ring % 2) * TAU / 32.0
			var anchor := center + Vector2.from_angle(angle) * distance
			var candidate := anchor - FORMULA_SIZE * 0.5
			var rect := clamp_formula_rect(Rect2(candidate, FORMULA_SIZE))
			if not formula_rect_overlaps(rect, occupied) and not formula_rect_overlaps(rect, geometry_zones):
				return rect
	# A completely saturated canvas still keeps the annotation on-screen. Overlap is
	# preferable to deleting mathematical history.
	return clamp_formula_rect(Rect2(candidates[0], FORMULA_SIZE))


func clamp_formula_rect(rect: Rect2) -> Rect2:
	const SCREEN_MARGIN := 12.0
	var maximum := Vector2(maxf(SCREEN_MARGIN, size.x - rect.size.x - SCREEN_MARGIN), maxf(SCREEN_MARGIN, size.y - rect.size.y - SCREEN_MARGIN))
	var position := Vector2(clampf(rect.position.x, SCREEN_MARGIN, maximum.x), clampf(rect.position.y, SCREEN_MARGIN, maximum.y))
	return Rect2(position, rect.size)


static func formula_rect_overlaps(rect: Rect2, occupied: Array[Rect2]) -> bool:
	for other: Rect2 in occupied:
		if rect.grow(4.0).intersects(other):
			return true
	return false


func draw_coordinate_plane(origin: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	var spacing := coordinate_spacing()
	var horizontal_steps := ceili(size.x / spacing * 0.5) + 1
	var vertical_steps := ceili(size.y / spacing * 0.5) + 1
	var reveal := smoothstep(0.0, 1.0, coordinate_reveal)
	for step in range(-horizontal_steps, horizontal_steps + 1):
		if step == 0:
			continue
		var distance_ratio := absf(float(step)) / float(horizontal_steps)
		var line_reveal := smoothstep(distance_ratio * 0.72, distance_ratio * 0.72 + 0.28, reveal)
		if line_reveal <= 0.0:
			continue
		var x := origin.x + float(step) * spacing
		var major := step % 4 == 0
		var tick_height := 8.0 if major else 4.0
		draw_line(Vector2(x, origin.y - tick_height * line_reveal), Vector2(x, origin.y + tick_height * line_reveal), Color(accent, (0.20 if major else 0.10) * line_reveal), 1.0)
	for step in range(-vertical_steps, vertical_steps + 1):
		if step == 0:
			continue
		var distance_ratio := absf(float(step)) / float(vertical_steps)
		var line_reveal := smoothstep(distance_ratio * 0.72, distance_ratio * 0.72 + 0.28, reveal)
		if line_reveal <= 0.0:
			continue
		var y := origin.y + float(step) * spacing
		var major := step % 4 == 0
		var tick_width := 8.0 if major else 4.0
		draw_line(Vector2(origin.x - tick_width * line_reveal, y), Vector2(origin.x + tick_width * line_reveal, y), Color(accent, (0.20 if major else 0.10) * line_reveal), 1.0)
	# Axes are the stable reference frame; arrowheads keep them legible without a UI panel.
	var left := origin.lerp(Vector2(18.0, origin.y), reveal)
	var right := origin.lerp(Vector2(size.x - 18.0, origin.y), reveal)
	var bottom := origin.lerp(Vector2(origin.x, size.y - 18.0), reveal)
	var top := origin.lerp(Vector2(origin.x, 18.0), reveal)
	draw_line(left, right, Color(accent, 0.22), 1.4, true)
	draw_line(bottom, top, Color(accent, 0.22), 1.4, true)
	var finish_reveal := smoothstep(0.78, 1.0, reveal)
	if finish_reveal > 0.0:
		draw_line(right, right + Vector2(-10.0, -5.0), Color(accent, 0.30 * finish_reveal), 1.4, true)
		draw_line(right, right + Vector2(-10.0, 5.0), Color(accent, 0.30 * finish_reveal), 1.4, true)
		draw_line(top, top + Vector2(-5.0, 10.0), Color(accent, 0.30 * finish_reveal), 1.4, true)
		draw_line(top, top + Vector2(5.0, 10.0), Color(accent, 0.30 * finish_reveal), 1.4, true)
		draw_string(Fonts.medium(), Vector2(size.x - 39.0, origin.y - 10.0), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.label_small_size, Color(accent, 0.48 * finish_reveal))
		draw_string(Fonts.medium(), Vector2(origin.x + 10.0, 34.0), "Y", HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.label_small_size, Color(accent, 0.48 * finish_reveal))
		draw_string(Fonts.regular(), origin + Vector2(7.0, 17.0), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.label_small_size, Color(accent, 0.34 * finish_reveal))
	pass


func draw_coordinate_projection(index: int, position: Vector2, origin: Vector2) -> void:
	if index == 0:
		return
	var accent := ThemeColor.accent_theme_color()
	var is_active := not active_seal.is_empty() and int(active_seal["index"]) == index
	var alpha := 0.16 if is_active else 0.045
	var x_projection := Vector2(position.x, origin.y)
	var y_projection := Vector2(origin.x, position.y)
	draw_projection_dashes(position, x_projection, Color(accent, alpha))
	draw_projection_dashes(position, y_projection, Color(accent, alpha))
	draw_circle(x_projection, 2.0, Color(accent, alpha * 1.8))
	draw_circle(y_projection, 2.0, Color(accent, alpha * 1.8))
	if is_active or index < 4:
		var unit := coordinate_spacing()
		var coordinate := "P%d  (%+.1f, %+.1f)" % [index + 1, (position.x - origin.x) / unit, (origin.y - position.y) / unit]
		draw_string(Fonts.regular(), position + Vector2(8.0, -8.0), coordinate, HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.label_small_size, Color(accent, 0.48 if is_active else 0.28))
	pass


func draw_projection_dashes(from: Vector2, to: Vector2, color: Color) -> void:
	var distance := from.distance_to(to)
	if distance <= 0.1:
		return
	var direction := (to - from) / distance
	var cursor := 0.0
	while cursor < distance:
		var segment_end := minf(cursor + 6.0, distance)
		draw_line(from + direction * cursor, from + direction * segment_end, color, 1.0, true)
		cursor += 12.0
	pass


func draw_origin(center: Vector2) -> void:
	if seals.is_empty():
		var breath := 0.5 + 0.5 * sin(elapsed * 2.2)
		var accent := ThemeColor.accent_theme_color()
		draw_circle(center, 2.0 + breath * 1.5, Color(accent, 0.65))
		draw_arc(center, 10.0 + breath * 5.0, 0.0, TAU, 32, Color(accent, 0.10), 1.0, true)
	pass


func draw_seal(seal: Dictionary, center: Vector2, radius: float) -> void:
	var growth: float = seal["growth"]
	var settle: float = seal["settle"]
	var sides: int = seal["sides"]
	var rotation: float = seal["rotation"]
	var accent := ThemeColor.accent_theme_color()
	var answer_energy: float = seal["answer_energy"]
	var guide_alpha := (1.0 - settle * 0.82) * (0.12 + reasoning_energy * 0.12)
	var guide_progress := clampf(growth * 1.35, 0.0, 1.0)
	draw_arc(center, radius * 1.14, rotation, rotation + TAU * guide_progress, 48, Color(accent, guide_alpha), 1.0, true)
	if growth < 0.12:
		draw_circle(center, 2.5 + growth * 16.0, Color(accent, 0.7))
		return
	var geometry_kind: int = seal["geometry_kind"]
	if geometry_kind >= GeometryKind.ELLIPSE:
		draw_analytic_geometry(seal, center, radius, smoothstep(0.12, 1.0, growth))
		for motif: Dictionary in seal["motifs"]:
			draw_tool_motif(motif, center, radius, sides, rotation)
		return
	var points := polygon_points(center, radius, sides, rotation)
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	var outline_growth := smoothstep(0.12, 0.82, growth)
	var visible_outline := partial_polyline(closed, outline_growth)
	if visible_outline.size() >= 2:
		draw_polyline(visible_outline, Color(accent, 0.028), 4.5, true)
		draw_polyline(visible_outline, Color(accent, 0.62 + settle * 0.16), 1.2, true)
	for vertex_index in range(points.size()):
		var reveal := clampf(outline_growth * float(sides) - float(vertex_index), 0.0, 1.0)
		if reveal > 0.0:
			draw_circle(points[vertex_index], 1.35 + reveal * 0.9, Color(accent, 0.58 * reveal))
	var complexity: int = seal["complexity"]
	if complexity > 0 and growth > 0.58:
		draw_inner_geometry(seal, center, radius, points, smoothstep(0.58, 1.0, growth))
	elif complexity == 0 and growth > 0.72:
		var center_growth := smoothstep(0.72, 1.0, growth)
		draw_circle(center, 2.2 + center_growth * 1.8, Color(accent, 0.46 * center_growth))
	if settle > 0.0:
		var fill := PackedColorArray([Color(accent, (0.012 + answer_energy * 0.018) * settle)])
		draw_polygon(points, fill)
	for motif: Dictionary in seal["motifs"]:
		draw_tool_motif(motif, center, radius, sides, rotation)
	pass


func draw_analytic_geometry(seal: Dictionary, center: Vector2, radius: float, growth: float) -> void:
	var kind: int = seal["geometry_kind"]
	var rotation: float = seal["rotation"]
	var variant: int = seal["index"]
	var points := analytic_curve_points(kind, center, radius, rotation, growth, variant)
	if points.size() < 2:
		return
	var accent := ThemeColor.accent_theme_color()
	draw_polyline(points, Color(accent, 0.028), 4.5, true)
	draw_polyline(points, Color(accent, 0.74), 1.2, true)
	var head := points[points.size() - 1]
	draw_circle(head, 2.2, Color(accent, 0.76))
	var settle: float = seal["settle"]
	var construction_alpha := 0.18 * (1.0 - settle * 0.72)
	match kind:
		GeometryKind.ELLIPSE:
			var axis := Vector2.from_angle(rotation)
			var focus_distance := radius * sqrt(1.0 - 0.62 * 0.62)
			draw_dashed_segment(center - axis * focus_distance, center + axis * focus_distance, Color(accent, construction_alpha))
			draw_circle(center - axis * focus_distance, 2.2, Color(accent, construction_alpha * 2.0))
			draw_circle(center + axis * focus_distance, 2.2, Color(accent, construction_alpha * 2.0))
		GeometryKind.PARABOLA:
			var local_focus := Vector2(0.0, -radius * 0.22).rotated(rotation)
			draw_circle(center + local_focus, 2.4, Color(accent, construction_alpha * 2.0))
			draw_dashed_segment(center + Vector2(-radius, radius * 0.42).rotated(rotation), center + Vector2(radius, radius * 0.42).rotated(rotation), Color(accent, construction_alpha))
		GeometryKind.ROSE, GeometryKind.LISSAJOUS, GeometryKind.SPIRAL:
			draw_line(center - Vector2(radius * 0.18, 0.0), center + Vector2(radius * 0.18, 0.0), Color(accent, construction_alpha), 1.0)
			draw_line(center - Vector2(0.0, radius * 0.18), center + Vector2(0.0, radius * 0.18), Color(accent, construction_alpha), 1.0)
	pass


func draw_dashed_segment(from: Vector2, to: Vector2, color: Color) -> void:
	var distance := from.distance_to(to)
	if distance <= 0.1:
		return
	var direction := (to - from) / distance
	for start in range(0, ceili(distance), 9):
		var segment_start := float(start)
		var segment_end := minf(segment_start + 4.5, distance)
		draw_line(from + direction * segment_start, from + direction * segment_end, color, 1.0, true)
	pass


static func analytic_curve_points(kind: int, center: Vector2, radius: float, rotation: float, growth: float, variant: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := maxi(2, ceili(96.0 * clampf(growth, 0.0, 1.0)))
	for step in range(steps):
		var amount := float(step) / 95.0
		var local := Vector2.ZERO
		match kind:
			GeometryKind.ELLIPSE:
				var angle := amount * TAU
				local = Vector2(cos(angle) * radius, sin(angle) * radius * 0.62)
			GeometryKind.PARABOLA:
				var u := lerpf(-1.0, 1.0, amount)
				local = Vector2(u * radius, (u * u - 0.46) * radius * 0.72)
			GeometryKind.ROSE:
				var angle := amount * TAU
				var petals := 3.0 + float(variant % 4)
				local = Vector2.from_angle(angle) * radius * cos(petals * angle)
			GeometryKind.LISSAJOUS:
				var time := amount * TAU
				var frequency_x := 2.0 + float(variant % 3)
				var frequency_y := 3.0 + float((variant + 1) % 4)
				local = Vector2(sin(frequency_x * time + PI * 0.5), sin(frequency_y * time)) * radius * 0.82
			GeometryKind.SPIRAL:
				var angle := amount * TAU * 3.4
				local = Vector2.from_angle(angle) * radius * amount
		points.append(center + local.rotated(rotation))
	return points


func draw_construction_formula(seal: Dictionary, center: Vector2, radius: float) -> void:
	var growth: float = seal["growth"]
	if growth <= 0.0:
		return
	var settle: float = seal["settle"]
	# Completed formulas remain as quiet proof annotations instead of disappearing.
	var fade := lerpf(1.0, 0.38, smoothstep(0.05, 0.72, settle))
	var index: int = seal["index"]
	var sides: int = seal["sides"]
	var point_formula := "theta_%d = %d * 137.508 deg    rho_%d = R sqrt(%d / %d)" % [index + 1, index, index + 1, index, MAX_SEALS - 1]
	var shape_formula := geometry_formula(int(seal["geometry_kind"]), sides)
	var point_reveal := clampf(growth / 0.42, 0.0, 1.0)
	var shape_reveal := clampf((growth - 0.34) / 0.58, 0.0, 1.0)
	var point_text := reveal_formula(point_formula, point_reveal)
	var shape_text := reveal_formula(shape_formula, shape_reveal)
	var formula_width := 330.0
	var rect: Rect2 = formula_layout.get(index, Rect2(center + Vector2(radius + 12.0, -21.5), Vector2(formula_width, 43.0)))
	var x := rect.position.x + 7.0
	var y := rect.position.y + 17.0
	var accent := ThemeColor.accent_theme_color()
	var label_anchor := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	var to_label := label_anchor - center
	if to_label.length() > radius + 8.0:
		var leader_start := center + to_label.normalized() * radius
		draw_line(leader_start, label_anchor, Color(accent, 0.14 * fade), 0.7, true)
		draw_circle(label_anchor, 1.5, Color(accent, 0.30 * fade))
	draw_line(Vector2(x - 7.0, y - 17.0), Vector2(x - 7.0, y + 26.0), Color(accent, 0.42 * fade), 1.0)
	draw_string(Fonts.regular(), Vector2(x, y), point_text, HORIZONTAL_ALIGNMENT_LEFT, formula_width, Typography.label_small_size, Color(accent, 0.58 * fade))
	if not shape_text.is_empty():
		draw_string(Fonts.medium(), Vector2(x, y + 18.0), shape_text, HORIZONTAL_ALIGNMENT_LEFT, formula_width, Typography.label_small_size, Color(accent, 0.82 * fade))
	pass


static func reveal_formula(formula: String, amount: float) -> String:
	var count := clampi(int(ceil(float(formula.length()) * amount)), 0, formula.length())
	if count == 0:
		return ""
	return formula.substr(0, count) + ("_" if count < formula.length() else "")


static func geometry_formula(kind: int, sides: int) -> String:
	match kind:
		GeometryKind.STAR:
			var step := 2 if sides % 2 == 1 else maxi(2, sides / 2 - 1)
			return "{%d/%d}:  k -> (k + %d) mod %d" % [sides, step, step, sides]
		GeometryKind.ROSETTE:
			return "(x - a_k)^2 + (y - b_k)^2 = (r / 2)^2"
		GeometryKind.RADIAL:
			return "L_k(t) = (1 - t) P_n + t v_k"
		GeometryKind.NESTED:
			return "v_(k,j) = P_n + lambda_j (v_k - P_n)"
		GeometryKind.WEAVE:
			return "C_k = segment(v_k, v_((k+s) mod %d))" % sides
		GeometryKind.ELLIPSE:
			return "x^2 / a^2 + y^2 / b^2 = 1"
		GeometryKind.PARABOLA:
			return "y = a x^2    |PF| = dist(P, directrix)"
		GeometryKind.ROSE:
			return "r(theta) = a cos(k theta)"
		GeometryKind.LISSAJOUS:
			return "x = A sin(a t + delta),  y = B sin(b t)"
		GeometryKind.SPIRAL:
			return "r(theta) = a + b theta"
	return "v_k = P_n + r (cos(2 PI k / m), sin(2 PI k / m))"


func draw_inner_geometry(seal: Dictionary, center: Vector2, radius: float, points: PackedVector2Array, growth: float) -> void:
	match int(seal["geometry_kind"]):
		GeometryKind.STAR:
			draw_star_geometry(seal, center, radius, points, growth)
		GeometryKind.ROSETTE:
			draw_rosette_geometry(center, radius, points, growth)
		GeometryKind.RADIAL:
			draw_radial_geometry(center, radius, points, growth)
		GeometryKind.NESTED:
			draw_nested_geometry(seal, center, radius, growth)
		GeometryKind.WEAVE:
			draw_weave_geometry(center, points, growth)
	var complexity: int = seal["complexity"]
	var accent := ThemeColor.accent_theme_color()
	if complexity >= 3:
		var secondary_growth := smoothstep(0.28, 1.0, growth)
		draw_arc(center, radius * 0.34, float(seal["rotation"]), float(seal["rotation"]) + TAU * secondary_growth, 32, Color(accent, 0.24), 1.0, true)
	if complexity >= 4:
		# Mature seals combine two construction grammars instead of merely adding more sides.
		draw_radial_geometry(center, radius * 0.72, points, smoothstep(0.42, 1.0, growth))
		var core := polygon_points(center, radius * 0.26, maxi(3, int(seal["sides"]) - 2), -float(seal["rotation"]) * 0.5)
		core.append(core[0])
		var visible_core := partial_polyline(core, smoothstep(0.55, 1.0, growth))
		if visible_core.size() >= 2:
			draw_polyline(visible_core, Color(accent, 0.42), 1.1, true)
	pass


func draw_star_geometry(seal: Dictionary, center: Vector2, radius: float, points: PackedVector2Array, growth: float) -> void:
	var accent := ThemeColor.accent_theme_color()
	var sides: int = seal["sides"]
	var step := 2 if sides % 2 == 1 else maxi(2, sides / 2 - 1)
	var star := PackedVector2Array()
	var cursor := 0
	var visited: Dictionary[int, bool] = {}
	while not visited.has(cursor):
		visited[cursor] = true
		star.append(points[cursor])
		cursor = (cursor + step) % sides
	star.append(star[0])
	var visible_star := partial_polyline(star, growth)
	if visible_star.size() >= 2:
		draw_polyline(visible_star, Color(accent, 0.035), 6.0, true)
		draw_polyline(visible_star, Color(accent, 0.32), 1.0, true)
	var inner_radius := radius * (0.24 + 0.07 * sin(float(seal["phase"]) * TAU))
	draw_arc(center, inner_radius, 0.0, TAU * growth, 32, Color(accent, 0.34), 1.2, true)
	pass


func draw_rosette_geometry(center: Vector2, radius: float, points: PackedVector2Array, growth: float) -> void:
	var accent := ThemeColor.accent_theme_color()
	var petal_radius := radius * 0.48
	for index in range(points.size()):
		var reveal := clampf(growth * float(points.size()) - float(index), 0.0, 1.0)
		if reveal <= 0.0:
			continue
		var petal_center := center.lerp(points[index], 0.48)
		draw_arc(petal_center, petal_radius, 0.0, TAU * reveal, 28, Color(accent, 0.24 + reveal * 0.12), 1.0, true)
	draw_arc(center, radius * 0.21, 0.0, TAU * growth, 28, Color(accent, 0.48), 1.4, true)
	pass


func draw_radial_geometry(center: Vector2, radius: float, points: PackedVector2Array, growth: float) -> void:
	var accent := ThemeColor.accent_theme_color()
	for index in range(points.size()):
		var reveal := clampf(growth * float(points.size()) - float(index), 0.0, 1.0)
		if reveal <= 0.0:
			continue
		var inner := center + (points[index] - center) * 0.24
		draw_line(inner, inner.lerp(points[index], reveal), Color(accent, 0.30), 1.1, true)
		var next := points[(index + 2) % points.size()]
		draw_line(inner, inner.lerp(next, reveal * 0.62), Color(accent, 0.16), 1.0, true)
	draw_circle(center, radius * 0.085 * growth, Color(accent, 0.54))
	pass


func draw_nested_geometry(seal: Dictionary, center: Vector2, radius: float, growth: float) -> void:
	var accent := ThemeColor.accent_theme_color()
	var sides: int = seal["sides"]
	var rotation: float = seal["rotation"]
	for layer in range(3):
		var reveal := clampf(growth * 3.0 - float(layer), 0.0, 1.0)
		if reveal <= 0.0:
			continue
		var layer_radius := radius * (0.72 - float(layer) * 0.19)
		var layer_points := polygon_points(center, layer_radius, sides, rotation + float(layer) * PI / float(sides))
		layer_points.append(layer_points[0])
		var visible := partial_polyline(layer_points, reveal)
		if visible.size() >= 2:
			draw_polyline(visible, Color(accent, 0.19 + float(layer) * 0.07), 1.0, true)
	pass


func draw_weave_geometry(center: Vector2, points: PackedVector2Array, growth: float) -> void:
	var accent := ThemeColor.accent_theme_color()
	var chord_count := points.size() * 2
	for chord in range(chord_count):
		var reveal := clampf(growth * float(chord_count) - float(chord), 0.0, 1.0)
		if reveal <= 0.0:
			continue
		var from := points[chord % points.size()]
		var offset := 2 + chord % maxi(2, points.size() - 3)
		var to := points[(chord + offset) % points.size()]
		var midpoint := from.lerp(to, 0.5).lerp(center, 0.18 if chord % 2 == 0 else -0.12)
		draw_line(from, from.lerp(midpoint, minf(reveal * 2.0, 1.0)), Color(accent, 0.20), 1.0, true)
		if reveal > 0.5:
			draw_line(midpoint, midpoint.lerp(to, (reveal - 0.5) * 2.0), Color(accent, 0.30), 1.0, true)
	pass


func draw_tool_motif(motif: Dictionary, center: Vector2, radius: float, sides: int, rotation: float) -> void:
	var slot: int = motif["slot"]
	var angle := rotation + float(slot) * GOLDEN_ANGLE
	var edge := center + Vector2.from_angle(angle) * radius * 0.78
	var growth: float = motif["growth"]
	var state: int = motif["state"]
	var color := ThemeColor.accent_theme_color() if state == ToolState.RUNNING else (ColorBase.success if state == ToolState.SUCCESS else ColorBase.error)
	var from := center.lerp(edge, growth)
	if state == ToolState.FAILED:
		var normal := (edge - center).normalized().orthogonal() * radius * 0.08
		draw_line(center, center.lerp(edge, growth * 0.46), Color(color, 0.50), 1.3, true)
		draw_line(center.lerp(edge, growth * 0.58) + normal, from, Color(color, 0.62), 1.3, true)
		if growth > 0.8:
			draw_line(edge - Vector2(3.5, 3.5), edge + Vector2(3.5, 3.5), color, 1.4, true)
			draw_line(edge + Vector2(-3.5, 3.5), edge + Vector2(3.5, -3.5), color, 1.4, true)
		return
	draw_line(center, from, Color(color, 0.30 if state == ToolState.SUCCESS else 0.52), 1.2, true)
	if growth > 0.82:
		var pulse: float = motif["pulse"]
		draw_circle(edge, 2.6 + pulse * 5.0, Color(color, 0.72 - pulse * 0.25))
		if state == ToolState.SUCCESS:
			var next_angle := rotation + float((slot + 2) % sides) * TAU / float(sides)
			var chord_end := center + Vector2.from_angle(next_angle) * radius * 0.72
			draw_line(edge, edge.lerp(chord_end, growth), Color(color, 0.24), 1.0, true)
	pass


func draw_completion_wave(center: Vector2) -> void:
	var color := ColorBase.error if ended_with_error else ColorBase.success
	var max_radius := center.length()
	var radius := max_radius * completion
	var alpha := sin(completion * PI) * 0.48
	draw_arc(center, radius, 0.0, TAU, 96, Color(color, alpha), 2.2, true)
	draw_arc(center, radius * 0.93, 0.0, TAU, 96, Color(color, alpha * 0.18), 12.0, true)
	for index in range(seals.size()):
		var position := seal_position(index, center)
		var hit := clampf(1.0 - absf(position.distance_to(center) - radius) / 54.0, 0.0, 1.0)
		if hit > 0.0:
			draw_circle(position, 4.0 + hit * 5.0, Color(color, hit * 0.44))
	pass


func finish_active_seal() -> void:
	if active_seal.is_empty():
		return
	active_seal["state"] = SealState.COMPLETE
	for motif: Dictionary in active_seal["motifs"]:
		if int(motif["state"]) == ToolState.RUNNING:
			motif["state"] = ToolState.SUCCESS
	active_seal = {}
	active_tools.clear()
	queue_redraw()
	pass


func ensure_seal() -> void:
	if active_seal.is_empty() and seals.size() < MAX_SEALS:
		on_turn_start()
	pass


func seal_position(index: int, center: Vector2) -> Vector2:
	if index == 0:
		return center
	var min_dimension := minf(size.x, size.y)
	var normalized := sqrt(float(index) / float(MAX_SEALS - 1))
	var radius := normalized * min_dimension * 0.47
	var angle := -PI * 0.5 + float(index) * GOLDEN_ANGLE
	var squash := clampf(size.y / maxf(size.x, 1.0) * 1.18, 0.68, 1.0)
	return center + Vector2(cos(angle) * radius / squash, sin(angle) * radius * squash)


func seal_radius(index: int) -> float:
	var min_dimension := minf(size.x, size.y)
	var base := clampf(min_dimension * 0.052, 25.0, 62.0)
	return base * (1.12 if index == 0 else 1.0 - minf(float(index), 48.0) * 0.0025)


func coordinate_spacing() -> float:
	return clampf(minf(size.x, size.y) * 0.072, 44.0, 76.0)


static func make_seal(turn: int, index: int) -> Dictionary:
	var sequence_index := index % SIDE_SEQUENCE.size()
	var complexity := complexity_for_index(index)
	var geometry_kind := geometry_kind_for(index, complexity)
	return {
		"turn": turn,
		"index": index,
		"sides": SIDE_SEQUENCE[sequence_index],
		"complexity": complexity,
		"geometry_kind": geometry_kind,
		"rotation": -PI * 0.5 + fmod(float(turn) * GOLDEN_ANGLE, TAU),
		"growth": 0.0,
		"settle": 0.0,
		"phase": fmod(float(turn) * 0.61803398875, 1.0),
		"answer_energy": 0.0,
		"state": SealState.CONSTRUCTING,
		"motifs": [],
	}


static func complexity_for_index(index: int) -> int:
	if index < 3:
		return 0
	if index < 8:
		return 1
	if index < 16:
		return 2
	if index < 32:
		return 3
	return 4


static func geometry_kind_for(index: int, complexity: int) -> int:
	match complexity:
		0:
			return GeometryKind.RADIAL
		1:
			return GeometryKind.RADIAL if index % 2 == 0 else GeometryKind.NESTED
		2:
			const DEVELOPING_KINDS: Array[int] = [GeometryKind.ELLIPSE, GeometryKind.STAR, GeometryKind.PARABOLA, GeometryKind.NESTED]
			return DEVELOPING_KINDS[index % DEVELOPING_KINDS.size()]
		3:
			const PARAMETRIC_KINDS: Array[int] = [GeometryKind.ROSE, GeometryKind.LISSAJOUS, GeometryKind.SPIRAL, GeometryKind.WEAVE, GeometryKind.ROSETTE]
			return PARAMETRIC_KINDS[index % PARAMETRIC_KINDS.size()]
	const MATURE_KINDS: Array[int] = [GeometryKind.ELLIPSE, GeometryKind.PARABOLA, GeometryKind.ROSE, GeometryKind.LISSAJOUS, GeometryKind.SPIRAL]
	return MATURE_KINDS[index % MATURE_KINDS.size()]


static func polygon_points(center: Vector2, radius: float, sides: int, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(sides):
		points.append(center + Vector2.from_angle(rotation + float(index) * TAU / float(sides)) * radius)
	return points


static func partial_polyline(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	if points.size() < 2 or amount <= 0.0:
		return PackedVector2Array()
	var scaled := clampf(amount, 0.0, 1.0) * float(points.size() - 1)
	var complete_segments := mini(int(floor(scaled)), points.size() - 1)
	var result := PackedVector2Array()
	for index in range(complete_segments + 1):
		result.append(points[index])
	if complete_segments < points.size() - 1:
		result.append(points[complete_segments].lerp(points[complete_segments + 1], scaled - float(complete_segments)))
	return result
