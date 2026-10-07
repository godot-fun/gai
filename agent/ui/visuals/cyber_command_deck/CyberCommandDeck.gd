class_name CyberCommandDeck
extends VisualEffect

## Full-screen command interface with a central mission core and concurrent tool pods.
##
## Layout (maintainers)
## - Center: flat-top hex underlay (`draw_core_hex_underlay`) then radar; cube/labels in `draw_core`. Links use `hex_flat_half_width`.
## - Sides: up to `MAX_PODS` tool panels in a fixed 4×2 grid (`pod_rect`); slot 0 replaces oldest when full.
## - Radar: radius is precomputed for all `MAX_PODS` slots so rings never resize when tools appear.
##
## Paint order (`_draw`): backplate → decor → core hex underlay → radar → pod links → pods → core foreground → orbit → end shockwave.
##
## Pod lifecycle: CONNECTING → EXECUTING → COMPLETE/FAILED; `pending_state` applies after `MIN_EXECUTION_SECONDS`.
## Agent end: wait for pods to hold complete, then `ENDING` drives `scan_wave` / `collapse` (core shrink + fade).

const MAX_PODS := 8
## Time pod stays in CONNECTING before EXECUTING (link + panel open animation).
const CONNECT_SECONDS := 0.38
## Minimum EXECUTING duration so flashes are readable even on instant tool results.
const MIN_EXECUTION_SECONDS := 1.0
## COMPLETE/FAILED must hold this long before `on_agent_end` can finish.
const COMPLETE_HOLD_SECONDS := 0.85
## Duration of the radial `draw_completion_wave` when the session ends.
const END_SECONDS := 1.25
## Inscribed radius of the mission hex and wireframe cube anchor (scales with `collapse`).
const CORE_RADIUS := 80.0
const RADAR_VIEWPORT_RATIO := 0.48
const RADAR_MAX_RADIUS := 400.0
## Extra margin beyond pod corners when sizing radar rings.
const RADAR_POD_CLEARANCE := 28.0
## Linear decay time for `radar_echoes` after the sweep hits a pod (also drives pod afterglow).
const RADAR_ECHO_SECONDS := 1.75
## Hot contrast hue offset from the accent (keeps the magenta readouts on the cyber palette).
const ACCENT_HOT_HUE_OFFSET := 0.41
## Cool secondary hue offset from the accent (keeps the blue grid / bus tones).
const ACCENT_COOL_HUE_OFFSET := 0.09
## Stroke width for radar concentric rings.
const HUD_RING_STROKE := 1.0
## Mission hex outline — slightly below ring stroke so high-contrast accent does not read heavier than arcs.
const HUD_HEX_STROKE := 0.65

enum DeckPhase { IDLE, ACTIVE, REASONING, RESPONDING, ENDING }
enum PodState { CONNECTING, EXECUTING, COMPLETE, FAILED }

var phase: DeckPhase = DeckPhase.IDLE
var pods: Array[Dictionary] = []
var pod_by_id: Dictionary[String, Dictionary] = {}
var elapsed: float = 0.0
var radar_angle: float = 0.0
var activity: float = 0.0
var scan_wave: float = -1.0
var collapse: float = 0.0
var turn_index: int = 0
var session_id: int = 0
var next_replacement_slot: int = 0
var end_requested: bool = false
var end_error_message: String = ""
## Per-slot strength 0..1 when the radar beam crosses that pod; decays in `_process`.
var radar_echoes: Dictionary[int, float] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.CYBER_COMMAND_DECK


func fade_in_seconds() -> float:
	return 0.28


func fade_out_seconds() -> float:
	return 0.34


func reset_visual() -> void:
	phase = DeckPhase.IDLE
	pods.clear()
	pod_by_id.clear()
	elapsed = 0.0
	radar_angle = 0.0
	activity = 0.0
	scan_wave = -1.0
	collapse = 0.0
	turn_index = 0
	session_id = 0
	next_replacement_slot = 0
	end_requested = false
	end_error_message = ""
	radar_echoes.clear()
	queue_redraw()
	pass


func on_agent_start(p_session_id: int) -> void:
	session_id = p_session_id
	phase = DeckPhase.ACTIVE
	activity = 1.0
	pass


## Blocks until every pod has reached COMPLETE/FAILED and held for `COMPLETE_HOLD_SECONDS`, then runs the end wave.
func on_agent_end(error_message: String) -> void:
	end_requested = true
	end_error_message = error_message
	for pod: Dictionary in pods:
		if int(pod["state"]) < PodState.COMPLETE and int(pod["pending_state"]) < 0:
			pod["pending_state"] = PodState.FAILED if StringUtils.is_not_blank(error_message) else PodState.COMPLETE
	if not is_inside_tree():
		return
	while not all_pods_finished_holding():
		await get_tree().process_frame
	phase = DeckPhase.ENDING
	scan_wave = 0.0
	collapse = 0.0
	activity = 1.0
	while scan_wave < 1.0:
		await get_tree().process_frame
	pass


func on_turn_start() -> void:
	turn_index += 1
	phase = DeckPhase.ACTIVE
	activity = 1.0
	pass


func on_turn_end() -> void:
	if phase != DeckPhase.ENDING:
		phase = DeckPhase.ACTIVE
	pass


func on_message_update(chunk: String, stream_kind: String) -> void:
	phase = DeckPhase.REASONING if stream_kind == OpenAiClient.STREAM_KIND_REASONING else DeckPhase.RESPONDING
	activity = clampf(activity + maxf(0.12, chunk.length() * 0.008), 0.0, 1.0)
	pass


func on_message_complete(_usage: OpenAiUsage) -> void:
	activity = 1.0
	pass


## Registers or replaces a pod; replacement reuses slot index and clears stale radar echo for that slot.
func on_tool_execution_start(tool_call_id: String, tool_name: String, args: Dictionary[String, Variant]) -> void:
	var slot := pods.size()
	if pods.size() >= MAX_PODS:
		slot = next_replacement_slot
		next_replacement_slot = (next_replacement_slot + 1) % MAX_PODS
		pod_by_id.erase(String(pods[slot]["id"]))
	var pod := make_pod(tool_call_id, tool_name, args, slot)
	radar_echoes.erase(slot)
	if slot < pods.size():
		pods[slot] = pod
	else:
		pods.append(pod)
	pod_by_id[tool_call_id] = pod
	activity = 1.0
	pass


func on_tool_execution_end(tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if not pod_by_id.has(tool_call_id):
		return
	var pod: Dictionary = pod_by_id[tool_call_id]
	pod["pending_state"] = PodState.FAILED if result.is_error else PodState.COMPLETE
	activity = 1.0
	pass


func on_theme_changed() -> void:
	queue_redraw()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	# Faster sweep during reasoning; echoes and pod highlight use the same `radar_angle`.
	var radar_speed := 1.5 if phase == DeckPhase.REASONING else 0.55
	var previous_radar_angle := radar_angle
	radar_angle = fmod(radar_angle + delta * radar_speed, TAU)
	for slot: int in radar_echoes.keys():
		var echo := maxf(0.0, radar_echoes[slot] - delta / RADAR_ECHO_SECONDS)
		if echo <= 0.0:
			radar_echoes.erase(slot)
		else:
			radar_echoes[slot] = echo
	# Only open pods register hits; angle is pod center vs screen center (same as `draw_radar_echoes`).
	for pod: Dictionary in pods:
		if float(pod["open"]) < 0.75:
			continue
		var rect := pod_rect(int(pod["slot"]), pods.size(), size * 0.5)
		var target_angle := (rect.get_center() - size * 0.5).angle()
		if radar_crossed_angle(previous_radar_angle, radar_angle, target_angle):
			radar_echoes[int(pod["slot"])] = 1.0
	activity = move_toward(activity, 0.22, delta * 0.7)
	for pod: Dictionary in pods:
		pod["age"] = float(pod["age"]) + delta
		pod["open"] = move_toward(float(pod["open"]), 1.0, delta * 4.6)
		if int(pod["state"]) == PodState.CONNECTING and float(pod["age"]) >= CONNECT_SECONDS:
			pod["state"] = PodState.EXECUTING
			pod["age"] = 0.0
		elif int(pod["state"]) == PodState.EXECUTING and float(pod["age"]) >= MIN_EXECUTION_SECONDS and int(pod["pending_state"]) >= 0:
			pod["state"] = int(pod["pending_state"])
			pod["age"] = 0.0
	if phase == DeckPhase.ENDING:
		scan_wave = minf(1.0, scan_wave + delta / END_SECONDS)
		# Core shrink lags slightly so the shockwave reads before the hex collapses.
		collapse = clampf((scan_wave - 0.18) / 0.62, 0.0, 1.0)
	queue_redraw()
	pass


func _draw() -> void:
	if size.x < 280.0 or size.y < 220.0:
		return
	var center := size * 0.5
	draw_backplane(center)
	draw_data_rain(center)
	draw_ambient_energy(center)
	draw_edge_telemetry(center)
	draw_core_hex_underlay(center)
	draw_radar(center)
	draw_live_telemetry(center)
	for index in range(pods.size()):
		draw_pod_link(pods[index], pod_rect(index, pods.size(), center), center)
	for index in range(pods.size()):
		draw_tool_pod(pods[index], pod_rect(index, pods.size(), center), center)
	# Foreground core (cube, labels) above links; hex fill/outline already in `draw_core_hex_underlay`.
	draw_core(center)
	draw_orbit_packets(center)
	if scan_wave >= 0.0:
		draw_completion_wave(center)
	pass


func draw_live_telemetry(center: Vector2) -> void:
	var radius := radar_radius(center)
	# Radar contacts come alive during reasoning and settle while responding.
	var contact_count := 9 if phase == DeckPhase.REASONING else 5
	for index in range(contact_count):
		var seed := float(index * 41 + 17)
		var angle := seed + elapsed * (0.08 + float(index % 3) * 0.035)
		var distance := radius * (0.38 + fmod(seed * 0.173, 0.58))
		var position := center + Vector2.from_angle(angle) * distance
		var blink := 0.35 + 0.65 * absf(sin(elapsed * (1.8 + index * 0.13) + seed))
		var color := neon_magenta() if index % 4 == 0 else neon_cyan()
		draw_circle(position, 7.0 + blink * 3.0, Color(color, 0.025 * blink))
		draw_circle(position, 1.8, Color(color, 0.55 * blink))
		draw_line(position - Vector2(5.0, 0.0), position - Vector2(10.0, 0.0), Color(color, 0.35 * blink), 1.0)
		draw_line(position + Vector2(5.0, 0.0), position + Vector2(10.0, 0.0), Color(color, 0.35 * blink), 1.0)
	# Four rotating readout labels make the radar feel instrumented.
	for index in range(4):
		var angle := elapsed * -0.12 + float(index) * TAU / 4.0
		var position := center + Vector2.from_angle(angle) * (radius + 37.0)
		var label := "%02X:%03d" % [index * 19 + turn_index, int(fmod(elapsed * 37.0 + index * 113.0, 999.0))]
		draw_string(Fonts.regular(), position, label, HORIZONTAL_ALIGNMENT_LEFT, 70.0, Typography.label_small_size, Color(neon_cyan(), 0.38))
	pass


func draw_orbit_packets(center: Vector2) -> void:
	# Keep the orbital hardware independent from short-lived tool/phase changes so its
	# spacing never pops when a fast tool starts or finishes.
	var orbit_count := 14
	var signal_strength := 0.58 + activity * 0.2
	for index in range(orbit_count):
		var lane := index % 3
		var radius := CORE_RADIUS + 72.0 + lane * 25.0
		var speed := 0.44 + lane * 0.17
		var angle := elapsed * speed * (-1.0 if lane == 1 else 1.0) + float(index) * TAU / float(orbit_count)
		var position := center + Vector2.from_angle(angle) * radius
		var tangent := Vector2.from_angle(angle + PI * 0.5)
		var color := neon_magenta() if index % 6 == 0 else neon_cyan()
		draw_line(position - tangent * 7.0, position + tangent * 7.0, Color(color, signal_strength), 2.0, true)
		if index % 3 == 0:
			draw_circle(position, 4.5, Color(color, 0.07 + activity * 0.025))
	pass


func draw_ambient_energy(center: Vector2) -> void:
	# A restrained horizontal flare keeps focus on the core without splitting the screen.
	for layer in range(8, 0, -1):
		var flare_width := size.x * (0.12 + layer * 0.045)
		var flare_height := 3.0 + layer * 4.0
		draw_rect(Rect2(center - Vector2(flare_width * 0.5, flare_height * 0.5), Vector2(flare_width, flare_height)), Color(neon_cyan(), 0.008 * float(9 - layer)), true)
	pass


func draw_edge_telemetry(center: Vector2) -> void:
	var rail_top := 104.0
	var rail_bottom := size.y - 92.0
	var rail_inset := 32.0
	for side: float in [-1.0, 1.0]:
		var x := rail_inset if side < 0.0 else size.x - rail_inset
		var inward := -side
		draw_line(Vector2(x, rail_top), Vector2(x, rail_bottom), Color(neon_blue(), 0.16), 1.0)
		for index in range(7):
			var y := lerpf(rail_top, rail_bottom, float(index) / 6.0)
			var hot := index == (int(elapsed * 2.0) + (0 if side < 0.0 else 3)) % 7
			var color := neon_magenta() if hot else neon_cyan()
			var length := 24.0 if index % 3 == 0 else 13.0
			draw_line(Vector2(x, y), Vector2(x + inward * length, y), Color(color, 0.78 if hot else 0.28), 2.0 if hot else 1.0)
			if index % 2 == 0:
				var code := "%02X" % int(fmod(index * 29.0 + elapsed * 7.0 + turn_index, 255.0))
				var text_x := x + inward * (length + 7.0) - (28.0 if side < 0.0 else 0.0)
				draw_string(Fonts.regular(), Vector2(text_x, y - 4.0), code, HORIZONTAL_ALIGNMENT_LEFT, 28.0, Typography.label_small_size, Color(color, 0.34))
	# Phase marker deliberately sits off-axis like a cockpit warning label.
	var phase_text: String = String(DeckPhase.keys()[phase])
	draw_string(Fonts.semibold(), Vector2(rail_inset + 13.0, center.y - 9.0), "[ %s ]" % phase_text, HORIZONTAL_ALIGNMENT_LEFT, 110.0, Typography.label_small_size, Color(neon_magenta(), 0.72))
	draw_string(Fonts.regular(), Vector2(size.x - rail_inset - 132.0, center.y - 9.0), StringUtils.format(I18n.t("agent.visuals.activity"), "%03d" % int(activity * 100.0)), HORIZONTAL_ALIGNMENT_RIGHT, 118.0, Typography.label_small_size, Color(neon_cyan(), 0.68))
	pass


func draw_data_rain(center: Vector2) -> void:
	var horizon := center.y + minf(size.y * 0.16, 150.0)
	# Sparse deterministic columns imply a distant neon megacity without obscuring content.
	for index in range(42):
		var lane_x := fmod(float(index * 149 + 31), maxf(size.x, 1.0))
		var speed := 18.0 + float(index % 7) * 8.0
		var y := fmod(float(index * 83) + elapsed * speed, maxf(horizon - 54.0, 1.0)) + 54.0
		var column_height := 12.0 + float(index % 5) * 9.0
		var color := neon_magenta() if index % 9 == 0 else neon_cyan()
		var alpha := 0.055 + float(index % 4) * 0.014
		draw_line(Vector2(lane_x, y - column_height), Vector2(lane_x, y), Color(color, alpha), 1.0)
		draw_rect(Rect2(Vector2(lane_x - 1.0, y), Vector2(3.0, 2.0)), Color(color, alpha * 2.2), true)
	# Low skyline blocks — same fake bounce as bottom chrome (base height + sine kick).
	for index in range(30):
		var block_width := 18.0 + float((index * 7) % 23)
		var x := float(index) * size.x / 29.0 - block_width * 0.5
		var base_height := 8.0 + float((index * 17) % 52)
		var bounce := absf(sin(elapsed * 7.6 + float(index) * 0.91)) * 22.0 + absf(sin(elapsed * 12.3 + float(index) * 1.27)) * 12.0
		var block_height := base_height + bounce
		draw_rect(Rect2(Vector2(x, horizon - block_height), Vector2(block_width, block_height)), Color(neon_blue(), 0.04 + float(index % 3) * 0.012), true)
		if index % 3 == 0:
			draw_line(Vector2(x + block_width * 0.5, horizon - block_height), Vector2(x + block_width * 0.5, horizon - block_height - 11.0), Color(neon_magenta(), 0.13), 1.0)
	pass


func draw_backplane(center: Vector2) -> void:
	# The deck is an overlay, so do not tint the entire desktop surface. The previous
	# translucent black wash visually softened the UI underneath like a blur layer.
	# Horizon and perspective floor turn the overlay into a room rather than graph paper.
	var horizon := center.y + minf(size.y * 0.16, 150.0)
	for ray in range(-12, 13):
		var bottom_x := center.x + float(ray) * size.x / 12.0
		draw_line(Vector2(center.x, horizon), Vector2(bottom_x, size.y), Color(neon_blue(), 0.055), 1.0)
	for band in range(11):
		var amount := float(band) / 10.0
		var curved := amount * amount
		var y := lerpf(horizon, size.y, curved)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(neon_cyan(), 0.045 + amount * 0.035), 1.0)
	# Upper technical grid and major axes.
	var grid_step := 64.0
	var drift := fmod(elapsed * 5.0, grid_step)
	for x in range(-1, int(size.x / grid_step) + 2):
		var px := float(x) * grid_step + drift
		draw_line(Vector2(px, 0.0), Vector2(px, horizon), Color(neon_blue(), 0.025), 1.0)
	for y in range(0, int(horizon / grid_step) + 1):
		draw_line(Vector2(0.0, y * grid_step), Vector2(size.x, y * grid_step), Color(neon_blue(), 0.025), 1.0)
	draw_line(Vector2(center.x, 0.0), Vector2(center.x, size.y), Color(neon_magenta(), 0.08), 1.0)
	pass


## Concentric rings, sweep wedge, targeting arc, and pod echo ticks (`draw_radar_echoes`).
func draw_radar(center: Vector2) -> void:
	var radius := radar_radius(center)
	for ring in range(1, 5):
		var ring_color := neon_cyan() if ring % 2 else neon_blue()
		draw_arc(center, radius * float(ring) / 4.0, 0.0, TAU, 72, Color(ring_color, 0.1), HUD_RING_STROKE, true)
		for tick in range(24):
			var tick_angle := float(tick) * TAU / 24.0
			var tick_radius := radius * float(ring) / 4.0
			var tick_length := 6.0 if tick % 3 == 0 else 3.0
			draw_line(center + Vector2.from_angle(tick_angle) * tick_radius, center + Vector2.from_angle(tick_angle) * (tick_radius + tick_length), Color(neon_cyan(), 0.22), 1.0)
	draw_radar_echoes(center, radius)
	var angle := radar_angle
	for slice in range(7):
		var slice_angle := angle - float(slice) * 0.055
		var sweep := PackedVector2Array([center, center + Vector2.from_angle(slice_angle - 0.055) * radius, center + Vector2.from_angle(slice_angle) * radius])
		draw_colored_polygon(sweep, Color(neon_cyan(), (0.015 + activity * 0.012) * float(7 - slice)))
	draw_line(center, center + Vector2.from_angle(angle) * radius, Color(neon_cyan(), 0.9), 2.0, true)
	# A counter-rotating magenta targeting arc keeps the palette from reading monochrome.
	var target_angle := -elapsed * 0.34
	draw_arc(center, radius + 13.0, target_angle, target_angle + 0.62, 24, Color(neon_magenta(), 0.72), 3.0, true)
	draw_circle(center + Vector2.from_angle(target_angle + 0.62) * (radius + 13.0), 3.0, Color(neon_magenta(), 0.95))
	pass


## Hex fill, facet tint, and outline — drawn before `draw_radar` so the sweep reads through the core.
func draw_core_hex_underlay(center: Vector2) -> void:
	var core_scale := 1.0 - collapse * 0.82
	var radius := CORE_RADIUS * core_scale
	var visibility := 1.0 - collapse
	var core_hex := polygon_points(center, radius, 6, PI / 6.0)
	draw_colored_polygon(core_hex, Color(ColorBase.deep_surface, 0.96))
	for index in range(6):
		var facet := PackedVector2Array([center, core_hex[index], core_hex[(index + 1) % 6]])
		draw_colored_polygon(facet, Color(neon_blue() if index % 2 else neon_cyan(), 0.018 + index * 0.005))
	draw_hex_outline(core_hex, Color(neon_cyan(), 0.94 * visibility), HUD_HEX_STROKE)
	pass


## Bus rings, cube, and labels above radar/links. Hex frame is `draw_core_hex_underlay`.
func draw_core(center: Vector2) -> void:
	var core_scale := 1.0 - collapse * 0.82
	var radius := CORE_RADIUS * core_scale
	var pulse := (sin(elapsed * 4.0) + 1.0) * 0.5
	var visibility := 1.0 - collapse
	# A restrained two-stage bus replaces the previous stack of competing rings.
	for ring in range(2):
		var bus_radius := radius + 58.0 + ring * 23.0
		var rotation := elapsed * (0.18 + ring * 0.07) * (-1.0 if ring == 1 else 1.0)
		for segment in range(6):
			var start := rotation + float(segment) * TAU / 6.0
			var span := 0.34 if ring == 0 else 0.21
			var ring_color := neon_magenta() if ring == 1 and segment % 3 == 0 else neon_cyan()
			draw_arc(center, bus_radius, start, start + span, 10, Color(ring_color, (0.22 + pulse * 0.07) * visibility), 1.8 if ring == 0 else 1.2, true)
	# Eight compact data blocks form a coherent status ring.
	for block in range(8):
		var angle := -elapsed * 0.12 + float(block) * TAU / 8.0
		var block_radius := radius + 38.0
		var position := center + Vector2.from_angle(angle) * block_radius
		var tangent := Vector2.from_angle(angle + PI * 0.5)
		var block_color := neon_magenta() if block % 4 == 0 else neon_cyan()
		draw_line(position - tangent * 8.0, position + tangent * 8.0, Color(block_color, (0.5 + pulse * 0.22) * visibility), 3.0, true)
	# Soft reactor bloom stays behind one stable frame instead of several rotating polygons.
	for glow in range(7, 0, -1):
		draw_circle(center, radius + glow * 9.0 + pulse * 3.0, Color(neon_cyan(), 0.006 * float(8 - glow) * visibility))
	var energy_center := center
	draw_circle(energy_center, 15.0 + pulse * 5.0, Color(neon_cyan(), 0.07 * visibility))
	draw_energy_cube(energy_center, 8.5 + pulse * 1.8, visibility)
	if collapse < 0.86:
		# Flat-top hex left/right vertical edges end at ±radius*0.5; status baseline sits on that bottom line.
		const CORE_LABEL_GAP := 30.0
		var status_font := Fonts.medium()
		var status_size := Typography.label_small_size
		draw_centered_text(center - Vector2(0.0, CORE_LABEL_GAP), I18n.t("agent.visuals.core"), Fonts.bold(), Typography.title_small_size, Color(neon_cyan(), 0.98))
		draw_centered_text(center + Vector2(0.0, radius * 0.5), core_status(), status_font, status_size, Color(neon_magenta(), 0.9))
	pass


func draw_energy_cube(energy_center: Vector2, half: float, visibility: float) -> void:
	# Orthographic yaw/pitch wireframe cube — edges only, no filled faces.
	var xform := Basis.from_euler(Vector3(0.55, elapsed * 0.7, 0.0))
	var corners := PackedVector2Array()
	for index in range(8):
		var local := Vector3(-1.0 if index & 1 else 1.0, -1.0 if index & 2 else 1.0, -1.0 if index & 4 else 1.0)
		var rotated: Vector3 = xform * local
		corners.append(energy_center + Vector2(rotated.x, rotated.y) * half)
	var edges: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 3), Vector2i(3, 2), Vector2i(2, 0),
		Vector2i(4, 5), Vector2i(5, 7), Vector2i(7, 6), Vector2i(6, 4),
		Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7),
	]
	const EDGE_WIDTH := 1.15
	const EDGE_INSET := 0.55
	var accent := neon_cyan()
	for edge: Vector2i in edges:
		var from := corners[edge.x]
		var to := corners[edge.y]
		var delta := to - from
		var length := delta.length()
		if length <= EDGE_INSET * 2.0:
			continue
		var dir := delta / length
		draw_line(from + dir * EDGE_INSET, to - dir * EDGE_INSET, Color(accent, 0.92 * visibility), EDGE_WIDTH, true)
	pass


## Orthogonal path from pod inner edge to mission hex flat side (must stay in sync with `draw_core` radius/rotation).
func draw_pod_link(pod: Dictionary, rect: Rect2, center: Vector2) -> void:
	var open_amount := float(pod["open"]) * (1.0 - collapse)
	if open_amount <= 0.01:
		return
	var left_side := rect.get_center().x < center.x
	var target := Vector2(rect.end.x if left_side else rect.position.x, rect.get_center().y)
	var core_radius := CORE_RADIUS * (1.0 - collapse * 0.82)
	var attach_x := hex_flat_half_width(core_radius)
	# Slight vertical bias keeps long horizontal segments visually centered on the core.
	var start := center + Vector2(-attach_x if left_side else attach_x, (target.y - center.y) * 0.18)
	var elbow := Vector2(lerpf(start.x, target.x, 0.58), target.y)
	var state: int = pod["state"]
	var color := pod_color(state)
	var path := PackedVector2Array([start, Vector2(elbow.x, start.y), elbow, target])
	draw_polyline(path, Color(color, 0.08 * open_amount), 8.0, true)
	draw_polyline(path, Color(color, 0.52 * open_amount), 1.2, true)
	if state <= PodState.EXECUTING:
		var packet := fmod(elapsed * 0.72 + float(pod["slot"]) * 0.13, 1.0)
		var segment := mini(int(packet * 3.0), 2)
		var local := fmod(packet * 3.0, 1.0)
		var position := path[segment].lerp(path[segment + 1], local)
		draw_circle(position, 6.0, Color(color, 0.1))
		draw_circle(position, 2.4, Color(color, 0.95))
		var return_packet := 1.0 - fmod(elapsed * 0.48 + float(pod["slot"]) * 0.19, 1.0)
		var return_segment := mini(int(return_packet * 3.0), 2)
		var return_local := fmod(return_packet * 3.0, 1.0)
		var return_position := path[return_segment].lerp(path[return_segment + 1], return_local)
		draw_rect(Rect2(return_position - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(neon_magenta(), 0.8), true)
	pass


## Tool panel chrome. In-pod decor: energy bars (non-EXECUTING), waveform + activity overlays (`draw_pod_activity`), radar scan tint.
func draw_tool_pod(pod: Dictionary, rect: Rect2, center: Vector2) -> void:
	var open_amount := float(pod["open"]) * (1.0 - collapse)
	if open_amount <= 0.01:
		return
	var state: int = pod["state"]
	var color := pod_color(state)
	var shown := Rect2(rect.position + Vector2(rect.size.x * (1.0 - open_amount) * 0.5, rect.size.y * (1.0 - open_amount) * 0.5), rect.size * open_amount)
	var cut := minf(15.0, shown.size.x * 0.1)
	var panel := PackedVector2Array([
		shown.position + Vector2(cut, 0.0), shown.position + Vector2(shown.size.x, 0.0),
		shown.end - Vector2(0.0, cut), shown.end - Vector2(cut, 0.0),
		shown.position + Vector2(0.0, shown.size.y), shown.position + Vector2(0.0, cut),
	])
	var shadow := PackedVector2Array()
	for point: Vector2 in panel:
		shadow.append(point + Vector2(8.0, 8.0))
	draw_colored_polygon(shadow, Color(color, 0.055))
	draw_polyline(PackedVector2Array([shadow[0], shadow[1], shadow[2], shadow[3]]), Color(color, 0.16), 4.0, true)
	var is_executing := state == PodState.EXECUTING
	var active_breath := 0.5 + 0.5 * sin(elapsed * 5.2 + float(pod["slot"]))
	# Live beam width × `radar_pod_feedback`; echo adds sustained highlight (0.55 scales decay tail on the panel).
	var radar_feedback := maxf(radar_pod_feedback(shown, center), float(radar_echoes.get(int(pod["slot"]), 0.0)) * 0.55) * open_amount
	if is_executing:
		for glow in range(4, 0, -1):
			draw_polyline(outset_polyline(panel, float(glow) * 3.0), Color(color, (0.018 + active_breath * 0.012) * float(5 - glow)), 4.0, true)
	draw_colored_polygon(panel, Color(color, 0.075 + active_breath * 0.025) if is_executing else Color(ColorBase.deep_surface, 0.94))
	if radar_feedback > 0.0:
		draw_colored_polygon(panel, Color(color, radar_feedback * 0.13))
		var scan_x := lerpf(shown.position.x, shown.end.x, radar_feedback)
		draw_rect(Rect2(Vector2(scan_x - 13.0, shown.position.y + 3.0), Vector2(26.0, shown.size.y - 6.0)), Color(color, radar_feedback * 0.12), true)
		for glow in range(4, 0, -1):
			draw_polyline(outset_polyline(panel, float(glow) * 3.5), Color(color, radar_feedback * 0.055 * float(5 - glow)), 4.0, true)
	var outline := PackedVector2Array(panel)
	outline.append(panel[0])
	draw_polyline(outline, Color(color, 0.2 if is_executing else 0.12), 9.0 if is_executing else 7.0, true)
	draw_polyline(outline, Color(color, 0.98 if is_executing else 0.8), 2.2 if is_executing else 1.4, true)
	draw_line(shown.position + Vector2(cut + 8.0, 0.0), shown.position + Vector2(shown.size.x * 0.84, 0.0), Color(color, 0.98), 3.0)
	var title := VisualToolFormatter.title_name(String(pod["name"]))
	var glyph := VisualToolFormatter.glyph(String(pod["name"]))
	draw_rect(Rect2(shown.position + Vector2(15.0, 17.0), Vector2(34.0, 34.0)), Color(color, 0.08), true)
	draw_rect(Rect2(shown.position + Vector2(15.0, 17.0), Vector2(34.0, 34.0)), Color(color, 0.58), false, 1.0)
	draw_centered_text(shown.position + Vector2(32.0, 40.0), glyph, Fonts.bold(), Typography.label_medium_size, color)
	draw_string(Fonts.semibold(), shown.position + Vector2(59.0, 27.0), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, shown.size.x - 80.0, Typography.label_medium_size, ColorBase.primary_text)
	draw_string(Fonts.medium(), shown.position + Vector2(59.0, 49.0), "// " + pod_status(state), HORIZONTAL_ALIGNMENT_LEFT, shown.size.x - 80.0, Typography.label_small_size, color)
	draw_string(Fonts.regular(), shown.position + Vector2(shown.size.x - 62.0, 49.0), "%02d" % int(pod["slot"]), HORIZONTAL_ALIGNMENT_RIGHT, 45.0, Typography.label_small_size, Color(color, 0.7))
	if is_executing:
		var live_rect := Rect2(shown.position + Vector2(shown.size.x - 62.0, 8.0), Vector2(46.0, 15.0))
		draw_rect(live_rect, Color(color, 0.12 + active_breath * 0.08), true)
		draw_rect(live_rect, Color(color, 0.8), false, 1.0)
		draw_string(Fonts.bold(), live_rect.position + Vector2(8.0, 11.0), I18n.t("agent.visuals.live"), HORIZONTAL_ALIGNMENT_LEFT, 34.0, Typography.label_small_size, Color(color, 0.95))
	# Upper-right energy columns — idle/complete pods only; EXECUTING uses LIVE badge instead.
	if not is_executing:
		for bar in range(5):
			var bar_height := 3.0 + absf(sin(elapsed * 5.0 + bar * 1.7 + int(pod["slot"]))) * 8.0
			var bar_x := shown.end.x - 58.0 + bar * 7.0
			draw_rect(Rect2(Vector2(bar_x, shown.position.y + 19.0 + 10.0 - bar_height), Vector2(3.0, bar_height)), Color(color, 0.55), true)
	draw_pod_activity(pod, shown, color)
	var progress := fmod(elapsed * 0.9 + float(pod["slot"]) * 0.17, 1.0)
	if state <= PodState.EXECUTING:
		draw_rect(Rect2(shown.position + Vector2(16.0, shown.size.y - 12.0), Vector2(shown.size.x - 32.0, 2.0)), Color(color, 0.14), true)
		draw_rect(Rect2(shown.position + Vector2(16.0, shown.size.y - 12.0), Vector2((shown.size.x - 32.0) * progress, 2.0)), Color(color, 0.95), true)
	pass


## State-specific motion inside the pod: connect sweep, execute scan/chevrons, shared waveform, complete pulse ring.
func draw_pod_activity(pod: Dictionary, rect: Rect2, color: Color) -> void:
	var state: int = pod["state"]
	var age: float = pod["age"]
	if state == PodState.CONNECTING:
		var sweep_x := rect.position.x + fmod(age / CONNECT_SECONDS, 1.0) * rect.size.x
		draw_rect(Rect2(Vector2(sweep_x - 10.0, rect.position.y + 3.0), Vector2(20.0, rect.size.y - 6.0)), Color(neon_magenta(), 0.045), true)
		for dot in range(3):
			var dot_alpha := 0.25 + 0.75 * absf(sin(elapsed * 5.0 + dot * 1.6))
			draw_circle(rect.position + Vector2(62.0 + dot * 9.0, rect.size.y - 11.0), 1.8, Color(neon_magenta(), dot_alpha))
		return
	if state == PodState.EXECUTING:
		var scan_x := rect.position.x + fmod(elapsed * 0.72 + float(pod["slot"]) * 0.11, 1.0) * rect.size.x
		draw_rect(Rect2(Vector2(scan_x - 16.0, rect.position.y + 3.0), Vector2(32.0, rect.size.y - 6.0)), Color(neon_cyan(), 0.055), true)
		for chevron in range(3):
			var chevron_x := rect.position.x + 58.0 + chevron * 10.0
			var chevron_y := rect.end.y - 10.0
			draw_polyline(PackedVector2Array([Vector2(chevron_x, chevron_y - 3.0), Vector2(chevron_x + 4.0, chevron_y), Vector2(chevron_x, chevron_y + 3.0)]), Color(neon_cyan(), 0.4 + chevron * 0.18), 1.3, true)
	if state >= PodState.EXECUTING:
		draw_pod_waveform(pod, rect, color)
	if state >= PodState.COMPLETE and age < 0.7:
		var pulse := age / 0.7
		var pulse_rect := rect.grow(10.0 * pulse)
		draw_polyline(closed_cut_panel(pulse_rect), Color(color, (1.0 - pulse) * 0.65), 2.0, true)
	pass


## Lower-right sine trace; kept for EXECUTING and after (COMPLETE/FAILED) — independent of energy bars above.
func draw_pod_waveform(pod: Dictionary, rect: Rect2, color: Color) -> void:
	var graph := PackedVector2Array()
	var graph_left := rect.position.x + rect.size.x * 0.58
	var graph_width := rect.size.x * 0.28
	for point in range(13):
		var amount := float(point) / 12.0
		var value := sin(elapsed * 5.4 + amount * 13.0 + int(pod["slot"])) * 5.0 + sin(elapsed * 2.1 + amount * 27.0) * 2.0
		graph.append(Vector2(graph_left + amount * graph_width, rect.position.y + rect.size.y - 23.0 + value))
	draw_polyline(graph, Color(color, 0.2), 5.0, true)
	draw_polyline(graph, Color(color, 0.9), 1.2, true)
	pass


## Expanding rings when `phase == ENDING`; opacity tied to `scan_wave`, not the tool radar.
func draw_completion_wave(center: Vector2) -> void:
	var max_radius := size.length() * 0.58
	var radius := scan_wave * max_radius
	draw_arc(center, radius, 0.0, TAU, 128, Color(neon_cyan(), (1.0 - scan_wave) * 0.95), 5.0, true)
	draw_arc(center, maxf(0.0, radius - 18.0), 0.0, TAU, 128, Color(neon_blue(), (1.0 - scan_wave) * 0.3), 15.0, true)
	draw_arc(center, maxf(0.0, radius - 34.0), 0.0, TAU, 128, Color(neon_magenta(), (1.0 - scan_wave) * 0.48), 2.0, true)
	pass


## Fixed grid: even index = left column, odd = right; row = index / 2. Used for layout, links, and radar targeting.
func pod_rect(index: int, _count: int, center: Vector2) -> Rect2:
	var width := clampf(size.x * 0.17, 170.0, 260.0)
	var height := 78.0
	var side := -1.0 if index % 2 == 0 else 1.0
	var row := index / 2
	var y_offset := (float(row) - 1.5) * (height + 22.0)
	var x := center.x + side * (minf(size.x * 0.31, 390.0) + width * 0.5) - width * 0.5
	return Rect2(Vector2(x, center.y + y_offset - height * 0.5), Vector2(width, height))


func radar_radius(center: Vector2) -> float:
	var radius := minf(size.y * RADAR_VIEWPORT_RATIO, RADAR_MAX_RADIUS)
	# Reserve the full command envelope from the first frame so the radar never jumps
	# outward as tool pods are added during startup.
	for index in range(MAX_PODS):
		var rect := pod_rect(index, MAX_PODS, center)
		var corners := PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
		for corner: Vector2 in corners:
			radius = maxf(radius, center.distance_to(corner) + RADAR_POD_CLEARANCE)
	return radius


## 0..1 while the radar spoke aims near this pod; wider span (×1.45, floor 0.12 rad) lengthens the visible hit window.
func radar_pod_feedback(rect: Rect2, center: Vector2) -> float:
	var direction := rect.get_center() - center
	var angle_delta := absf(wrapf(radar_angle - direction.angle() + PI, 0.0, TAU) - PI)
	var angular_span := atan2(rect.size.y * 0.72, maxf(direction.length(), 1.0))
	return clampf(1.0 - angle_delta / maxf(angular_span * 1.45, 0.12), 0.0, 1.0)


## Tick marks on the radar ring at each echoing pod bearing (strength follows `radar_echoes` decay).
func draw_radar_echoes(center: Vector2, radius: float) -> void:
	for pod: Dictionary in pods:
		var strength := float(radar_echoes.get(int(pod["slot"]), 0.0))
		if strength <= 0.0:
			continue
		var rect := pod_rect(int(pod["slot"]), pods.size(), center)
		var angle := (rect.get_center() - center).angle()
		var echo_radius := radius - 10.0
		var marker := center + Vector2.from_angle(angle) * echo_radius
		var direction := Vector2.from_angle(angle)
		var tangent := direction.rotated(PI * 0.5)
		draw_arc(center, echo_radius, angle - 0.055, angle + 0.055, 12, Color(neon_cyan(), strength * 0.75), 1.2, true)
		draw_arc(center, echo_radius - 8.0, angle - 0.032, angle + 0.032, 10, Color(neon_cyan(), strength * 0.28), 1.0, true)
		draw_polyline(PackedVector2Array([
			marker - direction * 4.0,
			marker + tangent * 4.0,
			marker + direction * 4.0,
			marker - tangent * 4.0,
			marker - direction * 4.0,
		]), Color(neon_cyan(), strength * 0.9), 1.0, true)
		draw_line(marker - tangent * 8.0, marker - tangent * 5.0, Color(neon_cyan(), strength * 0.55), 1.0)
		draw_line(marker + tangent * 5.0, marker + tangent * 8.0, Color(neon_cyan(), strength * 0.55), 1.0)
	pass


## True when `target_angle` lies on the forward sweep arc from `previous_angle` to `current_angle` (handles wrap).
static func radar_crossed_angle(previous_angle: float, current_angle: float, target_angle: float) -> bool:
	var swept := fposmod(current_angle - previous_angle, TAU)
	var target_offset := fposmod(target_angle - previous_angle, TAU)
	return target_offset <= swept


func active_pod_count() -> int:
	var count := 0
	for pod: Dictionary in pods:
		if int(pod["state"]) <= PodState.EXECUTING:
			count += 1
	return count


func core_status() -> String:
	match phase:
		DeckPhase.REASONING:
			return I18n.t("agent.visuals.radar_analysis")
		DeckPhase.RESPONDING:
			return I18n.t("agent.visuals.synthesizing")
		DeckPhase.ENDING:
			return I18n.t("agent.visuals.mission_complete")
	return I18n.t("agent.visuals.system_online")


static func pod_status(state: int) -> String:
	match state:
		PodState.CONNECTING:
			return I18n.t("agent.visuals.connecting")
		PodState.EXECUTING:
			return I18n.t("agent.visuals.executing")
		PodState.COMPLETE:
			return I18n.t("agent.visuals.complete")
	return I18n.t("agent.visuals.failed")


static func pod_color(state: int) -> Color:
	match state:
		PodState.COMPLETE:
			return ColorBase.success
		PodState.FAILED:
			return ColorBase.error
		PodState.CONNECTING:
			return neon_magenta()
	return neon_cyan()


## Primary neon tone — follows the user accent.
static func neon_cyan() -> Color:
	return ThemeColor.accent_theme_color()


## Cool secondary tone derived from the accent hue.
static func neon_blue() -> Color:
	return accent_shifted(ACCENT_COOL_HUE_OFFSET)


## Hot contrast tone derived from the accent hue.
static func neon_magenta() -> Color:
	return accent_shifted(ACCENT_HOT_HUE_OFFSET, 1.05)


static func accent_shifted(hue_offset: float, sat_mul: float = 1.0, val_mul: float = 1.0) -> Color:
	var base := ThemeColor.accent_theme_color()
	return Color.from_hsv(fposmod(base.h + hue_offset, 1.0), clampf(base.s * sat_mul, 0.0, 1.0), clampf(maxf(base.v, 0.72) * val_mul, 0.0, 1.0))


## `pending_state`: -1 until tool returns; then COMPLETE/FAILED applied after min execute time. `open`: panel reveal 0..1.
static func make_pod(tool_call_id: String, tool_name: String, args: Dictionary[String, Variant], slot: int) -> Dictionary:
	return {"id": tool_call_id, "name": tool_name, "arg_count": args.size(), "slot": slot, "state": PodState.CONNECTING, "pending_state": -1, "age": 0.0, "open": 0.0}


func all_pods_finished_holding() -> bool:
	for pod: Dictionary in pods:
		if int(pod["state"]) < PodState.COMPLETE or float(pod["age"]) < COMPLETE_HOLD_SECONDS:
			return false
	return true


## Horizontal distance from center to the flat vertical edge of a PI/6 hex — shared by `draw_core` and `draw_pod_link`.
static func hex_flat_half_width(radius: float) -> float:
	return radius * cos(PI / 6.0)


static func polygon_points(center: Vector2, radius: float, sides: int, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(sides):
		points.append(center + Vector2.from_angle(rotation + float(index) * TAU / float(sides)) * radius)
	return points


static func closed_cut_panel(rect: Rect2) -> PackedVector2Array:
	var cut := minf(15.0, rect.size.x * 0.1)
	return PackedVector2Array([
		rect.position + Vector2(cut, 0.0), rect.position + Vector2(rect.size.x, 0.0),
		rect.end - Vector2(0.0, cut), rect.end - Vector2(cut, 0.0),
		rect.position + Vector2(0.0, rect.size.y), rect.position + Vector2(0.0, cut),
		rect.position + Vector2(cut, 0.0),
	])


static func outset_polyline(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for point: Vector2 in points:
		center += point
	center /= float(points.size())
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(point + (point - center).normalized() * amount)
	result.append(result[0])
	return result


func draw_closed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, color, width, true)
	pass


## Six separate edges avoid closed-polyline corner caps looking heavier than `draw_arc` rings.
func draw_hex_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	for index in range(points.size()):
		draw_line(points[index], points[(index + 1) % points.size()], color, width, true)
	pass
