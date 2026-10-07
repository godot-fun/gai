class_name ToolConstellation
extends VisualEffect

## Event-driven star map of the agent core, invoked tools, and their execution history.
## Inner orbit holds live calls; settled tools drift outward into turn-linked constellations.

const MAX_NODES := 32
const PACKET_COUNT := 5
const CORE_RADIUS := 62.0
const NODE_RADIUS := 24.0
const STAR_COUNT := 96
const CURVE_STEPS := 32
const GOLDEN_ANGLE := 2.399963
const MIN_TOOL_PLAY_SECONDS := 1.35
const RESULT_HOLD_SECONDS := 0.7
const COMPLETE_SECONDS := 2.8
const RING_EXPAND_SECONDS := 3.6
const RING_LAYER_COUNT := 7
const DUST_COUNT := 48
## Fixed logical-pixel footprint of the center CRT. Keep orbit_radius() clearance in sync
## when changing this value so live tool nodes never overlap the command card.
const TERMINAL_SIZE := Vector2(304.0, 174.0)
## Streaming text is bounded because message chunks may contain an entire long response.
## The renderer only needs the most recent tail that could appear on the two-line display.
const STREAM_BUFFER_LIMIT := 180
const CRT_GLITCH_SECONDS := 0.55

enum ExecutionState { RUNNING, SUCCESS, FAILED }
enum ToolFamily { GENERIC, READ, WRITE, SEARCH, SHELL, WEB, IMAGE, AUDIO }

var nodes: Array[Dictionary] = []
var active_calls: Dictionary[String, int] = {}
var pending_calls: Array[Dictionary] = []
var pending_results: Dictionary[String, AgentToolResult] = {}
var playing_call: Dictionary = {}
var playing_seconds: float = 0.0
var result_hold_seconds: float = 0.0
var turn_index: int = 0
var spawn_sequence: int = 0
var elapsed: float = 0.0
var core_pulse: float = 0.0
var absorb_flash: float = 0.0
var completion: float = 0.0
var completing: bool = false
var ended_with_error: bool = false
## Raw recent stream tail and its OpenAI stream kind drive the terminal copy independently
## from the serialized tool-call playback timeline.
var stream_buffer: String = ""
var stream_kind: String = ""
## Seconds remaining, not a normalized amount. Rendering normalizes it so duration can be
## tuned without rewriting every glitch effect.
var crt_glitch: float = 0.0
## 0 = rings collapsed at the core, 1 = fully expanded field.
var field_spread: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.TOOL_CONSTELLATION


func fade_in_seconds() -> float:
	return 0.3


func fade_out_seconds() -> float:
	return 0.4


func reset_visual() -> void:
	nodes.clear()
	active_calls.clear()
	pending_calls.clear()
	pending_results.clear()
	playing_call.clear()
	playing_seconds = 0.0
	result_hold_seconds = 0.0
	turn_index = 0
	spawn_sequence = 0
	elapsed = 0.0
	core_pulse = 0.0
	absorb_flash = 0.0
	completion = 0.0
	completing = false
	ended_with_error = false
	stream_buffer = ""
	stream_kind = ""
	crt_glitch = 0.0
	field_spread = 0.0
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	field_spread = 0.0
	core_pulse = 1.0
	queue_redraw()
	pass


func on_agent_end(error_message: String) -> float:
	# Tool animation owns a separate timeline. VisualControl waits for the queued calls in
	# wait_for_agent_end(), so fast real executions remain readable instead of collapsing.
	ended_with_error = StringUtils.is_not_blank(error_message)
	if ended_with_error:
		crt_glitch = CRT_GLITCH_SECONDS
	var fallback_result := AgentToolResult.ok("completed") if not ended_with_error else AgentToolResult.error(error_message)
	if not playing_call.is_empty():
		var playing_id := String(playing_call["id"])
		if not pending_results.has(playing_id):
			pending_results[playing_id] = fallback_result
	for call: Dictionary in pending_calls:
		var pending_id := String(call["id"])
		if not pending_results.has(pending_id):
			pending_results[pending_id] = fallback_result
	core_pulse = 1.0
	queue_redraw()
	return 0.0


func wait_for_agent_end() -> void:
	while not pending_calls.is_empty() or not playing_call.is_empty() or result_hold_seconds > 0.0:
		await get_tree().process_frame
	completing = true
	completion = 0.0
	while completion < 1.0:
		await get_tree().process_frame
	pass


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


func on_message_update(chunk: String, next_stream_kind: String) -> void:
	# Chunks can be tiny token fragments. Append first, then retain only a bounded tail so
	# redraw cost and memory usage remain stable throughout long responses.
	stream_kind = next_stream_kind
	stream_buffer = terminal_text(stream_buffer + chunk)
	core_pulse = 1.0
	queue_redraw()
	pass


func on_tool_execution_start(tool_call_id: String, tool_name: String, args: Dictionary[String, Variant]) -> void:
	pending_calls.append({"id": tool_call_id, "name": tool_name, "args": args.duplicate(true), "turn": turn_index})
	start_next_queued_call()
	pass


func on_tool_execution_end(tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	pending_results[tool_call_id] = result
	pass


func on_theme_changed() -> void:
	queue_redraw()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	core_pulse = move_toward(core_pulse, 0.0, delta * 1.8)
	absorb_flash = move_toward(absorb_flash, 0.0, delta * 2.4)
	crt_glitch = move_toward(crt_glitch, 0.0, delta)
	if completing:
		completion = minf(completion + delta / COMPLETE_SECONDS, 1.0)
		field_spread = 1.0 - completion
	else:
		field_spread = move_toward(field_spread, 1.0, delta / RING_EXPAND_SECONDS)
	advance_tool_queue(delta)
	for node: Dictionary in nodes:
		node["growth"] = move_toward(float(node["growth"]), 1.0, delta * 3.2)
		if int(node["state"]) != ExecutionState.RUNNING:
			var previous_settle := float(node["settle"])
			node["settle"] = move_toward(previous_settle, 1.0, delta * 1.6)
			if int(node["state"]) == ExecutionState.SUCCESS and previous_settle < 0.98 and float(node["settle"]) >= 0.98:
				absorb_flash = 1.0
		var target_orbit := target_orbit_for(node)
		node["orbit"] = move_toward(float(node["orbit"]), target_orbit, delta * 1.7)
	queue_redraw()
	pass


func advance_tool_queue(delta: float) -> void:
	if result_hold_seconds > 0.0:
		result_hold_seconds = maxf(0.0, result_hold_seconds - delta)
		if result_hold_seconds <= 0.0:
			playing_call.clear()
			start_next_queued_call()
		return
	if playing_call.is_empty():
		start_next_queued_call()
		return
	playing_seconds += delta
	var tool_call_id := String(playing_call["id"])
	if playing_seconds < MIN_TOOL_PLAY_SECONDS or not pending_results.has(tool_call_id):
		return
	complete_playing_call(pending_results[tool_call_id])
	pass


func start_next_queued_call() -> void:
	if not playing_call.is_empty() or result_hold_seconds > 0.0 or pending_calls.is_empty():
		return
	playing_call = pending_calls.pop_front()
	playing_seconds = 0.0
	var tool_call_id := String(playing_call["id"])
	var tool_name := String(playing_call["name"])
	var args: Dictionary[String, Variant] = playing_call["args"]
	var node := make_node(tool_call_id, tool_name, args, spawn_sequence, int(playing_call["turn"]))
	spawn_sequence += 1
	var slot_index := nodes.size()
	if nodes.size() >= MAX_NODES:
		# Replace in place so orbital slots keep their screen positions.
		slot_index = oldest_settled_node_index()
		nodes[slot_index] = node
	else:
		nodes.append(node)
	active_calls[tool_call_id] = slot_index
	core_pulse = 1.0
	queue_redraw()
	pass


func complete_playing_call(result: AgentToolResult) -> void:
	var tool_call_id := String(playing_call["id"])
	if active_calls.has(tool_call_id):
		var index: int = active_calls[tool_call_id]
		if index >= 0 and index < nodes.size():
			nodes[index]["state"] = ExecutionState.FAILED if result.is_error else ExecutionState.SUCCESS
			nodes[index]["settle"] = 0.0
			if result.is_error:
				crt_glitch = CRT_GLITCH_SECONDS
	active_calls.erase(tool_call_id)
	pending_results.erase(tool_call_id)
	result_hold_seconds = RESULT_HOLD_SECONDS
	core_pulse = 1.0
	queue_redraw()
	pass


func _draw() -> void:
	if size.x < 180.0 or size.y < 180.0:
		return
	var center := field_center()
	var fade := 1.0 - completion * 0.92
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_deep_space(center)
	draw_star_field(center)
	draw_orbits(center)
	draw_radar_sweep(center)
	draw_constellation_links(center, fade)
	for index in range(nodes.size()):
		draw_connection(nodes[index], center, node_position(index, nodes.size(), center), fade)
	for index in range(nodes.size()):
		draw_tool_node(nodes[index], node_position(index, nodes.size(), center), center, fade)
	draw_core(center, fade)
	if completing:
		draw_completion_dust(center)
	pass


func field_center() -> Vector2:
	# Slight bias leaves room for the constellation to read as a star map, not a centered badge.
	return size * 0.5 + Vector2(-size.x * 0.03, size.y * 0.015)


func draw_deep_space(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	for layer in range(RING_LAYER_COUNT, 0, -1):
		var spread := layer_spread(layer, RING_LAYER_COUNT)
		if spread <= 0.001:
			continue
		var radius := minf(size.x, size.y) * (0.09 + float(layer) * 0.075) * spread
		draw_circle(center, radius, Color(accent, (0.006 + float(RING_LAYER_COUNT - layer) * 0.003) * spread))
	pass


func draw_orbits(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	var base_spread := layer_spread(2, RING_LAYER_COUNT)
	if base_spread <= 0.001:
		return
	var base_radius := orbit_radius(0.0) * base_spread
	for orbit_index in range(3):
		var spread := layer_spread(orbit_index + 2, RING_LAYER_COUNT)
		if spread <= 0.001:
			continue
		var radius := orbit_radius(float(orbit_index)) * spread
		var rotation := elapsed * (0.04 + orbit_index * 0.016) * (-1.0 if orbit_index % 2 else 1.0)
		for arc_index in range(3):
			var start := rotation + float(arc_index) * TAU / 3.0 + orbit_index * 0.28
			draw_arc(center, radius, start, start + 0.78, 30, Color(accent, (0.16 - orbit_index * 0.03) * spread), 1.6, true)
			draw_circle(center + Vector2.from_angle(start + 0.78) * radius, 2.4, Color(accent, 0.42 * spread))
	var tick_radius := base_radius + 28.0 * base_spread
	for tick in range(36):
		var angle := float(tick) * TAU / 36.0 + elapsed * 0.02
		var length := (7.0 if tick % 6 == 0 else 2.5) * base_spread
		var direction := Vector2.from_angle(angle)
		draw_line(center + direction * tick_radius, center + direction * (tick_radius + length), Color(accent, (0.2 if tick % 6 == 0 else 0.07) * base_spread), 1.2, true)
	pass


func draw_radar_sweep(center: Vector2) -> void:
	var spread := layer_spread(RING_LAYER_COUNT, RING_LAYER_COUNT)
	if spread <= 0.001:
		return
	var accent := ThemeColor.accent_theme_color()
	var radius := (orbit_radius(2.0) + 36.0) * spread
	var head := radar_head()
	for trail in range(10, 0, -1):
		var angle := head - float(trail) * 0.03
		draw_line(center, center + Vector2.from_angle(angle) * radius, Color(accent, (0.006 + float(10 - trail) * 0.005) * spread), 1.0, true)
	draw_line(center + Vector2.from_angle(head) * (CORE_RADIUS + 16.0), center + Vector2.from_angle(head) * radius, Color(accent, 0.2 * spread), 1.4, true)
	pass


func draw_star_field(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	for index in range(STAR_COUNT):
		var position := Vector2(fmod(float(index * 197 + 83), maxf(size.x, 1.0)), fmod(float(index * 113 + 47), maxf(size.y, 1.0)))
		if position.distance_to(center) < CORE_RADIUS * 1.8:
			continue
		var twinkle := 0.5 + 0.5 * sin(elapsed * (0.7 + float(index % 5) * 0.13) + index)
		var alpha := (0.05 + twinkle * 0.18) * (1.0 - completion * 0.7)
		draw_circle(position, 0.6 + float(index % 4) * 0.35, Color(accent, alpha))
	pass


func draw_constellation_links(center: Vector2, fade: float) -> void:
	if nodes.size() < 2:
		return
	var turn_groups: Dictionary[int, PackedInt32Array] = {}
	for index in range(nodes.size()):
		var turn: int = nodes[index]["turn"]
		if not turn_groups.has(turn):
			turn_groups[turn] = PackedInt32Array()
		var group: PackedInt32Array = turn_groups[turn]
		group.append(index)
		turn_groups[turn] = group
	var accent := ThemeColor.accent_theme_color()
	for turn: int in turn_groups.keys():
		var group: PackedInt32Array = turn_groups[turn]
		if group.size() < 2:
			continue
		var current_turn := turn == turn_index
		var link_color := accent if current_turn else ColorBase.secondary_text
		var alpha := (0.22 if current_turn else 0.1) * fade
		var points := angled_constellation_points(group, center)
		for edge in range(points.size()):
			var next := (edge + 1) % points.size()
			if points.size() == 2 and edge > 0:
				break
			draw_line(points[edge], points[next], Color(link_color, alpha), 1.8 if current_turn else 1.2, true)
			draw_circle(points[edge], 2.2, Color(link_color, alpha + 0.08))
		if current_turn and points.size() >= 3:
			draw_colored_polygon(points, Color(link_color, 0.035 * fade))
	pass


func angled_constellation_points(group: PackedInt32Array, center: Vector2) -> PackedVector2Array:
	var entries: Array[Dictionary] = []
	for member in group:
		var position := node_position(member, nodes.size(), center)
		entries.append({"angle": (position - center).angle(), "position": position})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["angle"]) < float(b["angle"]))
	var points := PackedVector2Array()
	for entry: Dictionary in entries:
		points.append(entry["position"])
	return points


func draw_core(center: Vector2, fade: float) -> void:
	# Render order is intentional: ambient glow and halo sit behind the opaque chassis;
	# terminal content sits below scanlines and the edge vignette to read as CRT glass.
	var accent := ThemeColor.accent_theme_color()
	var breath := (sin(elapsed * 2.4) + 1.0) * 0.5
	var terminal_rect := Rect2(center - TERMINAL_SIZE * 0.5, TERMINAL_SIZE)
	var glitch_strength := clampf(crt_glitch / CRT_GLITCH_SECONDS, 0.0, 1.0)
	var jitter := Vector2(sin(elapsed * 91.0), 0.0) * glitch_strength * 5.0
	terminal_rect.position += jitter
	for glow_index in range(4, 0, -1):
		var glow_rect := terminal_rect.grow(float(glow_index) * (4.0 + core_pulse * 2.0))
		draw_rect(glow_rect, Color(accent, (0.007 + breath * 0.003) * fade))
	# A restrained circular halo visually seats the rectangular CRT in the radial map.
	for halo_index in range(2):
		var halo_radius := TERMINAL_SIZE.x * (0.54 + float(halo_index) * 0.07)
		draw_arc(center, halo_radius, -PI * 0.86, PI * 0.16, 72, Color(accent, (0.13 - halo_index * 0.045) * fade), 1.2, true)
	if absorb_flash > 0.02:
		draw_rect(terminal_rect.grow(8.0 + (1.0 - absorb_flash) * 12.0), Color(ColorBase.success, 0.26 * absorb_flash * fade), false, 2.0)
	draw_rect(terminal_rect, Color(ColorBase.deep_surface, 0.98 * fade))
	draw_rect(terminal_rect, Color(accent, (0.72 + breath * 0.18) * fade), false, 2.0)
	var title_rect := Rect2(terminal_rect.position, Vector2(terminal_rect.size.x, 25.0))
	draw_rect(title_rect, Color(accent, 0.1 * fade))
	draw_line(title_rect.position + Vector2(0.0, title_rect.size.y), title_rect.end, Color(accent, 0.38 * fade), 1.0)
	draw_string(Fonts.semibold(), title_rect.position + Vector2(10.0, 17.0), "AGENT://CORE  T%02d" % maxi(turn_index, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.label_small_size, Color(accent, 0.9 * fade))
	for light_index in range(3):
		draw_circle(title_rect.position + Vector2(title_rect.size.x - 13.0 - light_index * 10.0, 12.0), 2.2, Color(accent, (0.28 + light_index * 0.16) * fade))
	draw_terminal_content(terminal_rect, accent, fade, glitch_strength)
	draw_crt_scanlines(terminal_rect, accent, fade)
	draw_crt_vignette(terminal_rect, fade)
	pass


func draw_terminal_content(rect: Rect2, accent: Color, fade: float, glitch_strength: float) -> void:
	# The top half belongs to streamed reasoning/answer text. The lower command card mirrors
	# playing_call, which remains populated during RESULT_HOLD_SECONDS so OK/ERR is readable.
	var font := Fonts.regular()
	var font_size := Typography.body_small_size
	var text_origin := rect.position + Vector2(12.0, 45.0)
	var status := "THINK" if stream_kind == OpenAiClient.STREAM_KIND_REASONING else "STREAM"
	# Twenty-four glyphs keeps CJK streams readable instead of relying on Latin-width clipping.
	var lines := terminal_display_lines(stream_buffer, 24, 2)
	var cursor_on := fmod(elapsed, 0.8) < 0.52
	draw_string(Fonts.semibold(), text_origin, "[%s]" % status, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(accent, 0.92 * fade))
	draw_string(font, text_origin + Vector2(0.0, 18.0), lines[0], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, font_size, Color(accent, 0.76 * fade))
	draw_string(font, text_origin + Vector2(0.0, 35.0), "%s%s" % [lines[1], "▋" if cursor_on else " "], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, font_size, Color(accent, 0.86 * fade))
	var card_rect := Rect2(rect.position + Vector2(10.0, 92.0), Vector2(rect.size.x - 20.0, 66.0))
	var card_color := ColorBase.error if glitch_strength > 0.0 else accent
	draw_rect(card_rect, Color(card_color, (0.08 + glitch_strength * 0.12) * fade))
	draw_rect(card_rect, Color(card_color, 0.48 * fade), false, 1.0)
	draw_string(Fonts.semibold(), card_rect.position + Vector2(9.0, 18.0), "$ %s" % current_tool_name(), HORIZONTAL_ALIGNMENT_LEFT, card_rect.size.x - 76.0, font_size, Color(card_color, 0.92 * fade))
	draw_string(Fonts.semibold(), card_rect.position + Vector2(-9.0, 18.0), current_tool_status(), HORIZONTAL_ALIGNMENT_RIGHT, card_rect.size.x, font_size, Color(card_color, 0.86 * fade))
	draw_line(card_rect.position + Vector2(9.0, 27.0), card_rect.position + Vector2(card_rect.size.x - 9.0, 27.0), Color(card_color, 0.24 * fade), 1.0)
	draw_string(font, card_rect.position + Vector2(9.0, 47.0), current_command_arguments(), HORIZONTAL_ALIGNMENT_LEFT, card_rect.size.x - 18.0, font_size, Color(ColorBase.primary_text, 0.82 * fade))
	if glitch_strength > 0.0:
		# These deterministic moving slices mimic horizontal sync loss without introducing
		# random state, which keeps previews and tests reproducible.
		for slice_index in range(3):
			var y := rect.position.y + 34.0 + fmod(elapsed * 173.0 + slice_index * 29.0, rect.size.y - 38.0)
			var offset := sin(elapsed * 83.0 + slice_index) * 12.0 * glitch_strength
			draw_line(Vector2(rect.position.x + offset, y), Vector2(rect.end.x + offset, y), Color(ColorBase.error, 0.48 * fade), 2.0 + slice_index, true)
	pass


func draw_crt_scanlines(rect: Rect2, accent: Color, fade: float) -> void:
	# Static low-alpha lines supply texture; one brighter sweep provides continuous motion.
	# Keep both subtle because they are drawn over text rather than clipped behind it.
	for line_index in range(9):
		var y := rect.position.y + 29.0 + float(line_index) * 16.0
		draw_line(Vector2(rect.position.x + 2.0, y), Vector2(rect.end.x - 2.0, y), Color(accent, 0.026 * fade), 1.0)
	var sweep_y := rect.position.y + 27.0 + fmod(elapsed * 38.0, rect.size.y - 30.0)
	draw_line(Vector2(rect.position.x + 2.0, sweep_y), Vector2(rect.end.x - 2.0, sweep_y), Color(accent, 0.13 * fade), 2.0)
	pass


func draw_crt_vignette(rect: Rect2, fade: float) -> void:
	# Layered top/bottom strips approximate curved glass without a shader or extra CanvasItem.
	for edge_index in range(4):
		var inset := float(edge_index) * 3.0
		var shade := Color(ColorBase.deep_surface, (0.22 - edge_index * 0.04) * fade)
		draw_rect(Rect2(rect.position + Vector2(inset, inset), Vector2(rect.size.x - inset * 2.0, 3.0)), shade)
		draw_rect(Rect2(Vector2(rect.position.x + inset, rect.end.y - inset - 3.0), Vector2(rect.size.x - inset * 2.0, 3.0)), shade)
	pass


func current_command_line() -> String:
	if playing_call.is_empty():
		return "idle --watch constellation"
	var name := String(playing_call["name"])
	var args: Dictionary[String, Variant] = playing_call["args"]
	var parts: PackedStringArray = PackedStringArray([name])
	for key: String in args.keys():
		parts.append("--%s=%s" % [key, short_argument(args[key])])
	return " ".join(parts).left(42)


func current_tool_name() -> String:
	if playing_call.is_empty():
		return "IDLE"
	return String(playing_call["name"]).to_upper()


func current_command_arguments() -> String:
	if playing_call.is_empty():
		return "watching constellation events..."
	var args: Dictionary[String, Variant] = playing_call["args"]
	if args.is_empty():
		return "no arguments"
	var parts := PackedStringArray()
	for key: String in args.keys():
		parts.append("%s: %s" % [key, short_argument(args[key])])
	return "  ".join(parts).left(45)


func current_tool_status() -> String:
	# active_calls is erased as soon as a result arrives, while playing_call is deliberately
	# held for the result card. Resolve state from the persistent node collection instead.
	if playing_call.is_empty():
		return "READY"
	var playing_id := String(playing_call["id"])
	for node: Dictionary in nodes:
		if String(node["id"]) != playing_id:
			continue
		var state: int = node["state"]
		if state == ExecutionState.FAILED:
			return "ERR"
		if state == ExecutionState.SUCCESS:
			return "OK"
	return "RUN"


static func short_argument(value: Variant) -> String:
	var text := str(value).replace("\n", " ").replace("\r", " ")
	return text.left(18) + ("..." if text.length() > 18 else "")


static func terminal_text(text: String) -> String:
	var clean := text.replace("\t", " ")
	return clean.right(STREAM_BUFFER_LIMIT)


static func terminal_display_lines(text: String, line_length: int, line_count: int) -> PackedStringArray:
	# Normalize arbitrary chunk boundaries and newlines into a stable terminal tail. Cropping
	# occurs before slicing so the newest streamed content always owns the visible display.
	var clean := " ".join(text.replace("\r", "").replace("\n", " ").split(" ", false)).strip_edges()
	if clean.is_empty():
		clean = "awaiting input..."
	var capacity := maxi(line_length, 1) * maxi(line_count, 1)
	clean = clean.right(capacity)
	var result := PackedStringArray()
	for line_index in range(maxi(line_count, 1)):
		result.append(clean.substr(line_index * line_length, line_length))
	while result.size() < 2:
		result.append("")
	return result


func draw_connection(node: Dictionary, center: Vector2, position: Vector2, fade: float) -> void:
	var growth: float = node["growth"]
	var state: int = node["state"]
	var accent := ThemeColor.accent_theme_color()
	var color := accent if state == ExecutionState.RUNNING else (ColorBase.success if state == ExecutionState.SUCCESS else ColorBase.error)
	var points := curved_path(center, position, int(node["sequence"]))
	var visible_points := partial_path(points, growth)
	if state == ExecutionState.FAILED:
		draw_broken_curve(visible_points, Color(color, 0.78 * fade))
		draw_failure_sparks(visible_points, color, fade)
	elif state == ExecutionState.RUNNING:
		draw_polyline(visible_points, Color(color, 0.04 * fade), 18.0, true)
		draw_polyline(visible_points, Color(color, 0.13 * fade), 8.0, true)
		draw_polyline(visible_points, Color(color, 0.68 * fade), 3.0, true)
	else:
		# Settled success stays quiet so the live call owns attention.
		draw_polyline(visible_points, Color(color, 0.02 * fade), 12.0, true)
		draw_polyline(visible_points, Color(color, 0.08 * fade), 2.0, true)
	if state == ExecutionState.RUNNING and growth > 0.1:
		for packet_index in range(PACKET_COUNT):
			var progress := fmod(elapsed * 0.55 + float(packet_index) / float(PACKET_COUNT), 1.0)
			draw_packet_streak(points, progress * growth, Color(accent, fade), true)
	elif state == ExecutionState.SUCCESS and float(node["settle"]) < 0.98:
		draw_packet_streak(points, 1.0 - clampf(float(node["settle"]), 0.0, 1.0), Color(ColorBase.success, fade), false)
	pass


func draw_packet_streak(points: PackedVector2Array, amount: float, color: Color, outbound: bool) -> void:
	var head := path_point(points, amount)
	var tail_amount := clampf(amount - (0.045 if outbound else -0.045), 0.0, 1.0)
	var tail := path_point(points, tail_amount)
	draw_line(tail, head, Color(color, 0.55), 3.4, true)
	draw_circle(head, 7.5, Color(color, 0.1))
	draw_circle(head, 3.4, Color(color, 0.95))
	pass


func draw_failure_sparks(points: PackedVector2Array, color: Color, fade: float) -> void:
	if points.size() < 4:
		return
	var mid := points[points.size() / 2]
	for spark in range(4):
		var angle := float(spark) * TAU / 4.0 + elapsed * 3.2
		var reach := 6.0 + fmod(elapsed * 22.0 + spark * 9.0, 10.0)
		draw_line(mid, mid + Vector2.from_angle(angle) * reach, Color(color, 0.55 * fade), 1.4, true)
	pass


func draw_tool_node(node: Dictionary, position: Vector2, center: Vector2, fade: float) -> void:
	var state: int = node["state"]
	var accent := ThemeColor.accent_theme_color()
	var state_color := accent if state == ExecutionState.RUNNING else (ColorBase.success if state == ExecutionState.SUCCESS else ColorBase.error)
	var growth: float = node["growth"]
	var node_radius := NODE_RADIUS * growth
	if state != ExecutionState.RUNNING:
		node_radius *= lerpf(1.0, 0.86, clampf(float(node["orbit"]) / 2.0, 0.0, 1.0))
	var highlight := radar_highlight(center, position)
	var shake := Vector2.ZERO
	if state == ExecutionState.FAILED and float(node["settle"]) < 0.85:
		shake = Vector2(sin(elapsed * 38.0), cos(elapsed * 31.0)) * (1.0 - float(node["settle"])) * 2.4
	position += shake
	var alpha := fade * lerpf(1.0, 0.55, clampf(float(node["orbit"]) * 0.35, 0.0, 1.0))
	if state == ExecutionState.RUNNING:
		draw_circle(position, node_radius + 11.0, Color(state_color, 0.14 * alpha))
		draw_circle(position, node_radius + 4.0, Color(state_color, 0.08 * alpha))
	elif highlight > 0.05:
		draw_circle(position, node_radius + 10.0, Color(accent, 0.06 * highlight * alpha))
	var hex := hexagon_points(position, node_radius)
	draw_colored_polygon(hex, Color(ColorBase.deep_surface, 0.97 * alpha))
	# Motif owns the hex interior; glyph sits above so letters and icons no longer fight.
	draw_family_motif(position, node_radius * 0.78, int(node["family"]), state_color, alpha * 0.88)
	var outline := PackedVector2Array(hex)
	outline.append(hex[0])
	if state == ExecutionState.FAILED:
		draw_broken_hex_outline(hex, Color(state_color, 0.9 * alpha), 2.6)
		draw_failure_mark(position, node_radius * 0.42, Color(state_color, 0.75 * alpha))
	elif state == ExecutionState.RUNNING:
		var pulse := 0.5 + 0.5 * sin(elapsed * 4.2)
		draw_polyline(outline, Color(state_color, (0.75 + pulse * 0.25) * alpha), 2.4 + pulse * 1.4, true)
	else:
		draw_polyline(outline, Color(state_color, 0.62 * alpha), 2.0, true)
	if state == ExecutionState.RUNNING:
		for satellite in range(3):
			var satellite_angle := elapsed * 1.35 + float(satellite) * TAU / 3.0 + float(node["sequence"])
			draw_circle(position + Vector2.from_angle(satellite_angle) * (node_radius + 15.0), 2.6, Color(state_color, 0.85 * alpha))
	draw_centered_text(position + Vector2(0.0, -node_radius - Margin.ma_2), VisualToolFormatter.glyph(String(node["name"])), Fonts.semibold(), Typography.label_small_size, Color(state_color, 0.85 * alpha))
	var label_position := position + Vector2(0.0, node_radius + Margin.ma_5)
	draw_centered_text(label_position, VisualToolFormatter.title_name(String(node["name"])), Fonts.semibold(), Typography.label_medium_size, Color(ColorBase.primary_text, alpha))
	if state == ExecutionState.RUNNING:
		draw_centered_text(label_position + Vector2(0.0, Margin.ma_4), I18n.t("agent.visuals.running"), Fonts.medium(), Typography.label_small_size, Color(state_color, 0.9 * alpha))
		if int(node["arg_count"]) > 0:
			draw_centered_text(label_position + Vector2(0.0, Margin.ma_8), StringUtils.format(I18n.t("agent.visuals.args"), int(node["arg_count"])), Fonts.regular(), Typography.label_small_size, Color(ColorBase.secondary_text, alpha))
	elif state == ExecutionState.FAILED:
		draw_centered_text(label_position + Vector2(0.0, Margin.ma_4), I18n.t("agent.visuals.failed"), Fonts.medium(), Typography.label_small_size, Color(state_color, 0.9 * alpha))
	pass


func draw_broken_hex_outline(hex: PackedVector2Array, color: Color, width: float) -> void:
	for index in range(6):
		var from := hex[index]
		var to := hex[(index + 1) % 6]
		draw_line(from, from.lerp(to, 0.32), color, width, true)
		draw_line(to.lerp(from, 0.32), to, color, width, true)
	pass


func draw_failure_mark(center: Vector2, reach: float, color: Color) -> void:
	var flash := 0.65 + 0.35 * sin(elapsed * 7.0)
	draw_line(center + Vector2(-reach, -reach), center + Vector2(reach, reach), Color(color, flash), 2.0, true)
	draw_line(center + Vector2(reach, -reach), center + Vector2(-reach, reach), Color(color, flash), 2.0, true)
	pass


func draw_family_motif(center: Vector2, radius: float, family: int, color: Color, alpha: float) -> void:
	match family:
		ToolFamily.READ:
			for line in range(3):
				var y := center.y - radius * 0.45 + float(line) * radius * 0.45
				draw_line(Vector2(center.x - radius * 0.55, y), Vector2(center.x + radius * 0.55, y), Color(color, alpha), 1.2, true)
		ToolFamily.WRITE:
			draw_line(center + Vector2(-radius * 0.45, radius * 0.35), center + Vector2(radius * 0.2, -radius * 0.45), Color(color, alpha), 1.6, true)
			draw_line(center + Vector2(radius * 0.05, -radius * 0.35), center + Vector2(radius * 0.45, -radius * 0.15), Color(color, alpha), 1.4, true)
		ToolFamily.SEARCH:
			draw_arc(center + Vector2(-radius * 0.1, -radius * 0.05), radius * 0.42, 0.0, TAU, 28, Color(color, alpha), 1.5, true)
			draw_line(center + Vector2(radius * 0.18, radius * 0.18), center + Vector2(radius * 0.55, radius * 0.55), Color(color, alpha), 1.8, true)
		ToolFamily.SHELL:
			draw_line(center + Vector2(-radius * 0.4, -radius * 0.15), center + Vector2(-radius * 0.05, 0.0), Color(color, alpha), 1.6, true)
			draw_line(center + Vector2(-radius * 0.05, 0.0), center + Vector2(-radius * 0.4, radius * 0.15), Color(color, alpha), 1.6, true)
			draw_line(center + Vector2(0.0, radius * 0.28), center + Vector2(radius * 0.45, radius * 0.28), Color(color, alpha), 1.5, true)
		ToolFamily.WEB:
			draw_arc(center, radius * 0.55, 0.0, TAU, 32, Color(color, alpha), 1.3, true)
			draw_line(center + Vector2(0.0, -radius * 0.55), center + Vector2(0.0, radius * 0.55), Color(color, alpha * 0.85), 1.1, true)
			draw_line(center + Vector2(-radius * 0.55, 0.0), center + Vector2(radius * 0.55, 0.0), Color(color, alpha * 0.85), 1.1, true)
		ToolFamily.IMAGE:
			draw_rect(Rect2(center - Vector2(radius * 0.5, radius * 0.35), Vector2(radius, radius * 0.7)), Color(color, alpha * 0.35), false, 1.3)
			draw_circle(center + Vector2(-radius * 0.18, -radius * 0.08), radius * 0.12, Color(color, alpha))
			draw_line(center + Vector2(-radius * 0.35, radius * 0.22), center + Vector2(0.0, -radius * 0.05), Color(color, alpha), 1.3, true)
			draw_line(center + Vector2(0.0, -radius * 0.05), center + Vector2(radius * 0.4, radius * 0.25), Color(color, alpha), 1.3, true)
		ToolFamily.AUDIO:
			for bar in range(4):
				var x := center.x - radius * 0.45 + float(bar) * radius * 0.3
				var height := radius * (0.25 + 0.35 * absf(sin(elapsed * 4.0 + bar)))
				draw_line(Vector2(x, center.y + height * 0.5), Vector2(x, center.y - height * 0.5), Color(color, alpha), 2.0, true)
		_:
			draw_circle(center, radius * 0.18, Color(color, alpha * 0.7))
	pass


func draw_completion_dust(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color() if not ended_with_error else ColorBase.error
	var ease := completion * completion
	for index in range(DUST_COUNT):
		var angle := float(index) * GOLDEN_ANGLE + elapsed * 0.2
		var distance := (40.0 + float(index % 17) * 18.0) * (0.35 + ease * 1.4)
		var position := center + Vector2.from_angle(angle) * distance
		var alpha := (1.0 - ease) * (0.15 + float(index % 4) * 0.08)
		draw_circle(position, 1.2 + float(index % 3) * 0.7, Color(accent, alpha))
	for index in range(nodes.size()):
		var node_pos := node_position(index, nodes.size(), center)
		var outward := (node_pos - center).normalized()
		var dust_pos := node_pos + outward * ease * 48.0
		draw_circle(dust_pos, 2.4 * (1.0 - ease), Color(accent, (1.0 - ease) * 0.45))
	pass


func draw_broken_curve(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 4:
		return
	var broken := PackedVector2Array(points)
	var midpoint_index := points.size() / 2
	for index in range(midpoint_index - 2, midpoint_index + 2):
		broken[index] += (points[index] - points[index - 1]).normalized().orthogonal() * (8.0 if index % 2 else -8.0)
	draw_polyline(broken, Color(color, 0.1), 12.0, true)
	draw_polyline(broken, color, 3.0, true)
	pass


func node_position(index: int, _count: int, center: Vector2) -> Vector2:
	var angle := -PI * 0.5 + float(index) * GOLDEN_ANGLE
	var orbit := float(nodes[index]["orbit"]) if index < nodes.size() else float(index % 3)
	var radius := orbit_radius(orbit)
	# Tiny angular drift keeps packed slots from reading as a rigid dial.
	angle += sin(elapsed * 0.35 + float(index)) * 0.018
	var squash := clampf(size.y / maxf(size.x, 1.0) * 1.25, 0.7, 0.94)
	return center + Vector2(cos(angle) * radius, sin(angle) * radius * squash)


func orbit_radius(orbit: float) -> float:
	var available := minf(size.x, size.y)
	# The former circular core only needed CORE_RADIUS clearance. The wider CRT requires a
	# horizontal safety radius that also includes one tool node and a shared spacing token.
	var terminal_clearance := TERMINAL_SIZE.x * 0.5 + NODE_RADIUS + Margin.ma_8
	var inner := minf(maxf(available * 0.18, terminal_clearance), 230.0)
	var step := minf(minf(size.x, size.y) * 0.125, 108.0)
	return inner + orbit * step


## One ring at a time: expand inside→out, collapse outside→in.
func layer_spread(layer_from_inside: int, layer_count: int) -> float:
	var index := clampi(layer_from_inside, 1, layer_count) - 1
	var count := float(maxi(layer_count, 1))
	var slot := 1.0 / count
	# Tiny overlap keeps the handoff from reading as a hard cut.
	var span := slot * 1.12
	if completing:
		var collapse := 1.0 - field_spread
		var start := float(layer_count - 1 - index) * slot
		var done := clampf((collapse - start) / span, 0.0, 1.0)
		var remain := 1.0 - done
		return remain * remain * (3.0 - 2.0 * remain)
	var start := float(index) * slot
	var local := clampf((field_spread - start) / span, 0.0, 1.0)
	return local * local * (3.0 - 2.0 * local)


func target_orbit_for(node: Dictionary) -> float:
	if int(node["state"]) == ExecutionState.RUNNING:
		return 0.0
	var age := spawn_sequence - int(node["sequence"])
	return 2.0 if age > 10 else 1.0


func radar_head() -> float:
	return elapsed * 0.34


func radar_highlight(center: Vector2, position: Vector2) -> float:
	var delta_angle := absf(wrapf((position - center).angle() - radar_head(), -PI, PI))
	return clampf(1.0 - delta_angle / 0.32, 0.0, 1.0)


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


func oldest_settled_node_index() -> int:
	var replace_index := 0
	var oldest_sequence := 0
	var found := false
	for index in range(nodes.size()):
		if int(nodes[index]["state"]) == ExecutionState.RUNNING:
			continue
		var sequence: int = nodes[index]["sequence"]
		if not found or sequence < oldest_sequence:
			replace_index = index
			oldest_sequence = sequence
			found = true
	return replace_index


static func tool_family(tool_name: String) -> int:
	var normalized := tool_name.to_lower()
	if "image" in normalized or "vision" in normalized or "screenshot" in normalized:
		return ToolFamily.IMAGE
	if "audio" in normalized or "speech" in normalized or "voice" in normalized or "transcri" in normalized:
		return ToolFamily.AUDIO
	if "web" in normalized or "fetch" in normalized or "http" in normalized:
		return ToolFamily.WEB
	if "read" in normalized or "list" in normalized or "glob" in normalized:
		return ToolFamily.READ
	if "write" in normalized or "edit" in normalized or "create" in normalized:
		return ToolFamily.WRITE
	if "search" in normalized or "find" in normalized or "grep" in normalized:
		return ToolFamily.SEARCH
	if "shell" in normalized or "bash" in normalized or "exec" in normalized or "terminal" in normalized:
		return ToolFamily.SHELL
	return ToolFamily.GENERIC


static func make_node(tool_call_id: String, tool_name: String, args: Dictionary[String, Variant], sequence: int, turn: int) -> Dictionary:
	return {
		"id": tool_call_id,
		"name": tool_name,
		"arg_count": args.size(),
		"sequence": sequence,
		"turn": turn,
		"family": tool_family(tool_name),
		"state": ExecutionState.RUNNING,
		"growth": 0.0,
		"settle": 0.0,
		"orbit": 0.0,
	}
