class_name CircuitBoard
extends VisualEffect

## Direct Godot port of the board face's construction model: reserve a grid for the
## central IC and components, route occupied-cell-aware 45-degree copper traces, then
## bind each trace end to its nearest component for signal-arrival propagation.

const GREEN := Color("3ddc84")
const GREEN_HOT := Color("a6ffd0")
const AMBER := Color("e7c368")
const AMBER_HOT := Color("ffe9ae")
const MAX_PULSES := 96
## Tune separately: dark app surfaces need more see-through board art than light ones.
const LIGHT_THEME_EFFECT_OPACITY := 0.90
const DARK_THEME_EFFECT_OPACITY := 0.65
const BOARD_OPACITY := 0.92
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]

var cell := 24.0
var cols := 0
var rows := 0
var occupied: Dictionary[String, bool] = {}
var traces: Array[Dictionary] = []
var components: Array[Dictionary] = []
var pulses: Array[Dictionary] = []
var chip: Dictionary = {}
var elapsed := 0.0
var activity := 0.22
var thinking := false
var failed := false
var built_size := Vector2.ZERO
var rng := RandomNumberGenerator.new()
## Transcript cursor boundary for the active run. The chip polls the latest live entry
## instead of consuming the shared sentence cursor used by other visual effects.
var active_session_id := 0
var run_entry_start := 0
var chip_text := ""
var chip_text_elapsed := 0.0


func _ready() -> void:
	super._ready()
	apply_theme_opacity()
	rng.seed = 7
	pass


func apply_theme_opacity() -> void:
	self_modulate.a = DARK_THEME_EFFECT_OPACITY if ThemeColor.is_dark_theme() else LIGHT_THEME_EFFECT_OPACITY
	pass


func on_agent_start(session_id: int) -> void:
	activity = 0.32
	thinking = false
	failed = false
	active_session_id = session_id
	var session := AgentSessionStore.load_session(session_id)
	run_entry_start = session.chat_entries.size() if session != null else 0
	chip_text = ""
	chip_text_elapsed = 0.5
	ensure_board()
	pulses.clear()
	for index in range(7):
		spawn_pulse(index, false, GREEN, float(index) * 0.06)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	failed = StringUtils.is_not_blank(error_message)
	activity = 0.58
	for index in range(14):
		spawn_pulse(index + 19, false, Colors.error if failed else GREEN_HOT, float(index) * 0.035)
	pass


func on_turn_start(_session_id: int) -> void:
	thinking = true
	activity = 1.0
	for index in range(10):
		spawn_pulse(index + 5, false, GREEN_HOT, float(index) * 0.04)
	pass


func on_turn_end(_session_id: int) -> void:
	thinking = false
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	activity = 1.0
	var count := clampi(ceili(float(chunk.length()) / 28.0), 1, 5)
	var color := GREEN_HOT if stream_kind == OpenAiClient.STREAM_KIND_REASONING else Color("7dffc0")
	for index in range(count):
		spawn_pulse(chunk.hash() + index * 31, false, color, float(index) * 0.045)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	activity = 1.0
	spawn_pulse(tool_call_id.hash(), false, AMBER_HOT, 0.0)
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	spawn_pulse(tool_call_id.hash() + 23, false, Colors.error if result.is_error else GREEN_HOT, 0.0)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	ensure_board()
	elapsed += delta
	chip_text_elapsed += delta
	if chip_text_elapsed >= 0.5:
		chip_text_elapsed = 0.0
		refresh_chip_text()
	activity = move_toward(activity, 0.2, delta * 0.38)
	var spawn_chance := (0.05 + activity * 0.85) * delta * 3.0
	if rng.randf() < spawn_chance:
		spawn_pulse(rng.randi(), false, GREEN if rng.randf() > 0.13 else AMBER, 0.0)
	advance_pulses(delta)
	for component: Dictionary in components:
		component["glow"] = move_toward(float(component["glow"]), 0.0, delta * 1.9)
	chip["glow"] = move_toward(float(chip.get("glow", 0.0)), 0.0, delta * 1.4)
	queue_redraw()
	pass


## Samples the latest streamed response at a fixed cadence so the central IC reads like
## a terminal display, without redrawing for every incoming token fragment.
func refresh_chip_text() -> void:
	if active_session_id == 0:
		return
	var latest := ChatEntryCursor.latest_entry_text(active_session_id, run_entry_start, ChatEntry.KIND_AGENT)
	if latest.is_empty():
		latest = ChatEntryCursor.latest_entry_text(active_session_id, run_entry_start, ChatEntry.KIND_THINKING)
	if latest.is_empty():
		return
	chip_text = display_text_for_chip(latest)
	pass


static func display_text_for_chip(text: String) -> String:
	var normalized := text.strip_edges().replace("\n", " ")
	return normalized.right(34) if normalized.length() > 34 else normalized


func ensure_board() -> void:
	var target_size := view_size()
	if target_size.is_equal_approx(built_size):
		return
	built_size = target_size
	build_board()
	pass


func view_size() -> Vector2:
	return size if size.x > 20.0 and size.y > 20.0 else Vector2(1280.0, 720.0)


func cell_key(x: int, y: int) -> String:
	return "%s_%s" % [x, y]


func is_occupied(x: int, y: int) -> bool:
	return occupied.has(cell_key(x, y))


func reserve(x: int, y: int) -> void:
	occupied[cell_key(x, y)] = true
	pass


## Port of board/index.html route(): a run turns only after a short straight segment,
## and collisions rotate it by 45 degrees. This is the source of the PCB-like paths.
func route(start_x: int, start_y: int, direction: int, max_length: int = -1) -> Dictionary:
	var x := start_x
	var y := start_y
	var current_direction := direction
	var grid_points: Array[Vector2i] = [Vector2i(x, y)]
	var run := rng.randi_range(2, 6)
	var blocked := 0
	var total := max_length if max_length > 0 else rng.randi_range(14, 43)
	for _step in range(total):
		var step := DIRS[current_direction]
		var next_x := x + step.x
		var next_y := y + step.y
		if next_x < 1 or next_y < 1 or next_x >= cols - 1 or next_y >= rows - 1 or is_occupied(next_x, next_y):
			current_direction = posmod(current_direction + (1 if rng.randf() < 0.5 else -1), DIRS.size())
			blocked += 1
			if blocked > 2:
				break
			continue
		blocked = 0
		x = next_x
		y = next_y
		reserve(x, y)
		grid_points.append(Vector2i(x, y))
		run -= 1
		if run <= 0:
			if rng.randf() < 0.7:
				current_direction = posmod(current_direction + (1 if rng.randf() < 0.5 else -1), DIRS.size())
			run = rng.randi_range(2, 7)
	if grid_points.size() < 5:
		return {}
	var kept: Array[Vector2i] = [grid_points[0]]
	for index in range(1, grid_points.size() - 1):
		var a: Vector2i = kept.back()
		var b := grid_points[index]
		var c := grid_points[index + 1]
		if (b.x - a.x) * (c.y - b.y) != (b.y - a.y) * (c.x - b.x):
			kept.append(b)
	kept.append(grid_points.back())
	var points := PackedVector2Array()
	var cumulative := PackedFloat32Array([0.0])
	for grid_point: Vector2i in kept:
		points.append(Vector2(float(grid_point.x) * cell + cell * 0.5, float(grid_point.y) * cell + cell * 0.5))
	for index in range(1, points.size()):
		cumulative.append(cumulative[index - 1] + points[index - 1].distance_to(points[index]))
	return {"points": points, "cumulative": cumulative, "length": cumulative[cumulative.size() - 1], "start": grid_points[0], "end": grid_points.back()}


func build_board() -> void:
	var view := view_size()
	cell = maxf(16.0, roundf(minf(view.x, view.y) / 56.0))
	cols = ceili(view.x / cell)
	rows = ceili(view.y / cell)
	occupied.clear()
	traces.clear()
	components.clear()
	pulses.clear()
	rng.seed = 7
	var chip_width := minf(view.x * 0.235, 620.0)
	var chip_height := roundf(chip_width * 0.30)
	chip = {"rect": Rect2(view * 0.5 - Vector2(chip_width, chip_height) * 0.5, Vector2(chip_width, chip_height)), "glow": 0.0, "pins": []}
	var rect: Rect2 = chip["rect"]
	var chip_x0 := floori(rect.position.x / cell) - 1
	var chip_y0 := floori(rect.position.y / cell) - 1
	var chip_x1 := ceili(rect.end.x / cell) + 1
	var chip_y1 := ceili(rect.end.y / cell) + 1
	for x in range(chip_x0, chip_x1 + 1):
		for y in range(chip_y0, chip_y1 + 1):
			reserve(x, y)
	for _index in range(34):
		var roll := rng.randf()
		var kind := "ic" if roll < 0.42 else "res" if roll < 0.78 else "cap"
		var width_cells := rng.randi_range(4, 6) if kind == "ic" else 1 if kind == "res" else 2
		var height_cells := rng.randi_range(3, 4) if kind == "ic" else rng.randi_range(3, 5) if kind == "res" else 2
		var spot := place_component(width_cells, height_cells)
		if spot.x < 0:
			continue
		components.append({"kind": kind, "gx": spot.x, "gy": spot.y, "wc": width_cells, "hc": height_cells,
			"rect": Rect2(Vector2(float(spot.x) * cell, float(spot.y) * cell), Vector2(float(width_cells) * cell, float(height_cells) * cell)),
			"amber": rng.randf() < 0.18, "glow": 0.0, "out": []})
	var pins_per_side := maxi(6, roundi(chip_height / cell) + 2)
	add_chip_traces(0, pins_per_side, chip_x0, chip_y0, chip_x1, chip_y1)
	add_chip_traces(1, pins_per_side, chip_x0, chip_y0, chip_x1, chip_y1)
	add_chip_traces(2, 6, chip_x0, chip_y0, chip_x1, chip_y1)
	add_chip_traces(3, 6, chip_x0, chip_y0, chip_x1, chip_y1)
	for _index in range(130):
		var x := rng.randi_range(1, cols - 2)
		var y := rng.randi_range(1, rows - 2)
		if is_occupied(x, y):
			continue
		reserve(x, y)
		var trace := route(x, y, [0, 2, 4, 6][rng.randi_range(0, 3)])
		if not trace.is_empty():
			trace["chip"] = false
			trace["amber"] = rng.randf() < 0.18
			traces.append(trace)
	bind_components()
	pass


func place_component(width_cells: int, height_cells: int) -> Vector2i:
	for _attempt in range(60):
		var x := rng.randi_range(1, cols - width_cells - 2)
		var y := rng.randi_range(1, rows - height_cells - 2)
		var free := true
		for candidate_x in range(x - 1, x + width_cells + 1):
			for candidate_y in range(y - 1, y + height_cells + 1):
				if is_occupied(candidate_x, candidate_y):
					free = false
					break
			if not free:
				break
		if not free:
			continue
		for candidate_x in range(x, x + width_cells):
			for candidate_y in range(y, y + height_cells):
				reserve(candidate_x, candidate_y)
		return Vector2i(x, y)
	return Vector2i(-1, -1)


func add_chip_traces(side: int, count: int, chip_x0: int, chip_y0: int, chip_x1: int, chip_y1: int) -> void:
	for _index in range(count):
		var x := chip_x0
		var y := chip_y0
		var direction := 0
		if side == 0:
			y = rng.randi_range(chip_y0 + 2, chip_y1 - 2)
			direction = 4
		elif side == 1:
			x = chip_x1
			y = rng.randi_range(chip_y0 + 2, chip_y1 - 2)
			direction = 0
		elif side == 2:
			x = rng.randi_range(chip_x0 + 2, chip_x1 - 2)
			direction = 6
		else:
			x = rng.randi_range(chip_x0 + 2, chip_x1 - 2)
			y = chip_y1
			direction = 2
		var trace := route(x, y, direction)
		if trace.is_empty():
			continue
		trace["chip"] = true
		trace["amber"] = rng.randf() < 0.15
		traces.append(trace)
		var pins: Array = chip["pins"]
		pins.append({"side": side, "x": x, "y": y})
	pass


func bind_components() -> void:
	for trace_index in range(traces.size()):
		var trace: Dictionary = traces[trace_index]
		var end: Vector2i = trace["end"]
		var best := -1
		var best_distance := 1000000
		for component_index in range(components.size()):
			var component: Dictionary = components[component_index]
			var dx := maxi(int(component["gx"]) - end.x, maxi(0, end.x - (int(component["gx"]) + int(component["wc"]) - 1)))
			var dy := maxi(int(component["gy"]) - end.y, maxi(0, end.y - (int(component["gy"]) + int(component["hc"]) - 1)))
			var distance := dx * dx + dy * dy
			if distance < best_distance:
				best_distance = distance
				best = component_index
		trace["end_component"] = best if best_distance <= 9 else -1
		var start: Vector2i = trace["start"]
		for component_index in range(components.size()):
			var component: Dictionary = components[component_index]
			var dx := maxi(int(component["gx"]) - start.x, maxi(0, start.x - (int(component["gx"]) + int(component["wc"]) - 1)))
			var dy := maxi(int(component["gy"]) - start.y, maxi(0, start.y - (int(component["gy"]) + int(component["hc"]) - 1)))
			if dx * dx + dy * dy <= 9:
				var outgoing: Array = component["out"]
				outgoing.append(trace_index)
	pass


func spawn_pulse(seed: int, inward: bool, color: Color, delay: float) -> void:
	if traces.is_empty() or pulses.size() >= MAX_PULSES:
		return
	var candidates: Array[int] = []
	for index in range(traces.size()):
		if bool(traces[index]["chip"]) == not inward:
			candidates.append(index)
	if candidates.is_empty():
		return
	var trace_index := candidates[posmod(seed, candidates.size())]
	pulses.append({"trace": trace_index, "distance": -delay * 290.0, "inward": inward, "color": color})
	pass


func advance_pulses(delta: float) -> void:
	var speed := lerpf(72.0, 720.0, activity)
	for index in range(pulses.size() - 1, -1, -1):
		var pulse: Dictionary = pulses[index]
		pulse["distance"] = float(pulse["distance"]) + delta * speed
		var trace: Dictionary = traces[int(pulse["trace"])]
		if float(pulse["distance"]) < float(trace["length"]) + cell * 7.0:
			continue
		if bool(pulse["inward"]):
			chip["glow"] = minf(1.0, float(chip["glow"]) + 0.5)
		else:
			var component_index := int(trace["end_component"])
			if component_index >= 0:
				var component: Dictionary = components[component_index]
				component["glow"] = 1.0
				for outgoing_index: int in component["out"]:
					if rng.randf() < 0.4:
						spawn_trace_pulse(outgoing_index, Color(pulse["color"]))
		pulses.remove_at(index)
	pass


func spawn_trace_pulse(trace_index: int, color: Color) -> void:
	if pulses.size() >= MAX_PULSES:
		return
	pulses.append({"trace": trace_index, "distance": 0.0, "inward": false, "color": color})
	pass


func _draw() -> void:
	ensure_board()
	var view := view_size()
	draw_background(view)
	for trace: Dictionary in traces:
		draw_trace(trace)
	for component: Dictionary in components:
		draw_component(component)
	draw_chip()
	for pulse: Dictionary in pulses:
		draw_pulse(pulse)
	draw_hud(view)
	pass


func draw_background(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color("020705", BOARD_OPACITY))
	var grid_step := maxi(5, roundi(cell * 0.3))
	for x in range(0, int(view.x), grid_step):
		draw_line(Vector2(x, 0.0), Vector2(x, view.y), Color("beffdc", 0.012), 1.0)
	for y in range(0, int(view.y), grid_step):
		draw_line(Vector2(0.0, y), Vector2(view.x, y), Color("beffdc", 0.012), 1.0)
	for x in range(roundi(cell * 2.0), int(view.x), roundi(cell * 4.0)):
		for y in range(roundi(cell * 2.0), int(view.y), roundi(cell * 4.0)):
			draw_rect(Rect2(Vector2(x - 1, y - 1), Vector2(2, 2)), Color(GREEN, 0.045))
	pass


func draw_trace(trace: Dictionary) -> void:
	var points: PackedVector2Array = trace["points"]
	var color := AMBER if bool(trace["amber"]) else GREEN
	draw_polyline(points, Color(Color.BLACK, 0.30), maxf(1.4, cell * 0.09) + 0.7, true)
	draw_polyline(points, Color(color, 0.17), maxf(1.4, cell * 0.09), true)
	for point: Vector2 in [points[0], points[points.size() - 1]]:
		var radius := maxf(2.6, cell * 0.14)
		draw_circle(point, radius, Color("010403", 0.95))
		draw_arc(point, radius, 0.0, TAU, 12, Color(color, 0.27), 1.1, true)
		draw_circle(point, maxf(1.1, cell * 0.06), Color("07150d", 0.95))
	pass


func draw_component(component: Dictionary) -> void:
	var rect: Rect2 = component["rect"]
	var color := AMBER if bool(component["amber"]) else GREEN
	var glow := float(component["glow"])
	if glow > 0.01:
		for layer in range(5, 0, -1):
			draw_rect(rect.grow(float(layer) * cell * 0.32), Color(color, glow * 0.008 * float(6 - layer)), true)
	var kind: String = component["kind"]
	if kind == "cap":
		var center := rect.get_center()
		var radius := rect.size.x * 0.34
		draw_circle(center, radius, Color("061008", 0.96))
		draw_arc(center, radius, 0.0, TAU, 18, Color(color, 0.28 + glow * 0.65), 1.3, true)
		draw_arc(center - Vector2(radius * 0.22, radius * 0.22), radius * 0.42, PI, PI * 1.55, 8, Color("b6ffd8", 0.18), 1.0, true)
		return
	if kind == "res":
		for row in range(int(component["hc"])):
			var resistor := Rect2(rect.position + Vector2(cell * 0.12, float(row) * cell + cell * 0.22), Vector2(rect.size.x - cell * 0.24, cell * 0.56))
			draw_rect(resistor, Color("040a06", 0.96))
			draw_rect(resistor, Color(color, 0.20 + glow * 0.58), false, 1.0)
		return
	var body := rect.grow(-cell * 0.3)
	var pins := maxi(3, int(component["wc"]) * 2 - 2)
	for pin in range(pins):
		var x := rect.position.x + cell * 0.5 + (rect.size.x - cell) * float(pin) / float(pins - 1)
		draw_line(Vector2(x, rect.position.y), Vector2(x, body.position.y), Color("b6e6ce", 0.23), 1.0)
		draw_line(Vector2(x, body.end.y), Vector2(x, rect.end.y), Color("b6e6ce", 0.23), 1.0)
	draw_rect(body, Color("050c08", 0.97))
	draw_rect(body, Color(color, 0.25 + glow * 0.65), false, 1.0)
	draw_circle(body.position + Vector2(cell * 0.32, cell * 0.32), maxf(1.0, cell * 0.09), Color("78dca8", 0.20))
	pass


func draw_chip() -> void:
	var rect: Rect2 = chip["rect"]
	var glow := float(chip["glow"])
	var beat := 0.5 + 0.5 * sin(elapsed * (4.5 if thinking else 1.8))
	var color := Colors.error if failed else GREEN_HOT
	for layer in range(11, 0, -1):
		draw_rect(rect.grow(float(layer) * 8.0), Color(color, (0.003 + glow * 0.007) * float(12 - layer) * (0.5 + beat * 0.5)), true)
	for pin in range(12):
		var x := rect.position.x + rect.size.x * (0.08 + 0.84 * float(pin) / 11.0)
		draw_line(Vector2(x, rect.position.y - cell * 0.34), Vector2(x, rect.position.y), Color("c8ebd7", 0.30), 2.0)
		draw_line(Vector2(x, rect.end.y), Vector2(x, rect.end.y + cell * 0.34), Color("c8ebd7", 0.30), 2.0)
	draw_rect(rect, Color("030a06", 0.96))
	draw_rect(rect, Color("1e3a2b", 0.90), false, 2.0)
	draw_rect(rect.grow(-5.0), Color(GREEN, 0.23 + glow * 0.55), false, 1.0)
	draw_circle(rect.position + Vector2(14.0, 14.0), 3.5, Color(GREEN, 0.45))
	var display_text := chip_text if not chip_text.is_empty() else "? Q $ 4 1 V Q 9 % Z ? #"
	draw_centered_text(rect.get_center() + Vector2(0.0, 7.0), display_text, Fonts.semibold(), Typography.title_medium_size, Color(color, 0.72 + beat * 0.23))
	pass


func draw_pulse(pulse: Dictionary) -> void:
	var trace: Dictionary = traces[int(pulse["trace"])]
	var distance := float(pulse["distance"])
	if distance < 0.0 or distance > float(trace["length"]):
		return
	var color: Color = pulse["color"]
	var tail_length := minf(view_size().x, view_size().y) * (0.10 + activity * 0.13)
	var start_distance := maxf(0.0, distance - tail_length)
	draw_trace_segment(trace, start_distance, distance, color)
	var position := trace_position(trace, distance)
	for radius in [16.0, 9.0, 4.0]:
		draw_circle(position, radius, Color(color, 0.035 * (17.0 / radius)))
	draw_circle(position, maxf(1.5, cell * 0.07), Color(color, 0.98))
	pass


func draw_trace_segment(trace: Dictionary, from_distance: float, to_distance: float, color: Color) -> void:
	var cumulative: PackedFloat32Array = trace["cumulative"]
	var points: PackedVector2Array = trace["points"]
	for index in range(1, cumulative.size()):
		var segment_start := maxf(cumulative[index - 1], from_distance)
		var segment_end := minf(cumulative[index], to_distance)
		if segment_end <= segment_start:
			continue
		var full_length := maxf(cumulative[index] - cumulative[index - 1], 0.001)
		var a := points[index - 1].lerp(points[index], (segment_start - cumulative[index - 1]) / full_length)
		var b := points[index - 1].lerp(points[index], (segment_end - cumulative[index - 1]) / full_length)
		var alpha := 0.44 + 0.42 * activity
		draw_line(a, b, Color(color, alpha), maxf(1.5, cell * 0.11), true)
	pass


func trace_position(trace: Dictionary, distance: float) -> Vector2:
	var cumulative: PackedFloat32Array = trace["cumulative"]
	var points: PackedVector2Array = trace["points"]
	for index in range(1, cumulative.size()):
		if distance <= cumulative[index]:
			var ratio := (distance - cumulative[index - 1]) / maxf(cumulative[index] - cumulative[index - 1], 0.001)
			return points[index - 1].lerp(points[index], ratio)
	return points[points.size() - 1]


func draw_hud(view: Vector2) -> void:
	draw_string(Fonts.regular(), Vector2(43.0, view.y - 30.0), "> run system diagnostics", HORIZONTAL_ALIGNMENT_LEFT, -1.0, Typography.label_small_size, Color("8fc4a8", 0.58))
	pass
