class_name QuantumCircuit
extends VisualEffect

## Each turn becomes a quantum wire. Reasoning creates rotating gates, tools become
## controlled operations, and the final answer collapses every wire to one state.

const MAX_WIRES := 12
const GATE_TRAVEL_SECONDS := 0.52
const MEASURE_SECONDS := 0.9
const COLLAPSE_SECONDS := 1.45
const CYAN := Color("#55f6ff")
const VIOLET := Color("#a875ff")
const MAGENTA := Color("#ff4fd8")
const SUCCESS := Color("#7dffb2")
const ERROR := Color("#ff5277")
const VOID := Color("#030711")

enum GateKind { HADAMARD, PHASE, ROTATION, TOOL }
enum GateState { EVOLVING, RUNNING, MEASURED, FAILED }

var wires: Array[Dictionary] = []
var tool_gates: Dictionary[String, Dictionary] = {}
var active_wire: Dictionary = {}
var elapsed: float = 0.0
var pulse: float = 0.0
var collapse: float = 0.0
var completing: bool = false
var ended_with_error: bool = false
var turn_serial: int = 0
var gate_serial: int = 0
var next_replacement_slot: int = 0
var fade_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.QUANTUM_CIRCUIT


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
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.38)
	fade_tween.tween_callback(func() -> void: visible = false; modulate.a = 1.0)
	pass


func reset_visual() -> void:
	wires.clear()
	tool_gates.clear()
	active_wire = {}
	elapsed = 0.0
	pulse = 0.0
	collapse = 0.0
	completing = false
	ended_with_error = false
	turn_serial = 0
	gate_serial = 0
	next_replacement_slot = 0
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	pulse = 1.0
	pass


func on_agent_end(error_message: String) -> float:
	ended_with_error = StringUtils.is_not_blank(error_message)
	completing = true
	return COLLAPSE_SECONDS


func on_turn_start() -> void:
	if not active_wire.is_empty():
		active_wire["active"] = false
	turn_serial += 1
	var wire := {"turn": turn_serial, "gates": [], "phase": 0.0, "decoherence": 0.0, "complete": false, "active": true}
	if wires.size() >= MAX_WIRES:
		# Keep every visual slot stationary. Shifting the array would move all existing
		# wires upward for every new turn, which reads as a full-screen UI hitch.
		var removed: Dictionary = wires[next_replacement_slot]
		for gate: Dictionary in removed["gates"]:
			if int(gate["kind"]) == GateKind.TOOL:
				tool_gates.erase(String(gate["id"]))
		wires[next_replacement_slot] = wire
		next_replacement_slot = (next_replacement_slot + 1) % MAX_WIRES
	else:
		wires.append(wire)
	active_wire = wire
	pulse = 1.0
	pass


func on_turn_end() -> void:
	if not active_wire.is_empty():
		active_wire["complete"] = true
		active_wire["active"] = false
	pass


func on_message_update(chunk: String, stream_kind: String) -> void:
	ensure_wire()
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		var count := maxi(1, ceili(float(chunk.length()) / 24.0))
		for index in range(count):
			var kind := (turn_serial + (active_wire["gates"] as Array).size() + index) % 3
			append_gate(kind, "", "")
	else:
		active_wire["phase"] = minf(float(active_wire["phase"]) + 0.12, 1.0)
	pulse = 1.0
	pass


func on_tool_execution_start(tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	ensure_wire()
	var gate := append_gate(GateKind.TOOL, tool_call_id, public_tool_name(tool_name))
	gate["state"] = GateState.RUNNING
	tool_gates[tool_call_id] = gate
	pulse = 1.0
	pass


func on_tool_execution_end(tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if not tool_gates.has(tool_call_id):
		return
	var gate: Dictionary = tool_gates[tool_call_id]
	gate["state"] = GateState.FAILED if result.is_error else GateState.MEASURED
	gate["event_age"] = 0.0
	if result.is_error:
		var wire: Dictionary = gate["wire"]
		wire["decoherence"] = 1.0
	pulse = 1.0
	pass


func on_theme_changed() -> void:
	queue_redraw()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	pulse = move_toward(pulse, 0.16, delta * 0.9)
	for wire: Dictionary in wires:
		wire["phase"] = fmod(float(wire["phase"]) + delta * 0.24, 1.0)
		wire["decoherence"] = move_toward(float(wire["decoherence"]), 0.0, delta * 0.12)
		for gate: Dictionary in wire["gates"]:
			gate["age"] = float(gate["age"]) + delta
			gate["event_age"] = float(gate["event_age"]) + delta
	if completing:
		collapse = minf(collapse + delta / COLLAPSE_SECONDS, 1.0)
	queue_redraw()
	pass


func _draw() -> void:
	if size.x < 320.0 or size.y < 220.0:
		return
	draw_background()
	draw_probability_field()
	draw_qpu_core()
	draw_header()
	var center_y := size.y * 0.53
	var spacing := minf(72.0, (size.y - 154.0) / maxf(float(wires.size() - 1), 1.0))
	var top := center_y - spacing * float(wires.size() - 1) * 0.5
	draw_entanglements(top, spacing)
	for index in range(wires.size()):
		draw_wire(wires[index], index, top + index * spacing)
	draw_quantum_readout(center_y)
	if completing:
		draw_collapse(center_y, top, spacing)
	pass


func draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(VOID, 0.62), true)
	for x in range(0, int(size.x), 48):
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(CYAN, 0.035), 1.0)
	for y in range(0, int(size.y), 48):
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(CYAN, 0.035), 1.0)
	for index in range(24):
		var x := fmod(float(index * 197) + elapsed * (9.0 + index % 4), maxf(size.x, 1.0))
		var y := fmod(float(index * 83), maxf(size.y, 1.0))
		draw_circle(Vector2(x, y), 1.2, Color(VIOLET, 0.16))
	pass


func draw_probability_field() -> void:
	# Interfering translucent lobes make the register read as a probability field instead
	# of a collection of independent progress bars.
	var center := Vector2(size.x * 0.52, size.y * 0.51)
	for lobe in range(9, 0, -1):
		var phase := elapsed * (0.22 + lobe * 0.018)
		var radius := minf(size.x, size.y) * (0.08 + lobe * 0.038)
		var offset := Vector2(cos(phase + lobe * 1.7), sin(phase * 1.31 + lobe)) * radius * 0.2
		var color := VIOLET if lobe % 3 else MAGENTA
		draw_circle(center + offset, radius, Color(color, 0.0045 + pulse * 0.0015))
	# Two counter-rotating phase waves cross the full register.
	for wave in range(2):
		var points := PackedVector2Array()
		for step in range(65):
			var ratio := float(step) / 64.0
			var x := lerpf(74.0, size.x - 92.0, ratio)
			var envelope := sin(ratio * PI)
			var y := center.y + sin(ratio * TAU * (2.0 + wave) + elapsed * (1.1 if wave == 0 else -0.8)) * (18.0 + wave * 11.0) * envelope
			points.append(Vector2(x, y))
		draw_polyline(points, Color(CYAN if wave == 0 else VIOLET, 0.08 + pulse * 0.035), 1.0, true)
	pass


func draw_qpu_core() -> void:
	# The QPU is the composition's focal point. Wires pass through its probability well,
	# while tools occupy the surrounding operating ring.
	var center := Vector2(size.x * 0.72, size.y * 0.53)
	var base_radius := minf(size.x, size.y) * 0.17
	var core_color := ERROR if ended_with_error else SUCCESS if completing else VIOLET
	for layer in range(12, 0, -1):
		var radius := base_radius * (0.3 + layer * 0.085)
		draw_circle(center, radius, Color(core_color, 0.0025 * (13 - layer)))
	# Counter-rotating broken rings read as active hardware rather than a flat target.
	for ring in range(7):
		var radius := base_radius * (0.44 + ring * 0.13)
		var rotation := elapsed * (0.22 + ring * 0.07) * (-1.0 if ring % 2 else 1.0)
		for segment in range(4):
			var start := rotation + segment * TAU / 4.0
			var span := 0.38 + 0.18 * sin(elapsed + ring * 1.7 + segment)
			draw_arc(center, radius, start, start + span, 18, Color(CYAN if ring % 2 else core_color, 0.14 + ring * 0.035), 1.0 + ring * 0.32, true)
	# A rotating wireframe polyhedron forms the processor's determinate-state chamber.
	var vertices := PackedVector2Array()
	for index in range(8):
		var angle := elapsed * 0.33 + index * TAU / 8.0
		var squash := 0.58 + 0.18 * sin(elapsed * 0.7 + index)
		vertices.append(center + Vector2(cos(angle), sin(angle) * squash) * base_radius * 0.47)
	vertices.append(vertices[0])
	draw_polyline(vertices, Color(core_color, 0.72), 2.0, true)
	for index in range(4):
		draw_line(vertices[index], vertices[index + 4], Color(CYAN, 0.21), 1.0, true)
	var heartbeat := 0.72 + 0.28 * sin(elapsed * 4.0)
	draw_circle(center, base_radius * 0.19 * heartbeat, Color(core_color, 0.055))
	draw_arc(center, base_radius * 0.19 * heartbeat, 0.0, TAU, 40, Color(core_color, 0.9), 2.5, true)
	draw_centered_text(center + Vector2(0.0, 5.0), "QPU", Fonts.semibold(), Typography.label_large_size, Color(core_color, 0.92))
	# Radial telemetry makes the core feel connected to the desktop runtime.
	for ray in range(16):
		var angle := ray * TAU / 16.0 + elapsed * 0.04
		var inner := center + Vector2.from_angle(angle) * base_radius * 1.08
		var outer := center + Vector2.from_angle(angle) * base_radius * (1.13 + (ray % 3) * 0.06)
		draw_line(inner, outer, Color(CYAN if ray % 4 else MAGENTA, 0.28), 1.0)
	pass


func draw_entanglements(top: float, spacing: float) -> void:
	if wires.size() < 2:
		return
	var left := 90.0
	var right := size.x - 118.0
	var settle := smoothstep(0.18, 0.82, collapse)
	for index in range(wires.size() - 1):
		if (index + turn_serial) % 3 == 1:
			continue
		var upper_y := lerpf(top + index * spacing, size.y * 0.52, settle)
		var lower_index := mini(index + 1 + (index % 2), wires.size() - 1)
		var lower_y := lerpf(top + lower_index * spacing, size.y * 0.52, settle)
		var x := lerpf(left, right, 0.19 + fmod(float(index) * 0.217, 0.62))
		var color := VIOLET if index % 2 else CYAN
		draw_line(Vector2(x, upper_y), Vector2(x, lower_y), Color(color, 0.2), 1.5, true)
		draw_circle(Vector2(x, upper_y), 4.5, Color(color, 0.85))
		draw_circle(Vector2(x, lower_y), 9.0, Color(VOID, 0.9))
		draw_arc(Vector2(x, lower_y), 8.0, 0.0, TAU, 24, Color(color, 0.8), 1.5, true)
		var packet_y := lerpf(upper_y, lower_y, 0.5 + 0.5 * sin(elapsed * 2.4 + index))
		draw_circle(Vector2(x, packet_y), 2.5, Color(color, 0.95))
	pass


func draw_quantum_readout(center_y: float) -> void:
	var x := size.x - 62.0
	var height := minf(size.y * 0.44, 310.0)
	var top := center_y - height * 0.5
	draw_line(Vector2(x, top), Vector2(x, top + height), Color(VIOLET, 0.18), 1.0)
	for index in range(17):
		var y := top + index * height / 16.0
		var probability := 0.25 + 0.75 * absf(sin(elapsed * 0.9 + index * 2.37))
		var length := 4.0 + probability * 20.0
		draw_line(Vector2(x - length, y), Vector2(x, y), Color(CYAN if index % 4 else MAGENTA, 0.18 + probability * 0.32), 1.0)
	draw_string(Fonts.regular(), Vector2(x - 44.0, top - 10.0), "P(q)", HORIZONTAL_ALIGNMENT_CENTER, 40.0, Typography.label_small_size, Color(VIOLET, 0.55))
	pass


func draw_header() -> void:
	draw_line(Vector2(34.0, 42.0), Vector2(size.x - 34.0, 42.0), Color(ThemeColor.accent_theme_color(), 0.18), 1.0)
	draw_string(Fonts.semibold(), Vector2(38.0, 32.0), "QUANTUM CIRCUIT // LIVE", HORIZONTAL_ALIGNMENT_LEFT, 300.0, Typography.label_large_size, Color(CYAN, 0.88))
	var state := "COLLAPSING" if completing else "SUPERPOSITION"
	draw_string(Fonts.medium(), Vector2(size.x - 220.0, 32.0), state, HORIZONTAL_ALIGNMENT_RIGHT, 180.0, Typography.label_small_size, Color(SUCCESS if completing else MAGENTA, 0.78))
	draw_string(Fonts.regular(), Vector2(38.0, size.y - 27.0), "|psi>  UNITARY REASONING BUS", HORIZONTAL_ALIGNMENT_LEFT, 260.0, Typography.label_small_size, Color(ColorBase.secondary_text, 0.62))
	pass


func draw_wire(wire: Dictionary, wire_index: int, y: float) -> void:
	var left := 90.0
	var right := size.x - 118.0
	var decoherence := float(wire["decoherence"])
	var settle := smoothstep(0.18, 0.82, collapse)
	y = lerpf(y, size.y * 0.52, settle)
	if bool(wire.get("active", false)) and not completing:
		draw_active_wire_effect(left, right, y, wire_index)
	if decoherence > 0.01:
		draw_decoherent_wire(left, right, y, decoherence, wire_index)
	else:
		draw_lensed_wire(left, right, y, right, Color(CYAN, 0.18 + pulse * 0.2), 1.0)
		var phase_x := lerpf(left, right, float(wire["phase"]))
		for glow in range(5, 0, -1):
			draw_lensed_wire(left, right, y, phase_x, Color(CYAN, 0.008 * (6 - glow)), 1.0 + glow * 2.2)
		draw_lensed_wire(left, right, y, phase_x, Color(CYAN, 0.88), 2.0)
		for packet in range(3):
			var packet_phase := fmod(float(wire["phase"]) - packet * 0.07 + 1.0, 1.0)
			var packet_x := lerpf(left, right, packet_phase)
			draw_circle(Vector2(packet_x, y), 2.0 + packet, Color(CYAN, 0.75 - packet * 0.18))
	draw_string(Fonts.medium(), Vector2(34.0, y + 5.0), "q%02d" % int(wire["turn"]), HORIZONTAL_ALIGNMENT_LEFT, 48.0, Typography.label_small_size, Color(CYAN, 0.66))
	draw_ket(Vector2(right + 24.0, y), "|1>" if collapse > 0.68 and not ended_with_error else "|?>", SUCCESS if collapse > 0.68 else VIOLET)
	var gates: Array = wire["gates"]
	for gate_index in range(gates.size()):
		var gate: Dictionary = gates[gate_index]
		var x := lerpf(left + 48.0, right - 42.0, float(gate["x_ratio"]))
		var gate_position := Vector2(lerpf(x, right + 24.0, settle), y)
		if int(gate["kind"]) == GateKind.TOOL and settle < 0.5:
			var core := Vector2(size.x * 0.72, size.y * 0.53)
			var orbit_angle := float(gate["orbit_angle"]) + sin(elapsed * 0.35 + float(gate["spin"])) * 0.08
			var orbit_radius := minf(size.x, size.y) * 0.245
			var orbital_position := core + Vector2.from_angle(orbit_angle) * orbit_radius
			draw_line(gate_position, orbital_position, Color(MAGENTA, 0.18), 1.0, true)
			gate_position = orbital_position
		draw_gate(gate, gate_position, decoherence)
	pass


func draw_active_wire_effect(left: float, right: float, y: float, wire_index: int) -> void:
	var breathe := 0.5 + 0.5 * sin(elapsed * 3.4)
	var band_height := 38.0 + breathe * 8.0
	# Wide energy volume establishes the active turn before any small gate detail is read.
	for layer in range(6, 0, -1):
		var height := band_height + layer * 10.0
		var rect := Rect2(Vector2(left - 18.0, y - height * 0.5), Vector2(right - left + 36.0, height))
		draw_rect(rect, Color(CYAN, 0.0025 * (7 - layer)), true)
	var scan_ratio := fmod(elapsed * 0.34 + wire_index * 0.071, 1.0)
	var scan_x := lerpf(left, right, scan_ratio)
	for glow in range(5, 0, -1):
		draw_line(Vector2(scan_x, y - band_height * 0.48), Vector2(scan_x, y + band_height * 0.48), Color(CYAN, 0.025 * (6 - glow)), 1.0 + glow * 3.0, true)
	draw_line(Vector2(scan_x, y - band_height * 0.48), Vector2(scan_x, y + band_height * 0.48), Color(CYAN, 0.9), 1.5, true)
	# Moving corner brackets make the lane feel selected by the runtime scheduler.
	var bracket := 13.0
	var x0 := left - 12.0
	var x1 := right + 12.0
	var y0 := y - band_height * 0.5
	var y1 := y + band_height * 0.5
	for corner: Vector2 in [Vector2(x0, y0), Vector2(x1, y0), Vector2(x0, y1), Vector2(x1, y1)]:
		var horizontal := 1.0 if corner.x == x0 else -1.0
		var vertical := 1.0 if corner.y == y0 else -1.0
		draw_line(corner, corner + Vector2(horizontal * bracket, 0.0), Color(CYAN, 0.55 + breathe * 0.3), 1.5)
		draw_line(corner, corner + Vector2(0.0, vertical * bracket), Color(CYAN, 0.55 + breathe * 0.3), 1.5)
	var label_position := Vector2(left + 8.0, y - band_height * 0.5 - 7.0)
	draw_string(Fonts.semibold(), label_position, "● EXECUTING  /  QUANTUM CHANNEL LOCKED", HORIZONTAL_ALIGNMENT_LEFT, 310.0, Typography.label_small_size, Color(CYAN, 0.7 + breathe * 0.25))
	# Oscilloscope trace rides directly on the active lane.
	var waveform := PackedVector2Array()
	for step in range(49):
		var ratio := float(step) / 48.0
		var x := lerpf(left, right, ratio)
		var envelope := sin(ratio * PI)
		var offset := sin(ratio * TAU * 9.0 - elapsed * 8.0) * 4.0 * envelope
		waveform.append(Vector2(x, y + offset))
	draw_polyline(waveform, Color(CYAN, 0.34 + breathe * 0.18), 1.0, true)
	pass


func draw_lensed_wire(left: float, right: float, y: float, limit_x: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var core := Vector2(size.x * 0.72, size.y * 0.53)
	var radius := minf(size.x, size.y) * 0.22
	var steps := maxi(2, ceili((limit_x - left) / 34.0))
	for step in range(steps + 1):
		var x := lerpf(left, limit_x, float(step) / steps)
		var horizontal_distance := (x - core.x) / radius
		var influence := exp(-horizontal_distance * horizontal_distance * 2.4)
		var vertical_distance := y - core.y
		var direction := -1.0 if vertical_distance < 0.0 else 1.0
		if absf(vertical_distance) < 4.0:
			direction = -1.0 if int(y) % 2 else 1.0
		var bend := direction * influence * maxf(0.0, 1.0 - absf(vertical_distance) / radius) * 24.0
		points.append(Vector2(x, y + bend))
	if points.size() >= 2:
		draw_polyline(points, color, width, true)
	pass


func draw_decoherent_wire(left: float, right: float, y: float, amount: float, seed: int) -> void:
	var previous := Vector2(left, y)
	for index in range(1, 39):
		var x := lerpf(left, right, float(index) / 38.0)
		var current := Vector2(x, y + sin(index * 5.13 + seed * 2.7 + elapsed * 18.0) * amount * 7.0)
		if index % 7 != 0:
			draw_line(previous, current, Color(ERROR, 0.25 + amount * 0.5), 1.5, true)
		previous = current
	pass


func draw_gate(gate: Dictionary, position: Vector2, decoherence: float) -> void:
	var state := int(gate["state"])
	var kind := int(gate["kind"])
	var arrival := clampf(float(gate["age"]) / GATE_TRAVEL_SECONDS, 0.0, 1.0)
	var radius := (18.0 if kind != GateKind.TOOL else 28.0) * ease(arrival, -2.0)
	var color := ERROR if state == GateState.FAILED else SUCCESS if state == GateState.MEASURED else MAGENTA if kind == GateKind.TOOL else CYAN
	var spin := elapsed * (2.8 if state == GateState.RUNNING else 1.35) + float(gate["spin"])
	var wake_length := 34.0 + minf(float(gate["age"]) * 16.0, 80.0)
	for wake in range(4, 0, -1):
		draw_line(position - Vector2(wake_length + wake * 9.0, 0.0), position - Vector2(radius, 0.0), Color(color, 0.018 * (5 - wake)), float(wake) * 2.5, true)
	if kind == GateKind.TOOL:
		draw_tool_control_column(position, radius, color, state)
	if state == GateState.MEASURED:
		draw_measurement_flash(position, float(gate["event_age"]), color)
	if state == GateState.FAILED:
		draw_noise(position, float(gate["event_age"]), decoherence)
	for ring in range(3, 0, -1):
		draw_circle(position, radius + ring * 5.0, Color(color, 0.025 * (4 - ring)))
	var points := PackedVector2Array()
	for corner in range(4):
		points.append(position + Vector2.from_angle(spin + PI * 0.25 + corner * PI * 0.5) * radius)
	points.append(points[0])
	draw_polyline(points, Color(color, 0.35 if state == GateState.FAILED else 0.9), 2.0, true)
	for satellite in range(3):
		var satellite_angle := -spin * 0.7 + satellite * TAU / 3.0
		var satellite_position := position + Vector2.from_angle(satellite_angle) * (radius + 11.0)
		draw_circle(satellite_position, 2.2, Color(color, 0.7))
	var label := String(gate["label"]) if kind == GateKind.TOOL else gate_label(kind)
	draw_centered_text(position + Vector2(0.0, 5.0), label, Fonts.semibold(), Typography.label_small_size, Color(color, 0.92))
	pass


func draw_tool_control_column(position: Vector2, radius: float, color: Color, state: int) -> void:
	# Tool operations are deliberately wider than a single wire: they temporarily couple
	# the active qubit to the operating-system/tool plane.
	var reach := 30.0 + 8.0 * sin(elapsed * 2.0)
	draw_line(position - Vector2(0.0, radius + reach), position + Vector2(0.0, radius + reach), Color(color, 0.14), 5.0, true)
	draw_line(position - Vector2(0.0, radius + reach), position + Vector2(0.0, radius + reach), Color(color, 0.52), 1.0, true)
	for side: float in [-1.0, 1.0]:
		var endpoint := position + Vector2(0.0, side * (radius + reach))
		draw_circle(endpoint, 7.0, Color(color, 0.08))
		draw_arc(endpoint, 5.0, 0.0, TAU, 20, Color(color, 0.72), 1.5, true)
	var orbit_radius := radius + 17.0
	draw_arc(position, orbit_radius, elapsed * 1.7, elapsed * 1.7 + PI * 1.3, 32, Color(color, 0.5), 2.0, true)
	if state == GateState.RUNNING:
		for index in range(6):
			var angle := elapsed * 2.2 + index * TAU / 6.0
			draw_circle(position + Vector2.from_angle(angle) * orbit_radius, 2.8, Color(color, 0.9))
	pass


func draw_measurement_flash(position: Vector2, age: float, color: Color) -> void:
	var progress := clampf(age / MEASURE_SECONDS, 0.0, 1.0)
	var radius := 18.0 + progress * 58.0
	draw_arc(position, radius, 0.0, TAU, 48, Color(color, (1.0 - progress) * 0.7), 2.5, true)
	for index in range(8):
		var direction := Vector2.from_angle(index * TAU / 8.0)
		draw_line(position + direction * 24.0, position + direction * radius, Color(color, (1.0 - progress) * 0.62), 2.0, true)
	pass


func draw_noise(position: Vector2, age: float, amount: float) -> void:
	for index in range(13):
		var angle := index * 2.19 + elapsed * (2.0 + index % 3)
		var radius := 18.0 + fmod(index * 17.0 + age * 48.0, 52.0)
		var p := position + Vector2.from_angle(angle) * radius
		draw_line(p - Vector2(3.0, 0.0), p + Vector2(3.0 + amount * 5.0, 0.0), Color(ERROR, 0.5), 1.0)
	pass


func draw_collapse(center_y: float, top: float, spacing: float) -> void:
	var progress := smoothstep(0.15, 1.0, collapse)
	var right := size.x - 94.0
	for index in range(wires.size()):
		var from := Vector2(right - 34.0, top + index * spacing)
		draw_line(from, from.lerp(Vector2(right, center_y), progress), Color(ERROR if ended_with_error else SUCCESS, 0.24 + progress * 0.52), 2.0, true)
	var color := ERROR if ended_with_error else SUCCESS
	var radius := 22.0 + sin(elapsed * 8.0) * 3.0
	draw_circle(Vector2(right, center_y), radius + progress * 36.0, Color(color, 0.035 * progress))
	draw_arc(Vector2(right, center_y), radius, 0.0, TAU, 48, Color(color, progress), 3.0, true)
	if collapse > 0.7:
		draw_centered_text(Vector2(size.x * 0.5, 86.0), "STATE ERROR  |X>" if ended_with_error else "DETERMINATE STATE  |1>", Fonts.semibold(), Typography.title_medium_size, Color(color, progress))
	pass


func draw_ket(position: Vector2, text: String, color: Color) -> void:
	draw_centered_text(position + Vector2(0.0, 5.0), text, Fonts.medium(), Typography.label_small_size, Color(color, 0.72))
	pass


func append_gate(kind: int, id: String, label: String) -> Dictionary:
	gate_serial += 1
	var distribution := fmod(float(gate_serial) * 0.61803398875 + float(turn_serial) * 0.137, 1.0)
	var gate := {"kind": kind, "id": id, "label": label, "state": GateState.EVOLVING, "age": 0.0, "event_age": 99.0, "spin": randf() * TAU, "wire": active_wire, "x_ratio": lerpf(0.08, 0.9, distribution), "orbit_angle": fmod(float(gate_serial) * 2.39996, TAU)}
	var gates: Array = active_wire["gates"]
	if gates.size() >= 14:
		gates.pop_front()
	gates.append(gate)
	return gate


func ensure_wire() -> void:
	if active_wire.is_empty():
		on_turn_start()
	pass


static func gate_x(index: int, count: int, left: float, right: float) -> float:
	return lerpf(left + 48.0, right - 42.0, float(index + 1) / float(maxi(count + 1, 2)))


static func gate_label(kind: int) -> String:
	match kind:
		GateKind.HADAMARD:
			return "H"
		GateKind.PHASE:
			return "S"
		GateKind.ROTATION:
			return "Ry"
	return "U"


static func public_tool_name(tool_name: String) -> String:
	var readable := tool_name.replace("_", " ").replace("-", " ").strip_edges()
	if readable.is_empty():
		return "TOOL"
	return String(readable.split(" ", false)[0]).left(7).to_upper()


func draw_centered_text(position: Vector2, text: String, font: Font, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, position - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	pass
