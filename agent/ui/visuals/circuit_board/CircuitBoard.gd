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
const LIGHT_THEME_EFFECT_OPACITY := 0.82
const DARK_THEME_EFFECT_OPACITY := 0.65
const BOARD_OPACITY := 0.24
const REFERENCE_AREA := 1920.0 * 1080.0
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
var chip_text := ""
var chip_status := "STANDBY"
var redraw_elapsed := 0.0
var completion_wave := -1.0
var streamed_chars := 0
var turn_count := 0
var boot_progress := 1.0
var focus_position := Vector2.ZERO
var focus_strength := 0.0
var completion_delay := -1.0
var response_burst := -1.0
var response_burst_released := false


func _ready() -> void:
	super._ready()
	apply_theme_opacity()
	gdf.events.theme_changed.connect(apply_theme_opacity)
	rng.seed = 7
	pass


func apply_theme_opacity() -> void:
	self_modulate.a = DARK_THEME_EFFECT_OPACITY if ThemeColor.is_dark_theme() else LIGHT_THEME_EFFECT_OPACITY
	queue_redraw()
	pass


func board_green() -> Color:
	return GREEN if ThemeColor.is_dark_theme() else Color("176b45")


func board_hot_green() -> Color:
	return GREEN_HOT if ThemeColor.is_dark_theme() else Color("008f52")


func board_amber() -> Color:
	return AMBER if ThemeColor.is_dark_theme() else Color("9a6500")


func board_hot_amber() -> Color:
	return AMBER_HOT if ThemeColor.is_dark_theme() else Color("b26d00")


func board_surface(alpha: float = 1.0) -> Color:
	return Color("030a06", alpha) if ThemeColor.is_dark_theme() else Color("edf4ef", alpha)


func board_ink(alpha: float = 1.0) -> Color:
	return Color("c8ebd7", alpha) if ThemeColor.is_dark_theme() else Color("174d35", alpha)


func on_agent_start(_session_id: int) -> void:
	activity = 0.32
	thinking = false
	failed = false
	chip_text = ""
	chip_status = "BOOTING"
	completion_wave = -1.0
	completion_delay = -1.0
	response_burst = -1.0
	response_burst_released = false
	streamed_chars = 0
	turn_count = 0
	boot_progress = 0.0
	ensure_board()
	pulses.clear()
	for index in range(7):
		spawn_pulse(index, false, board_green(), float(index) * 0.06, true)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	failed = StringUtils.is_not_blank(error_message)
	chip_status = "ERROR" if failed else "COMPLETE"
	completion_wave = -1.0
	completion_delay = 0.46
	activity = 0.58
	for index in range(14):
		spawn_pulse(index + 19, true, Colors.error if failed else board_hot_green(), float(index) * 0.025, true)
	pass


func on_turn_start(_session_id: int) -> void:
	thinking = true
	activity = 1.0
	chip_status = "REASONING"
	turn_count += 1
	for index in range(10):
		spawn_pulse(index + 5, false, board_hot_green(), float(index) * 0.04, true)
	pass


func on_turn_end(_session_id: int) -> void:
	thinking = false
	chip_status = "RESPONDING"
	response_burst = 0.0
	response_burst_released = false
	for index in range(9):
		spawn_pulse(index + 71, true, board_hot_green(), float(index) * 0.025, true)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	activity = 1.0
	streamed_chars += chunk.length()
	chip_status = "REASONING" if stream_kind == OpenAiClient.STREAM_KIND_REASONING else "RESPONDING"
	var count := clampi(ceili(float(chunk.length()) / 28.0), 1, 5)
	var color := board_hot_green() if stream_kind == OpenAiClient.STREAM_KIND_REASONING else board_green()
	for index in range(count):
		spawn_pulse(chunk.hash() + index * 31, false, color, float(index) * 0.045, true)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	activity = 1.0
	chip_status = display_tool_status(tool_name)
	var flow_mode := tool_flow_mode(tool_name)
	spawn_pulse(tool_call_id.hash(), flow_mode == "inward", board_hot_amber(), 0.0, true)
	if flow_mode == "bidirectional":
		spawn_pulse(tool_call_id.hash() + 17, true, board_hot_amber(), 0.08, true)
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	chip_status = "TOOL FAILED" if result.is_error else "TOOL COMPLETE"
	spawn_pulse(tool_call_id.hash() + 23, true, Colors.error if result.is_error else board_hot_green(), 0.0, true)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	ensure_board()
	elapsed += delta
	boot_progress = minf(1.0, boot_progress + delta / 0.85)
	var sentence := ChatEntryCursor.take_next_sentence()
	if not sentence.is_empty() and is_informative_chip_text(sentence.text):
		chip_text = display_text_for_chip(sentence.text)
	activity = move_toward(activity, 0.2, delta * 0.38)
	var spawn_chance := (0.05 + activity * 0.85) * delta * 3.0 * phase_spawn_multiplier()
	if rng.randf() < spawn_chance:
		spawn_pulse(rng.randi(), false, board_green() if rng.randf() > 0.13 else board_amber(), 0.0)
	advance_pulses(delta)
	update_focus(delta)
	advance_response_burst(delta)
	for component: Dictionary in components:
		component["glow"] = move_toward(float(component["glow"]), 0.0, delta * 1.9)
	for trace: Dictionary in traces:
		trace["heat"] = move_toward(float(trace.get("heat", 0.0)), 0.0, delta * 0.28)
	chip["glow"] = move_toward(float(chip.get("glow", 0.0)), 0.0, delta * 1.4)
	if completion_wave >= 0.0:
		completion_wave += delta
		if completion_wave > 1.35:
			completion_wave = -1.0
	if completion_delay >= 0.0:
		completion_delay -= delta
		if completion_delay <= 0.0:
			completion_delay = -1.0
			completion_wave = 0.0
	redraw_elapsed += delta
	var redraw_interval := 1.0 / (60.0 if activity > 0.3 or not pulses.is_empty() else 30.0)
	if redraw_elapsed >= redraw_interval:
		redraw_elapsed = 0.0
		queue_redraw()
	pass


func advance_response_burst(delta: float) -> void:
	if response_burst < 0.0:
		return
	response_burst += delta
	if response_burst >= 0.36 and not response_burst_released:
		response_burst_released = true
		chip["glow"] = 1.0
		for index in range(12):
			spawn_pulse(index + 131, false, board_hot_green(), float(index) * 0.018, true)
	if response_burst > 0.86:
		response_burst = -1.0
	pass


func phase_speed_multiplier() -> float:
	if chip_status.begins_with("EXEC") or chip_status.begins_with("TOOL"):
		return 0.46
	if thinking:
		return 1.12
	if chip_status == "RESPONDING":
		return 0.82
	if chip_status == "COMPLETE" or chip_status == "ERROR":
		return 0.55
	return 0.72


func phase_spawn_multiplier() -> float:
	if chip_status.begins_with("EXEC"):
		return 1.45
	if thinking:
		return 1.20
	if chip_status == "RESPONDING":
		return 0.78
	if chip_status == "COMPLETE" or chip_status == "ERROR":
		return 0.0
	return 0.52


func update_focus(delta: float) -> void:
	var target_strength := 0.0
	for pulse: Dictionary in pulses:
		var distance := float(pulse["distance"])
		var trace: Dictionary = traces[int(pulse["trace"])]
		if distance < 0.0 or distance > float(trace["length"]):
			continue
		var trace_distance := float(trace["length"]) - distance if bool(pulse["inward"]) else distance
		focus_position = trace_position(trace, trace_distance)
		target_strength = 1.0
		break
	focus_strength = move_toward(focus_strength, target_strength, delta * 3.5)
	pass


static func display_text_for_chip(text: String) -> String:
	var normalized := text.strip_edges().replace("\n", " ")
	return normalized.right(34) if normalized.length() > 34 else normalized


static func is_informative_chip_text(text: String) -> bool:
	var meaningful := text.strip_edges()
	for symbol in [" ", "\t", "\n", ".", ",", ":", ";", "!", "?", "*", "#", "$", "%", "/", "\\", "-", "_", "=", "+", "`", "~", "'", "\""]:
		meaningful = meaningful.replace(symbol, "")
	return meaningful.length() >= 5


static func display_tool_status(tool_name: String) -> String:
	var normalized := tool_name.replace("_", " ").strip_edges().to_upper()
	return "EXEC · %s" % (normalized.left(20) if normalized.length() > 20 else normalized)


static func tool_flow_mode(tool_name: String) -> String:
	var normalized := tool_name.to_lower()
	for token in ["read", "get", "list", "find", "search", "open", "fetch", "load"]:
		if normalized.contains(token):
			return "inward"
	for token in ["request", "http", "network", "sync", "upload", "download"]:
		if normalized.contains(token):
			return "bidirectional"
	return "outward"


func chip_detail_text() -> String:
	if chip_status.begins_with("EXEC") or chip_status.begins_with("TOOL"):
		return "TURN %02d · BUS ACTIVE" % turn_count
	if chip_status == "COMPLETE" or chip_status == "ERROR":
		return "TURN %02d · STREAM %04d" % [turn_count, streamed_chars]
	if thinking or chip_status == "RESPONDING":
		return "TURN %02d · STREAM %04d" % [turn_count, streamed_chars]
	return "SYSTEM BUS · READY"


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
	var chip_height := roundf(chip_width * 0.345)
	chip = {"rect": Rect2(view * 0.5 - Vector2(chip_width, chip_height) * 0.5, Vector2(chip_width, chip_height)), "glow": 0.0, "pins": []}
	var rect: Rect2 = chip["rect"]
	var chip_x0 := floori(rect.position.x / cell) - 1
	var chip_y0 := floori(rect.position.y / cell) - 1
	var chip_x1 := ceili(rect.end.x / cell) + 1
	var chip_y1 := ceili(rect.end.y / cell) + 1
	for x in range(chip_x0, chip_x1 + 1):
		for y in range(chip_y0, chip_y1 + 1):
			reserve(x, y)
	var area_scale := clampf(view.x * view.y / REFERENCE_AREA, 0.65, 1.65)
	var component_count := roundi(34.0 * area_scale)
	for component_index in range(component_count):
		var roll := rng.randf()
		var kind := "ic" if roll < 0.42 else "res" if roll < 0.78 else "cap"
		var width_cells := rng.randi_range(4, 6) if kind == "ic" else 1 if kind == "res" else 2
		var height_cells := rng.randi_range(3, 4) if kind == "ic" else rng.randi_range(3, 5) if kind == "res" else 2
		var spot := place_component(width_cells, height_cells)
		if spot.x < 0:
			continue
		var prefix := "U" if kind == "ic" else "R" if kind == "res" else "C"
		components.append({"kind": kind, "gx": spot.x, "gy": spot.y, "wc": width_cells, "hc": height_cells,
			"rect": Rect2(Vector2(float(spot.x) * cell, float(spot.y) * cell), Vector2(float(width_cells) * cell, float(height_cells) * cell)),
			"amber": false, "glow": 0.0, "out": [], "label": "%s%02d" % [prefix, component_index + 1], "show_label": component_index % 5 == 0,
			"reveal": rng.randf_range(0.30, 0.92)})
	var pins_per_side := maxi(6, roundi(chip_height / cell) + 2)
	add_chip_traces(0, pins_per_side, chip_x0, chip_y0, chip_x1, chip_y1)
	add_chip_traces(1, pins_per_side, chip_x0, chip_y0, chip_x1, chip_y1)
	add_chip_traces(2, 6, chip_x0, chip_y0, chip_x1, chip_y1)
	add_chip_traces(3, 6, chip_x0, chip_y0, chip_x1, chip_y1)
	var trace_attempts := roundi(130.0 * area_scale)
	for _index in range(trace_attempts):
		var x := rng.randi_range(1, cols - 2)
		var y := rng.randi_range(1, rows - 2)
		if is_occupied(x, y):
			continue
		reserve(x, y)
		var trace := route(x, y, [0, 2, 4, 6][rng.randi_range(0, 3)])
		if not trace.is_empty():
			trace["chip"] = false
			trace["amber"] = false
			trace["reveal"] = rng.randf_range(0.18, 0.96)
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
		trace["amber"] = false
		trace["reveal"] = rng.randf_range(0.05, 0.48)
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


func spawn_pulse(seed: int, inward: bool, color: Color, delay: float, key_event: bool = false) -> void:
	if traces.is_empty() or pulses.size() >= MAX_PULSES:
		return
	var candidates: Array[int] = []
	for index in range(traces.size()):
		if bool(traces[index]["chip"]):
			candidates.append(index)
	if candidates.is_empty():
		return
	var trace_index := candidates[posmod(seed, candidates.size())]
	pulses.append({"trace": trace_index, "distance": -delay * 290.0, "inward": inward, "color": color, "key_event": key_event})
	pass


func advance_pulses(delta: float) -> void:
	var speed := lerpf(72.0, 720.0, activity) * phase_speed_multiplier()
	for index in range(pulses.size() - 1, -1, -1):
		var pulse: Dictionary = pulses[index]
		var event_speed := 2.85 if bool(pulse.get("key_event", false)) and (chip_status.begins_with("EXEC") or chip_status.begins_with("TOOL")) else 1.0
		pulse["distance"] = float(pulse["distance"]) + delta * speed * event_speed
		var trace: Dictionary = traces[int(pulse["trace"])]
		trace["heat"] = 1.0
		if float(pulse["distance"]) < float(trace["length"]) + cell * 7.0:
			continue
		if bool(pulse["inward"]):
			chip["glow"] = minf(1.0, float(chip["glow"]) + 0.5)
		else:
			var component_index := int(trace["end_component"])
			if component_index >= 0:
				var component: Dictionary = components[component_index]
				component["glow"] = 1.0
				var branch_index := 0
				for outgoing_index: int in component["out"]:
					var branch_chance := 0.78 if bool(pulse.get("key_event", false)) else 0.4
					if rng.randf() < branch_chance:
						spawn_trace_pulse(outgoing_index, Color(pulse["color"]), 0.08 + float(branch_index) * 0.055, bool(pulse.get("key_event", false)))
						branch_index += 1
		pulses.remove_at(index)
	pass


func spawn_trace_pulse(trace_index: int, color: Color, delay: float = 0.0, key_event: bool = false) -> void:
	if pulses.size() >= MAX_PULSES:
		return
	pulses.append({"trace": trace_index, "distance": -delay * 290.0, "inward": false, "color": color, "key_event": key_event})
	pass


func _draw() -> void:
	ensure_board()
	var view := view_size()
	draw_background(view)
	var parallax := parallax_offset(view)
	draw_set_transform(parallax * 0.42)
	for trace: Dictionary in traces:
		draw_trace(trace)
	for component: Dictionary in components:
		draw_component(component)
	draw_set_transform(parallax)
	draw_chip()
	draw_response_burst()
	draw_completion_wave()
	for pulse: Dictionary in pulses:
		draw_pulse(pulse)
	draw_set_transform(Vector2.ZERO)
	pass


func parallax_offset(view: Vector2) -> Vector2:
	if view.x <= 1.0 or view.y <= 1.0:
		return Vector2.ZERO
	var normalized := (get_local_mouse_position() - view * 0.5) / (view * 0.5)
	return Vector2(clampf(normalized.x, -1.0, 1.0), clampf(normalized.y, -1.0, 1.0)) * 3.2


func draw_background(view: Vector2) -> void:
	var dark_theme := ThemeColor.is_dark_theme()
	if dark_theme:
		draw_rect(Rect2(Vector2.ZERO, view), Color("020705", BOARD_OPACITY))
	var grid_step := maxi(5, roundi(cell * 0.3))
	var grid_color := Color("beffdc", 0.012) if dark_theme else Color("164a33", 0.018)
	for x in range(0, int(view.x), grid_step):
		draw_line(Vector2(x, 0.0), Vector2(x, view.y), grid_color, 1.0)
	for y in range(0, int(view.y), grid_step):
		draw_line(Vector2(0.0, y), Vector2(view.x, y), grid_color, 1.0)
	for x in range(roundi(cell * 2.0), int(view.x), roundi(cell * 4.0)):
		for y in range(roundi(cell * 2.0), int(view.y), roundi(cell * 4.0)):
			draw_rect(Rect2(Vector2(x - 1, y - 1), Vector2(2, 2)), Color(board_green(), 0.045))
	pass


func draw_trace(trace: Dictionary) -> void:
	var points: PackedVector2Array = trace["points"]
	var color := board_amber() if bool(trace["amber"]) else board_green()
	var main_bus := bool(trace["chip"])
	var reveal_start := float(trace.get("reveal", 0.0))
	var growth := smoothstep(reveal_start, minf(1.0, reveal_start + 0.28), boot_progress)
	if growth <= 0.001:
		return
	var visible_points := partial_trace_points(trace, growth)
	var midpoint := (points[0] + points[points.size() - 1]) * 0.5
	var focus_distance := midpoint.distance_to(focus_position) / maxf(view_size().length() * 0.42, 1.0)
	var focus_alpha := lerpf(1.0, lerpf(1.12, 0.74, clampf(focus_distance, 0.0, 1.0)), focus_strength)
	var chip_rect: Rect2 = chip["rect"]
	var tide_progress := fmod(elapsed, 6.5) / 6.5
	var tide_radius := tide_progress * view_size().length() * 0.58
	var tide_band := 1.0 - clampf(absf(midpoint.distance_to(chip_rect.get_center()) - tide_radius) / maxf(cell * 5.0, 1.0), 0.0, 1.0)
	var heat := float(trace.get("heat", 0.0))
	var trace_alpha := ((0.18 if ThemeColor.is_dark_theme() else 0.32) if main_bus else (0.09 if ThemeColor.is_dark_theme() else 0.19)) * focus_alpha
	trace_alpha += tide_band * (0.025 if ThemeColor.is_dark_theme() else 0.018) + heat * (0.075 if main_bus else 0.045)
	var trace_width := maxf(1.7, cell * 0.12) if main_bus else maxf(1.2, cell * 0.075)
	draw_polyline(visible_points, Color(Color.BLACK, 0.30 if ThemeColor.is_dark_theme() else 0.05), trace_width + 0.7, true)
	draw_polyline(visible_points, Color(color, trace_alpha), trace_width, true)
	for point: Vector2 in [visible_points[0], visible_points[visible_points.size() - 1]]:
		var radius := maxf(2.6, cell * 0.14)
		draw_circle(point, radius, board_surface(0.95))
		draw_arc(point, radius, 0.0, TAU, 12, Color(color, 0.24 if not ThemeColor.is_dark_theme() else 0.19), 1.1, true)
		draw_circle(point, maxf(1.1, cell * 0.06), Color(color, 0.78))
	pass


func partial_trace_points(trace: Dictionary, progress: float) -> PackedVector2Array:
	var points: PackedVector2Array = trace["points"]
	var cumulative: PackedFloat32Array = trace["cumulative"]
	var target_distance := float(trace["length"]) * clampf(progress, 0.0, 1.0)
	var visible := PackedVector2Array([points[0]])
	for index in range(1, points.size()):
		if cumulative[index] <= target_distance:
			visible.append(points[index])
			continue
		var segment_length := maxf(cumulative[index] - cumulative[index - 1], 0.001)
		var ratio := (target_distance - cumulative[index - 1]) / segment_length
		visible.append(points[index - 1].lerp(points[index], clampf(ratio, 0.0, 1.0)))
		break
	return visible


func draw_component(component: Dictionary) -> void:
	if boot_progress < float(component.get("reveal", 0.0)):
		return
	var rect: Rect2 = component["rect"]
	var color := board_amber() if bool(component["amber"]) else board_green()
	var glow := float(component["glow"])
	if glow > 0.01:
		for layer in range(5, 0, -1):
			draw_rect(rect.grow(float(layer) * cell * 0.32), Color(color, glow * 0.008 * float(6 - layer)), true)
	var kind: String = component["kind"]
	if bool(component["show_label"]):
		draw_string(Fonts.regular(), rect.position - Vector2(0.0, 4.0), String(component["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, Typography.label_small, Color(board_green(), 0.30))
	if kind == "cap":
		var center := rect.get_center()
		var radius := rect.size.x * 0.34
		draw_circle(center, radius, board_surface(0.96))
		draw_arc(center, radius, 0.0, TAU, 18, Color(color, 0.28 + glow * 0.65), 1.3, true)
		draw_arc(center - Vector2(radius * 0.22, radius * 0.22), radius * 0.42, PI, PI * 1.55, 8, Color("b6ffd8", 0.18), 1.0, true)
		if glow > 0.01:
			var wave_radius := radius * (1.0 + (1.0 - glow) * 1.8)
			draw_arc(center, wave_radius, 0.0, TAU, 24, Color(color, glow * 0.34), 1.2, true)
		return
	if kind == "res":
		for row in range(int(component["hc"])):
			var resistor := Rect2(rect.position + Vector2(cell * 0.12, float(row) * cell + cell * 0.22), Vector2(rect.size.x - cell * 0.24, cell * 0.56))
			draw_rect(resistor, board_surface(0.96))
			var row_phase := fmod(elapsed * 5.0 + float(row) * 0.34, 1.0)
			var row_glow := glow * (0.55 + 0.45 * sin(row_phase * TAU))
			draw_rect(resistor, Color(color, 0.20 + row_glow * 0.66), false, 1.0 + row_glow)
		return
	var body := rect.grow(-cell * 0.3)
	var pins := maxi(3, int(component["wc"]) * 2 - 2)
	for pin in range(pins):
		var x := rect.position.x + cell * 0.5 + (rect.size.x - cell) * float(pin) / float(pins - 1)
		draw_line(Vector2(x, rect.position.y), Vector2(x, body.position.y), board_ink(0.23), 1.0)
		draw_line(Vector2(x, body.end.y), Vector2(x, rect.end.y), board_ink(0.23), 1.0)
	draw_rect(body, board_surface(0.97))
	draw_rect(body, Color(color, 0.25 + glow * 0.65), false, 1.0)
	draw_circle(body.position + Vector2(cell * 0.32, cell * 0.32), maxf(1.0, cell * 0.09), Color(color, 0.30))
	if glow > 0.01:
		var scan_x := lerpf(body.position.x, body.end.x, fmod(elapsed * 1.8, 1.0))
		draw_line(Vector2(scan_x, body.position.y + 2.0), Vector2(scan_x, body.end.y - 2.0), Color(color, glow * 0.42), 1.0)
	pass


func draw_chip() -> void:
	var rect: Rect2 = chip["rect"]
	var glow := float(chip["glow"])
	var beat := 0.5 + 0.5 * sin(elapsed * (4.5 if thinking else 1.8))
	var color := Colors.error if failed else board_hot_green()
	var pin_step := floori(elapsed * (14.0 if thinking else 6.0))
	for layer in range(11, 0, -1):
		draw_rect(rect.grow(float(layer) * 8.0), Color(color, (0.003 + glow * 0.007) * float(12 - layer) * (0.5 + beat * 0.5)), true)
	for pin in range(12):
		var x := rect.position.x + rect.size.x * (0.08 + 0.84 * float(pin) / 11.0)
		var pin_alpha := 0.72 if posmod(pin_step, 12) == pin else 0.30
		draw_line(Vector2(x, rect.position.y - cell * 0.34), Vector2(x, rect.position.y), Color(color, pin_alpha), 2.0)
		draw_line(Vector2(x, rect.end.y), Vector2(x, rect.end.y + cell * 0.34), Color(color, pin_alpha), 2.0)
	for pin in range(6):
		var y := rect.position.y + rect.size.y * (0.12 + 0.76 * float(pin) / 5.0)
		var pin_alpha := 0.72 if posmod(pin_step, 6) == pin else 0.30
		draw_line(Vector2(rect.position.x - cell * 0.34, y), Vector2(rect.position.x, y), Color(color, pin_alpha), 2.0)
		draw_line(Vector2(rect.end.x, y), Vector2(rect.end.x + cell * 0.34, y), Color(color, pin_alpha), 2.0)
	draw_rect(rect, board_surface(0.96))
	for layer in range(5):
		var inset := 3.0 + float(layer) * 4.0
		draw_rect(rect.grow(-inset), Color(color, 0.012 * float(5 - layer)), true)
	draw_rect(rect, Color(board_green(), 0.90), false, 2.0)
	draw_rect(rect.grow(-5.0), Color(board_green(), 0.23 + glow * 0.55), false, 1.0)
	draw_circle(rect.position + Vector2(14.0, 14.0), 3.5, Color(board_green(), 0.45))
	draw_holographic_core(rect, color, glow)
	var scan_y := rect.position.y + fmod(elapsed * (34.0 if thinking else 16.0), rect.size.y)
	draw_line(Vector2(rect.position.x + 7.0, scan_y), Vector2(rect.end.x - 7.0, scan_y), Color(color, 0.035 + glow * 0.06), 1.0)
	draw_centered_text(rect.get_center() - Vector2(0.0, 5.0), chip_status, Fonts.semibold(), Typography.title_medium, Color(color, 0.76 + beat * 0.20))
	draw_centered_text(rect.get_center() + Vector2(0.0, 22.0), chip_detail_text(), Fonts.regular(), Typography.label_small, Color(color, 0.46))
	pass


func draw_holographic_core(rect: Rect2, color: Color, glow: float) -> void:
	var speed := 1.8 if thinking else 0.75
	var radius := minf(24.0, rect.size.y * 0.19)
	var core_center := rect.get_center()
	var core_radius := minf(34.0, rect.size.y * 0.26)
	for ring in range(3):
		var ring_radius := core_radius * (0.46 + float(ring) * 0.24)
		var start_angle := elapsed * speed * (1.0 if ring % 2 == 0 else -1.0) + float(ring)
		draw_arc(core_center, ring_radius, start_angle, start_angle + PI * (0.72 + float(ring) * 0.12), 24, Color(color, 0.055 + glow * 0.055), 1.0, true)
	var neural_points := PackedVector2Array()
	for index in range(5):
		var angle := elapsed * speed * (0.42 + float(index) * 0.06) + float(index) * TAU / 5.0
		var point := core_center + Vector2.from_angle(angle) * core_radius * (0.30 + float(index % 2) * 0.25)
		neural_points.append(point)
		draw_circle(point, 1.3 + glow * 0.8, Color(color, 0.20 + glow * 0.20))
	for index in range(neural_points.size()):
		draw_line(neural_points[index], neural_points[(index + 2) % neural_points.size()], Color(color, 0.035 + glow * 0.05), 0.8, true)
	for side: float in [-1.0, 1.0]:
		var center := rect.get_center() + Vector2(rect.size.x * 0.34 * side, 0.0)
		var rotation: float = elapsed * speed * side
		var outer := polygon_points(center, radius, 6, rotation)
		outer.append(outer[0])
		var inner := polygon_points(center, radius * 0.56, 6, -rotation * 1.45)
		inner.append(inner[0])
		draw_polyline(outer, Color(color, 0.14 + glow * 0.18), 1.0, true)
		draw_polyline(inner, Color(color, 0.20 + glow * 0.22), 1.0, true)
		var orbit_position := center + Vector2.from_angle(rotation * 1.7) * radius * 0.78
		draw_circle(orbit_position, 1.7 + glow, Color(color, 0.46 + glow * 0.30))
	pass


func draw_completion_wave() -> void:
	if completion_wave < 0.0:
		return
	var rect: Rect2 = chip["rect"]
	var progress := clampf(completion_wave / 1.35, 0.0, 1.0)
	var max_radius := view_size().length() * 0.46
	var radius := lerpf(rect.size.x * 0.28, max_radius, ease(progress, -1.7))
	var color := Colors.error if failed else board_hot_green()
	draw_arc(rect.get_center(), radius, 0.0, TAU, 96, Color(color, (1.0 - progress) * 0.30), 2.0, true)
	pass


func draw_response_burst() -> void:
	if response_burst < 0.0:
		return
	var rect: Rect2 = chip["rect"]
	var center := rect.get_center()
	var color := board_hot_green()
	if response_burst < 0.36:
		var gather := clampf(response_burst / 0.36, 0.0, 1.0)
		for ring in range(3):
			var start_radius := rect.size.x * (0.62 + float(ring) * 0.18)
			var radius := lerpf(start_radius, rect.size.y * 0.16, ease(gather, 2.2))
			draw_arc(center, radius, 0.0, TAU, 72, Color(color, 0.08 + gather * 0.16), 1.2, true)
		draw_circle(center, lerpf(3.0, 8.0, gather), Color(color, gather * 0.42))
		return
	var release := clampf((response_burst - 0.36) / 0.50, 0.0, 1.0)
	var radius := lerpf(rect.size.y * 0.12, view_size().length() * 0.32, ease(release, -1.8))
	draw_arc(center, radius, 0.0, TAU, 96, Color(color, (1.0 - release) * 0.34), 2.4 - release, true)
	for ray in range(8):
		var angle := float(ray) * TAU / 8.0
		var inner := center + Vector2.from_angle(angle) * rect.size.y * 0.16
		var outer := center + Vector2.from_angle(angle) * minf(radius, rect.size.x * 0.72)
		draw_line(inner, outer, Color(color, (1.0 - release) * 0.16), 1.0, true)
	pass


func draw_pulse(pulse: Dictionary) -> void:
	var trace: Dictionary = traces[int(pulse["trace"])]
	var distance := float(pulse["distance"])
	if distance < 0.0 or distance > float(trace["length"]):
		return
	var color: Color = pulse["color"]
	var tail_length := minf(view_size().x, view_size().y) * (0.10 + activity * 0.13)
	var start_distance := maxf(0.0, distance - tail_length)
	var inward := bool(pulse["inward"])
	var trace_length := float(trace["length"])
	var segment_from := trace_length - distance if inward else start_distance
	var segment_to := trace_length - start_distance if inward else distance
	var head_distance := trace_length - distance if inward else distance
	draw_trace_segment(trace, segment_from, segment_to, head_distance, color)
	var position := trace_position(trace, head_distance)
	for radius in [44.0, 32.0, 22.0]:
		draw_circle(position, radius, Color(color, 0.006 * (46.0 / radius)))
	for radius in [16.0, 9.0, 4.0]:
		draw_circle(position, radius, Color(color, 0.035 * (17.0 / radius)))
	draw_circle(position, maxf(1.5, cell * 0.07), Color(color, 0.98))
	for packet_index in range(1, 4):
		var packet_travel := distance - float(packet_index) * cell * 0.58
		if packet_travel < 0.0:
			continue
		var packet_distance := trace_length - packet_travel if inward else packet_travel
		var packet_position := trace_position(trace, clampf(packet_distance, 0.0, trace_length))
		var packet_alpha := 0.62 - float(packet_index) * 0.12
		draw_circle(packet_position, maxf(1.0, cell * (0.060 - float(packet_index) * 0.008)), Color(color, packet_alpha))
	pass


func draw_trace_segment(trace: Dictionary, from_distance: float, to_distance: float, head_distance: float, color: Color) -> void:
	var cumulative: PackedFloat32Array = trace["cumulative"]
	var points: PackedVector2Array = trace["points"]
	var visible_length := maxf(to_distance - from_distance, 0.001)
	for index in range(1, cumulative.size()):
		var segment_start := maxf(cumulative[index - 1], from_distance)
		var segment_end := minf(cumulative[index], to_distance)
		if segment_end <= segment_start:
			continue
		var full_length := maxf(cumulative[index] - cumulative[index - 1], 0.001)
		var slice_count := clampi(ceili((segment_end - segment_start) / maxf(8.0, cell * 0.55)), 1, 16)
		for slice in range(slice_count):
			var slice_start := lerpf(segment_start, segment_end, float(slice) / float(slice_count))
			var slice_end := lerpf(segment_start, segment_end, float(slice + 1) / float(slice_count))
			var a := points[index - 1].lerp(points[index], (slice_start - cumulative[index - 1]) / full_length)
			var b := points[index - 1].lerp(points[index], (slice_end - cumulative[index - 1]) / full_length)
			var midpoint := (slice_start + slice_end) * 0.5
			var tail_progress := clampf(1.0 - absf(head_distance - midpoint) / visible_length, 0.0, 1.0)
			var alpha := (0.06 + 0.82 * tail_progress * tail_progress) * (0.72 + activity * 0.28)
			var width := lerpf(maxf(1.0, cell * 0.065), maxf(1.8, cell * 0.13), tail_progress)
			draw_line(a, b, Color(color, alpha), width, true)
	pass


func trace_position(trace: Dictionary, distance: float) -> Vector2:
	var cumulative: PackedFloat32Array = trace["cumulative"]
	var points: PackedVector2Array = trace["points"]
	for index in range(1, cumulative.size()):
		if distance <= cumulative[index]:
			var ratio := (distance - cumulative[index - 1]) / maxf(cumulative[index] - cumulative[index - 1], 0.001)
			return points[index - 1].lerp(points[index], ratio)
	return points[points.size() - 1]
