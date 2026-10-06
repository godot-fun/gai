class_name CyberCommandDeck
extends VisualEffect

## Full-screen command interface with a central mission core and concurrent tool pods.

const MAX_PODS := 8
const CONNECT_SECONDS := 0.38
const MIN_EXECUTION_SECONDS := 1.0
const COMPLETE_HOLD_SECONDS := 0.85
const END_SECONDS := 1.25
const CORE_RADIUS := 76.0
const NEON_CYAN := Color("#00f5d4")
const NEON_BLUE := Color("#16a8ff")
const NEON_MAGENTA := Color("#ff2bd6")
const DECK_VOID := Color("#050812")

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
var fade_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.CYBER_COMMAND_DECK


func set_visual_visible(show: bool, animated: bool) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	if show:
		visible = true
		modulate.a = 0.0 if animated else 1.0
		if animated:
			fade_tween = create_tween()
			fade_tween.tween_property(self, "modulate:a", 1.0, 0.28)
		return
	if not animated:
		visible = false
		modulate.a = 1.0
		return
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.34)
	fade_tween.tween_callback(func() -> void: visible = false; modulate.a = 1.0)
	pass


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
	queue_redraw()
	pass


func on_agent_start(p_session_id: int) -> void:
	session_id = p_session_id
	phase = DeckPhase.ACTIVE
	activity = 1.0
	pass


func on_agent_end(error_message: String) -> float:
	end_requested = true
	end_error_message = error_message
	for pod: Dictionary in pods:
		if int(pod["state"]) < PodState.COMPLETE and int(pod["pending_state"]) < 0:
			pod["pending_state"] = PodState.FAILED if StringUtils.is_not_blank(error_message) else PodState.COMPLETE
	return 0.0


func wait_for_agent_end() -> void:
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


func on_tool_execution_start(tool_call_id: String, tool_name: String, args: Dictionary[String, Variant]) -> void:
	var slot := pods.size()
	if pods.size() >= MAX_PODS:
		slot = next_replacement_slot
		next_replacement_slot = (next_replacement_slot + 1) % MAX_PODS
		pod_by_id.erase(String(pods[slot]["id"]))
	var pod := make_pod(tool_call_id, tool_name, args, slot)
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
	var radar_speed := 1.5 if phase == DeckPhase.REASONING else 0.55
	radar_angle = fmod(radar_angle + delta * radar_speed, TAU)
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
	draw_screen_fx()
	draw_system_chrome(center)
	draw_edge_telemetry(center)
	draw_radar(center)
	draw_live_telemetry(center)
	draw_waveforms(center)
	for index in range(pods.size()):
		draw_pod_link(pods[index], pod_rect(index, pods.size(), center), center)
	for index in range(pods.size()):
		draw_tool_pod(pods[index], pod_rect(index, pods.size(), center))
	draw_core(center)
	draw_orbit_packets(center)
	if scan_wave >= 0.0:
		draw_completion_wave(center)
	pass


func draw_live_telemetry(center: Vector2) -> void:
	var radius := minf(size.y * 0.35, 270.0)
	# Radar contacts come alive during reasoning and settle while responding.
	var contact_count := 9 if phase == DeckPhase.REASONING else 5
	for index in range(contact_count):
		var seed := float(index * 41 + 17)
		var angle := seed + elapsed * (0.08 + float(index % 3) * 0.035)
		var distance := radius * (0.38 + fmod(seed * 0.173, 0.58))
		var position := center + Vector2.from_angle(angle) * distance
		var blink := 0.35 + 0.65 * absf(sin(elapsed * (1.8 + index * 0.13) + seed))
		var color := NEON_MAGENTA if index % 4 == 0 else NEON_CYAN
		draw_circle(position, 7.0 + blink * 3.0, Color(color, 0.025 * blink))
		draw_circle(position, 1.8, Color(color, 0.55 * blink))
		draw_line(position - Vector2(5.0, 0.0), position - Vector2(10.0, 0.0), Color(color, 0.35 * blink), 1.0)
		draw_line(position + Vector2(5.0, 0.0), position + Vector2(10.0, 0.0), Color(color, 0.35 * blink), 1.0)
	# Four rotating readout labels make the radar feel instrumented.
	for index in range(4):
		var angle := elapsed * -0.12 + float(index) * TAU / 4.0
		var position := center + Vector2.from_angle(angle) * (radius + 37.0)
		var label := "%02X:%03d" % [index * 19 + turn_index, int(fmod(elapsed * 37.0 + index * 113.0, 999.0))]
		draw_string(Fonts.regular(), position, label, HORIZONTAL_ALIGNMENT_LEFT, 70.0, Typography.label_small_size, Color(NEON_CYAN, 0.38))
	pass


func draw_orbit_packets(center: Vector2) -> void:
	var orbit_count := 18 if phase == DeckPhase.REASONING else 10
	for index in range(orbit_count):
		var lane := index % 3
		var radius := CORE_RADIUS + 72.0 + lane * 25.0
		var speed := 0.44 + lane * 0.17
		var angle := elapsed * speed * (-1.0 if lane == 1 else 1.0) + float(index) * TAU / float(orbit_count)
		var position := center + Vector2.from_angle(angle) * radius
		var tangent := Vector2.from_angle(angle + PI * 0.5)
		var color := NEON_MAGENTA if index % 6 == 0 else NEON_CYAN
		draw_line(position - tangent * 7.0, position + tangent * 7.0, Color(color, 0.68), 2.0, true)
		if index % 3 == 0:
			draw_circle(position, 4.5, Color(color, 0.09))
	pass


func draw_ambient_energy(center: Vector2) -> void:
	# A restrained horizontal flare keeps focus on the core without splitting the screen.
	for layer in range(8, 0, -1):
		var flare_width := size.x * (0.12 + layer * 0.045)
		var flare_height := 3.0 + layer * 4.0
		draw_rect(Rect2(center - Vector2(flare_width * 0.5, flare_height * 0.5), Vector2(flare_width, flare_height)), Color(NEON_CYAN, 0.008 * float(9 - layer)), true)
	pass


func draw_system_chrome(center: Vector2) -> void:
	var top_y := 34.0
	var bar_width := minf(size.x * 0.42, 720.0)
	var left := center.x - bar_width * 0.5
	draw_line(Vector2(left, top_y), Vector2(center.x - 86.0, top_y), Color(NEON_CYAN, 0.5), 1.0)
	draw_line(Vector2(center.x + 86.0, top_y), Vector2(left + bar_width, top_y), Color(NEON_MAGENTA, 0.42), 1.0)
	draw_centered_text(Vector2(center.x, top_y + 5.0), "C Y B E R   C O M M A N D   D E C K", Fonts.semibold(), Typography.label_small_size, Color(NEON_CYAN, 0.9))
	draw_string(Fonts.regular(), Vector2(left, top_y + 24.0), "SYS // GAI-OS", HORIZONTAL_ALIGNMENT_LEFT, 160.0, Typography.label_small_size, ColorBase.secondary_text)
	draw_string(Fonts.regular(), Vector2(left + bar_width - 160.0, top_y + 24.0), "LINK // SECURE", HORIZONTAL_ALIGNMENT_RIGHT, 160.0, Typography.label_small_size, Color(NEON_MAGENTA, 0.72))
	var bottom_y := size.y - 34.0
	for index in range(24):
		var height := 3.0 + absf(sin(elapsed * 3.0 + index * 0.73)) * 12.0 * activity
		var x := center.x - 144.0 + index * 12.0
		draw_rect(Rect2(Vector2(x, bottom_y - height), Vector2(5.0, height)), Color(NEON_CYAN if index % 4 else NEON_MAGENTA, 0.48), true)
	draw_centered_text(Vector2(center.x, bottom_y + 16.0), "NEURAL BUS  /  LIVE TELEMETRY  /  ZERO LATENCY", Fonts.regular(), Typography.label_small_size, ColorBase.secondary_text)
	pass


func draw_edge_telemetry(center: Vector2) -> void:
	var rail_top := 104.0
	var rail_bottom := size.y - 92.0
	var rail_inset := 32.0
	for side: float in [-1.0, 1.0]:
		var x := rail_inset if side < 0.0 else size.x - rail_inset
		var inward := -side
		draw_line(Vector2(x, rail_top), Vector2(x, rail_bottom), Color(NEON_BLUE, 0.16), 1.0)
		for index in range(7):
			var y := lerpf(rail_top, rail_bottom, float(index) / 6.0)
			var hot := index == (int(elapsed * 2.0) + (0 if side < 0.0 else 3)) % 7
			var color := NEON_MAGENTA if hot else NEON_CYAN
			var length := 24.0 if index % 3 == 0 else 13.0
			draw_line(Vector2(x, y), Vector2(x + inward * length, y), Color(color, 0.78 if hot else 0.28), 2.0 if hot else 1.0)
			if index % 2 == 0:
				var code := "%02X" % int(fmod(index * 29.0 + elapsed * 7.0 + turn_index, 255.0))
				var text_x := x + inward * (length + 7.0) - (28.0 if side < 0.0 else 0.0)
				draw_string(Fonts.regular(), Vector2(text_x, y - 4.0), code, HORIZONTAL_ALIGNMENT_LEFT, 28.0, Typography.label_small_size, Color(color, 0.34))
	# Phase marker deliberately sits off-axis like a cockpit warning label.
	var phase_text: String = String(DeckPhase.keys()[phase])
	draw_string(Fonts.semibold(), Vector2(rail_inset + 13.0, center.y - 9.0), "[ %s ]" % phase_text, HORIZONTAL_ALIGNMENT_LEFT, 110.0, Typography.label_small_size, Color(NEON_MAGENTA, 0.72))
	draw_string(Fonts.regular(), Vector2(size.x - rail_inset - 132.0, center.y - 9.0), "ACT %03d%%" % int(activity * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 118.0, Typography.label_small_size, Color(NEON_CYAN, 0.68))
	pass


func draw_data_rain(center: Vector2) -> void:
	var horizon := center.y + minf(size.y * 0.16, 150.0)
	# Sparse deterministic columns imply a distant neon megacity without obscuring content.
	for index in range(42):
		var lane_x := fmod(float(index * 149 + 31), maxf(size.x, 1.0))
		var speed := 18.0 + float(index % 7) * 8.0
		var y := fmod(float(index * 83) + elapsed * speed, maxf(horizon - 54.0, 1.0)) + 54.0
		var column_height := 12.0 + float(index % 5) * 9.0
		var color := NEON_MAGENTA if index % 9 == 0 else NEON_CYAN
		var alpha := 0.055 + float(index % 4) * 0.014
		draw_line(Vector2(lane_x, y - column_height), Vector2(lane_x, y), Color(color, alpha), 1.0)
		draw_rect(Rect2(Vector2(lane_x - 1.0, y), Vector2(3.0, 2.0)), Color(color, alpha * 2.2), true)
	# Low skyline blocks anchor the horizon and add parallax against the floor grid.
	for index in range(30):
		var block_width := 18.0 + float((index * 7) % 23)
		var x := float(index) * size.x / 29.0 - block_width * 0.5
		var block_height := 8.0 + float((index * 17) % 52)
		draw_rect(Rect2(Vector2(x, horizon - block_height), Vector2(block_width, block_height)), Color(NEON_BLUE, 0.018 + float(index % 3) * 0.008), true)
		if index % 3 == 0:
			draw_line(Vector2(x + block_width * 0.5, horizon - block_height), Vector2(x + block_width * 0.5, horizon - block_height - 11.0), Color(NEON_MAGENTA, 0.13), 1.0)
	pass


func draw_backplane(center: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(DECK_VOID, 0.28), true)
	# Horizon and perspective floor turn the overlay into a room rather than graph paper.
	var horizon := center.y + minf(size.y * 0.16, 150.0)
	for ray in range(-12, 13):
		var bottom_x := center.x + float(ray) * size.x / 12.0
		draw_line(Vector2(center.x, horizon), Vector2(bottom_x, size.y), Color(NEON_BLUE, 0.055), 1.0)
	for band in range(11):
		var amount := float(band) / 10.0
		var curved := amount * amount
		var y := lerpf(horizon, size.y, curved)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(NEON_CYAN, 0.045 + amount * 0.035), 1.0)
	# Upper technical grid and major axes.
	var grid_step := 64.0
	var drift := fmod(elapsed * 5.0, grid_step)
	for x in range(-1, int(size.x / grid_step) + 2):
		var px := float(x) * grid_step + drift
		draw_line(Vector2(px, 0.0), Vector2(px, horizon), Color(NEON_BLUE, 0.025), 1.0)
	for y in range(0, int(horizon / grid_step) + 1):
		draw_line(Vector2(0.0, y * grid_step), Vector2(size.x, y * grid_step), Color(NEON_BLUE, 0.025), 1.0)
	draw_line(Vector2(0.0, center.y), Vector2(size.x, center.y), Color(NEON_CYAN, 0.13), 1.0)
	draw_line(Vector2(center.x, 0.0), Vector2(center.x, size.y), Color(NEON_MAGENTA, 0.08), 1.0)
	draw_hud_corners()
	pass


func draw_screen_fx() -> void:
	# Fine scanlines, drifting data ticks, and a restrained magenta glitch channel.
	for y in range(0, int(size.y), 5):
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(NEON_CYAN, 0.012), 1.0)
	for index in range(28):
		var px := fmod(float(index * 173) + elapsed * (9.0 + index % 4), maxf(size.x, 1.0))
		var py := fmod(float(index * 97) + elapsed * (4.0 + index % 3), maxf(size.y, 1.0))
		var length := 4.0 + float(index % 5) * 3.0
		draw_line(Vector2(px, py), Vector2(px + length, py), Color(NEON_CYAN if index % 3 else NEON_MAGENTA, 0.16), 1.0)
	var glitch := fmod(elapsed * 3.7, 5.0)
	if glitch < 0.11:
		var gy := fmod(elapsed * 431.0, size.y)
		draw_rect(Rect2(Vector2(0.0, gy), Vector2(size.x, 2.0)), Color(NEON_MAGENTA, 0.2), true)
		# A few displaced RGB fragments sell a digital signal fault without moving the UI.
		for slice in range(4):
			var slice_y := fmod(gy + slice * 43.0, size.y)
			var slice_x := fmod(elapsed * 977.0 + slice * 271.0, maxf(size.x - 180.0, 1.0))
			var slice_width := 46.0 + slice * 31.0
			draw_rect(Rect2(Vector2(slice_x - 7.0, slice_y), Vector2(slice_width, 1.0)), Color(NEON_MAGENTA, 0.32), true)
			draw_rect(Rect2(Vector2(slice_x + 7.0, slice_y + 2.0), Vector2(slice_width, 1.0)), Color(NEON_CYAN, 0.28), true)
	pass


func draw_hud_corners() -> void:
	var inset := 28.0
	var length := 72.0
	for x_side: float in [-1.0, 1.0]:
		for y_side: float in [-1.0, 1.0]:
			var corner := Vector2(inset if x_side < 0.0 else size.x - inset, inset if y_side < 0.0 else size.y - inset)
			draw_line(corner, corner + Vector2(-x_side * length, 0.0), Color(NEON_CYAN, 0.55), 2.0)
			draw_line(corner, corner + Vector2(0.0, -y_side * length), Color(NEON_MAGENTA, 0.42), 2.0)
	pass


func draw_radar(center: Vector2) -> void:
	var radius := minf(size.y * 0.35, 270.0)
	for ring in range(1, 5):
		var ring_color := NEON_CYAN if ring % 2 else NEON_BLUE
		draw_arc(center, radius * float(ring) / 4.0, 0.0, TAU, 72, Color(ring_color, 0.1), 1.0, true)
		for tick in range(24):
			var tick_angle := float(tick) * TAU / 24.0
			var tick_radius := radius * float(ring) / 4.0
			var tick_length := 6.0 if tick % 3 == 0 else 3.0
			draw_line(center + Vector2.from_angle(tick_angle) * tick_radius, center + Vector2.from_angle(tick_angle) * (tick_radius + tick_length), Color(NEON_CYAN, 0.22), 1.0)
	var angle := radar_angle
	for slice in range(7):
		var slice_angle := angle - float(slice) * 0.055
		var sweep := PackedVector2Array([center, center + Vector2.from_angle(slice_angle - 0.055) * radius, center + Vector2.from_angle(slice_angle) * radius])
		draw_colored_polygon(sweep, Color(NEON_CYAN, (0.015 + activity * 0.012) * float(7 - slice)))
	draw_line(center, center + Vector2.from_angle(angle) * radius, Color(NEON_CYAN, 0.9), 2.0, true)
	# A counter-rotating magenta targeting arc keeps the palette from reading monochrome.
	var target_angle := -elapsed * 0.34
	draw_arc(center, radius + 13.0, target_angle, target_angle + 0.62, 24, Color(NEON_MAGENTA, 0.72), 3.0, true)
	draw_circle(center + Vector2.from_angle(target_angle + 0.62) * (radius + 13.0), 3.0, Color(NEON_MAGENTA, 0.95))
	pass


func draw_waveforms(center: Vector2) -> void:
	var width := minf(size.x * 0.2, 245.0)
	for side: float in [-1.0, 1.0]:
		var points := PackedVector2Array()
		for index in range(33):
			var amount := float(index) / 32.0
			var x := center.x + side * (CORE_RADIUS + 32.0 + amount * width)
			var wave_value := sin(elapsed * 7.0 + amount * 25.0) * 7.0 * activity + sin(elapsed * 3.1 + amount * 11.0) * 3.0
			points.append(Vector2(x, center.y + wave_value))
		draw_polyline(points, Color(NEON_CYAN, 0.1), 9.0, true)
		draw_polyline(points, Color(NEON_CYAN, 0.88), 1.7, true)
		for marker in range(0, points.size(), 8):
			draw_circle(points[marker], 2.2, Color(NEON_MAGENTA, 0.72))
	pass


func draw_core(center: Vector2) -> void:
	var core_scale := 1.0 - collapse * 0.82
	var radius := CORE_RADIUS * core_scale
	var pulse := (sin(elapsed * 4.0) + 1.0) * 0.5
	# Broken targeting rings add the dense mechanical readout associated with cyberpunk HUDs.
	for ring in range(3):
		var lock_radius := radius + 112.0 + ring * 18.0
		var rotation := elapsed * (0.22 + ring * 0.07) * (-1.0 if ring == 1 else 1.0)
		for segment in range(8):
			if (segment + ring) % 3 == 0:
				continue
			var start := rotation + float(segment) * TAU / 8.0
			var span := 0.24 + float((segment + ring) % 3) * 0.07
			var ring_color := NEON_MAGENTA if ring == 1 and segment % 2 == 0 else NEON_CYAN
			draw_arc(center, lock_radius, start, start + span, 10, Color(ring_color, (0.2 + pulse * 0.08) * (1.0 - collapse)), 1.5 if ring == 1 else 1.0, true)
	# Orthogonal lock brackets make the core read as a target rather than decoration.
	var bracket_radius := radius + 58.0
	for quarter in range(4):
		var direction := Vector2.from_angle(float(quarter) * PI * 0.5)
		var tangent := direction.rotated(PI * 0.5)
		var anchor := center + direction * bracket_radius
		draw_line(anchor - tangent * 12.0, anchor + tangent * 12.0, Color(NEON_CYAN, 0.66 * (1.0 - collapse)), 2.0)
		draw_line(anchor, anchor + direction * 9.0, Color(NEON_MAGENTA, 0.52 * (1.0 - collapse)), 1.0)
	# Wide fake bloom gives the core its own light source.
	for glow in range(9, 0, -1):
		draw_circle(center, radius + glow * 11.0 + pulse * 5.0, Color(NEON_CYAN, 0.0055 * float(10 - glow) * (1.0 - collapse)))
	# Detached armour shards create a machine silhouette instead of another radar dial.
	for shard in range(12):
		var angle := elapsed * (0.08 if shard % 2 else -0.06) + float(shard) * TAU / 12.0
		var inner := radius + 39.0 + float(shard % 3) * 8.0
		var outer := inner + 20.0 + float(shard % 2) * 11.0
		var half_angle := 0.045 + float(shard % 3) * 0.012
		var shard_color := NEON_MAGENTA if shard % 4 == 0 else NEON_CYAN
		var shard_points := PackedVector2Array([
			center + Vector2.from_angle(angle - half_angle) * inner,
			center + Vector2.from_angle(angle - half_angle * 0.45) * outer,
			center + Vector2.from_angle(angle + half_angle * 0.45) * outer,
			center + Vector2.from_angle(angle + half_angle) * inner,
		])
		draw_colored_polygon(shard_points, Color(shard_color, (0.22 + pulse * 0.08) * (1.0 - collapse)))
		draw_polyline(PackedVector2Array([shard_points[0], shard_points[1], shard_points[2], shard_points[3]]), Color(shard_color, 0.75 * (1.0 - collapse)), 1.2, true)
	# Three nested faceted shells suggest a holographic reactor.
	var outer_hex := polygon_points(center, radius + 24.0, 6, elapsed * 0.11)
	var mid_hex := polygon_points(center, radius + 8.0, 6, -elapsed * 0.16 + PI / 6.0)
	var core_hex := polygon_points(center, radius, 6, PI / 6.0)
	draw_colored_polygon(outer_hex, Color(NEON_BLUE, (0.08 + pulse * 0.025) * (1.0 - collapse)))
	draw_closed_polyline(outer_hex, Color(NEON_CYAN, 0.34 * (1.0 - collapse)), 2.0)
	draw_colored_polygon(mid_hex, Color(NEON_MAGENTA, 0.055 * (1.0 - collapse)))
	draw_closed_polyline(mid_hex, Color(NEON_MAGENTA, 0.65 * (1.0 - collapse)), 1.6)
	draw_colored_polygon(core_hex, Color(ColorBase.deep_surface, 0.96))
	draw_closed_polyline(core_hex, Color(NEON_CYAN, 0.9 * (1.0 - collapse)), 2.2)
	# Facet lighting and hot centre.
	for index in range(6):
		var facet := PackedVector2Array([center, core_hex[index], core_hex[(index + 1) % 6]])
		draw_colored_polygon(facet, Color(NEON_BLUE if index % 2 else NEON_CYAN, 0.025 + index * 0.008))
	draw_circle(center, 9.0 + pulse * 4.0, Color(NEON_CYAN, 0.11))
	draw_circle(center, 3.5 + pulse * 1.5, Color(NEON_CYAN, 0.95))
	if collapse < 0.86:
		draw_centered_text(center - Vector2(0.0, 23.0), "MISSION", Fonts.semibold(), Typography.label_medium_size, ColorBase.primary_text)
		draw_centered_text(center - Vector2(0.0, 6.0), "C O R E", Fonts.bold(), Typography.title_small_size, Color(NEON_CYAN, 0.98))
		draw_centered_text(center + Vector2(0.0, 24.0), core_status(), Fonts.medium(), Typography.label_small_size, Color(NEON_MAGENTA, 0.9))
		draw_centered_text(center + Vector2(0.0, 42.0), "T-%02d  //  %02d ACTIVE" % [maxi(turn_index, 1), active_pod_count()], Fonts.regular(), Typography.label_small_size, ColorBase.secondary_text)
	pass


func draw_pod_link(pod: Dictionary, rect: Rect2, center: Vector2) -> void:
	var open_amount := float(pod["open"]) * (1.0 - collapse)
	if open_amount <= 0.01:
		return
	var left_side := rect.get_center().x < center.x
	var target := Vector2(rect.end.x if left_side else rect.position.x, rect.get_center().y)
	var start := center + Vector2(-CORE_RADIUS - 35.0 if left_side else CORE_RADIUS + 35.0, (target.y - center.y) * 0.18)
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
		draw_rect(Rect2(return_position - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(NEON_MAGENTA, 0.8), true)
	pass


func draw_tool_pod(pod: Dictionary, rect: Rect2) -> void:
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
	draw_colored_polygon(shadow, Color(NEON_BLUE, 0.055))
	draw_polyline(PackedVector2Array([shadow[0], shadow[1], shadow[2], shadow[3]]), Color(NEON_MAGENTA, 0.16), 4.0, true)
	var is_executing := state == PodState.EXECUTING
	var active_breath := 0.5 + 0.5 * sin(elapsed * 5.2 + float(pod["slot"]))
	if is_executing:
		for glow in range(4, 0, -1):
			draw_polyline(outset_polyline(panel, float(glow) * 3.0), Color(NEON_CYAN, (0.018 + active_breath * 0.012) * float(5 - glow)), 4.0, true)
	draw_colored_polygon(panel, Color(NEON_CYAN, 0.075 + active_breath * 0.025) if is_executing else Color(ColorBase.deep_surface, 0.94))
	var outline := PackedVector2Array(panel)
	outline.append(panel[0])
	draw_polyline(outline, Color(color, 0.2 if is_executing else 0.12), 9.0 if is_executing else 7.0, true)
	draw_polyline(outline, Color(color, 0.98 if is_executing else 0.8), 2.2 if is_executing else 1.4, true)
	draw_line(shown.position + Vector2(cut + 8.0, 0.0), shown.position + Vector2(shown.size.x * 0.62, 0.0), Color(color, 0.98), 3.0)
	draw_line(shown.position + Vector2(shown.size.x * 0.66, 0.0), shown.position + Vector2(shown.size.x * 0.84, 0.0), Color(NEON_MAGENTA, 0.72), 3.0)
	var title := ToolConstellation.public_tool_name(String(pod["name"]))
	var glyph := ToolConstellation.tool_glyph(String(pod["name"]))
	draw_rect(Rect2(shown.position + Vector2(15.0, 17.0), Vector2(34.0, 34.0)), Color(color, 0.08), true)
	draw_rect(Rect2(shown.position + Vector2(15.0, 17.0), Vector2(34.0, 34.0)), Color(color, 0.58), false, 1.0)
	draw_centered_text(shown.position + Vector2(32.0, 40.0), glyph, Fonts.bold(), Typography.label_medium_size, color)
	draw_string(Fonts.semibold(), shown.position + Vector2(59.0, 27.0), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, shown.size.x - 80.0, Typography.label_medium_size, ColorBase.primary_text)
	draw_string(Fonts.medium(), shown.position + Vector2(59.0, 49.0), "// " + pod_status(state), HORIZONTAL_ALIGNMENT_LEFT, shown.size.x - 80.0, Typography.label_small_size, color)
	draw_string(Fonts.regular(), shown.position + Vector2(shown.size.x - 62.0, 49.0), "%02d" % int(pod["slot"]), HORIZONTAL_ALIGNMENT_RIGHT, 45.0, Typography.label_small_size, Color(NEON_MAGENTA, 0.7))
	if is_executing:
		var live_rect := Rect2(shown.position + Vector2(shown.size.x - 62.0, 8.0), Vector2(46.0, 15.0))
		draw_rect(live_rect, Color(NEON_CYAN, 0.12 + active_breath * 0.08), true)
		draw_rect(live_rect, Color(NEON_CYAN, 0.8), false, 1.0)
		draw_string(Fonts.bold(), live_rect.position + Vector2(8.0, 11.0), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, 34.0, Typography.label_small_size, Color(NEON_CYAN, 0.95))
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


func draw_pod_activity(pod: Dictionary, rect: Rect2, color: Color) -> void:
	var state: int = pod["state"]
	var age: float = pod["age"]
	if state == PodState.CONNECTING:
		var sweep_x := rect.position.x + fmod(age / CONNECT_SECONDS, 1.0) * rect.size.x
		draw_rect(Rect2(Vector2(sweep_x - 10.0, rect.position.y + 3.0), Vector2(20.0, rect.size.y - 6.0)), Color(NEON_MAGENTA, 0.045), true)
		for dot in range(3):
			var dot_alpha := 0.25 + 0.75 * absf(sin(elapsed * 5.0 + dot * 1.6))
			draw_circle(rect.position + Vector2(62.0 + dot * 9.0, rect.size.y - 11.0), 1.8, Color(NEON_MAGENTA, dot_alpha))
		return
	if state == PodState.EXECUTING:
		var scan_x := rect.position.x + fmod(elapsed * 0.72 + float(pod["slot"]) * 0.11, 1.0) * rect.size.x
		draw_rect(Rect2(Vector2(scan_x - 16.0, rect.position.y + 3.0), Vector2(32.0, rect.size.y - 6.0)), Color(NEON_CYAN, 0.055), true)
		for chevron in range(3):
			var chevron_x := rect.position.x + 58.0 + chevron * 10.0
			var chevron_y := rect.end.y - 10.0
			draw_polyline(PackedVector2Array([Vector2(chevron_x, chevron_y - 3.0), Vector2(chevron_x + 4.0, chevron_y), Vector2(chevron_x, chevron_y + 3.0)]), Color(NEON_CYAN, 0.4 + chevron * 0.18), 1.3, true)
		var graph := PackedVector2Array()
		var graph_left := rect.position.x + rect.size.x * 0.58
		var graph_width := rect.size.x * 0.28
		for point in range(13):
			var amount := float(point) / 12.0
			var value := sin(elapsed * 5.4 + amount * 13.0 + int(pod["slot"])) * 5.0 + sin(elapsed * 2.1 + amount * 27.0) * 2.0
			graph.append(Vector2(graph_left + amount * graph_width, rect.position.y + rect.size.y - 23.0 + value))
		draw_polyline(graph, Color(color, 0.2), 5.0, true)
		draw_polyline(graph, Color(color, 0.9), 1.2, true)
		return
	# A short local confirmation pulse is tied to the tool completion event.
	if age < 0.7:
		var pulse := age / 0.7
		var pulse_rect := rect.grow(10.0 * pulse)
		draw_polyline(closed_cut_panel(pulse_rect), Color(color, (1.0 - pulse) * 0.65), 2.0, true)
	pass


func draw_completion_wave(center: Vector2) -> void:
	var max_radius := size.length() * 0.58
	var radius := scan_wave * max_radius
	draw_arc(center, radius, 0.0, TAU, 128, Color(NEON_CYAN, (1.0 - scan_wave) * 0.95), 5.0, true)
	draw_arc(center, maxf(0.0, radius - 18.0), 0.0, TAU, 128, Color(NEON_BLUE, (1.0 - scan_wave) * 0.3), 15.0, true)
	draw_arc(center, maxf(0.0, radius - 34.0), 0.0, TAU, 128, Color(NEON_MAGENTA, (1.0 - scan_wave) * 0.48), 2.0, true)
	pass


func pod_rect(index: int, _count: int, center: Vector2) -> Rect2:
	var width := clampf(size.x * 0.17, 170.0, 260.0)
	var height := 78.0
	var side := -1.0 if index % 2 == 0 else 1.0
	var row := index / 2
	var y_offset := (float(row) - 1.5) * (height + 22.0)
	var x := center.x + side * (minf(size.x * 0.31, 390.0) + width * 0.5) - width * 0.5
	return Rect2(Vector2(x, center.y + y_offset - height * 0.5), Vector2(width, height))


func active_pod_count() -> int:
	var count := 0
	for pod: Dictionary in pods:
		if int(pod["state"]) <= PodState.EXECUTING:
			count += 1
	return count


func core_status() -> String:
	match phase:
		DeckPhase.REASONING:
			return "RADAR ANALYSIS"
		DeckPhase.RESPONDING:
			return "SYNTHESIZING"
		DeckPhase.ENDING:
			return "MISSION COMPLETE"
	return "SYSTEM ONLINE"


static func pod_status(state: int) -> String:
	match state:
		PodState.CONNECTING:
			return "CONNECTING"
		PodState.EXECUTING:
			return "EXECUTING"
		PodState.COMPLETE:
			return "COMPLETE"
	return "FAILED"


static func pod_color(state: int) -> Color:
	match state:
		PodState.COMPLETE:
			return ColorBase.success
		PodState.FAILED:
			return ColorBase.error
		PodState.CONNECTING:
			return NEON_MAGENTA
	return NEON_CYAN


static func make_pod(tool_call_id: String, tool_name: String, args: Dictionary[String, Variant], slot: int) -> Dictionary:
	return {"id": tool_call_id, "name": tool_name, "arg_count": args.size(), "slot": slot, "state": PodState.CONNECTING, "pending_state": -1, "age": 0.0, "open": 0.0}


func all_pods_finished_holding() -> bool:
	for pod: Dictionary in pods:
		if int(pod["state"]) < PodState.COMPLETE or float(pod["age"]) < COMPLETE_HOLD_SECONDS:
			return false
	return true


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


func draw_centered_text(position: Vector2, text: String, font: Font, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, position - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	pass
