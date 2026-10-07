class_name ContextMemoryRiver
extends VisualEffect

## A living context map: source material flows into the model, older items recede,
## and generated content leaves through the output channel.

const MAX_ITEMS := 256
const PARTICLE_SPEED := 0.19
const DEFAULT_CONTEXT_LIMIT := 128_000
const ABSORPTION_DURATION := 0.62

enum StreamType { USER, SYSTEM, HISTORY, FILE, TOOL, REASONING, ANSWER }

var items: Array[Dictionary] = []
var absorption_effects: Array[Dictionary] = []
var elapsed: float = 0.0
var turn_index: int = 0
var prompt_tokens: int = 0
var completion_tokens: int = 0
var context_limit: int = DEFAULT_CONTEXT_LIMIT
var activity: float = 0.0
var visual_activity: float = 0.0
var output_activity: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.CONTEXT_MEMORY_RIVER


func fade_in_seconds() -> float:
	return 0.35


func fade_out_seconds() -> float:
	return 0.45


func reset_visual() -> void:
	items.clear()
	absorption_effects.clear()
	elapsed = 0.0
	turn_index = 0
	prompt_tokens = 0
	completion_tokens = 0
	activity = 0.0
	visual_activity = 0.0
	output_activity = 0.0
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	activity = 1.0
	queue_redraw()
	pass


func on_agent_end(error_message: String) -> void:
	add_item(StreamType.ANSWER, I18n.t("agent.visuals.error") if StringUtils.is_not_blank(error_message) else I18n.t("agent.visuals.answer"), 0.72)
	output_activity = 1.0
	if is_inside_tree():
		await get_tree().create_timer(0.6).timeout
	pass


func on_turn_start() -> void:
	turn_index += 1
	activity = 1.0
	pass


func on_turn_end() -> void:
	output_activity = maxf(output_activity, 0.6)
	pass


func on_chat_entry_add(entry: ChatEntry) -> void:
	var stream_type := stream_type_for_entry(entry)
	if stream_type < 0:
		return
	add_item(stream_type as StreamType, label_for_type(stream_type as StreamType), weight_for_text(entry.body))
	pass


func on_message_update(chunk: String, stream_kind: String) -> void:
	var stream_type := StreamType.REASONING if stream_kind == OpenAiClient.STREAM_KIND_REASONING else StreamType.ANSWER
	add_item(stream_type, I18n.t("agent.visuals.thought") if stream_type == StreamType.REASONING else I18n.t("agent.visuals.answer"), weight_for_text(chunk))
	if stream_type == StreamType.ANSWER:
		output_activity = 1.0
	else:
		activity = 1.0
	pass


func on_message_complete(usage: OpenAiUsage) -> void:
	prompt_tokens = maxi(usage.prompt_tokens, 0)
	completion_tokens = maxi(usage.completion_tokens, 0)
	# Keep the gauge meaningful for providers whose actual context limit is unknown.
	while prompt_tokens > context_limit:
		context_limit *= 2
	activity = 1.0
	queue_redraw()
	pass


func on_tool_execution_start(_tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	add_item(StreamType.TOOL, public_label(tool_name), 0.7)
	activity = 1.0
	pass


func on_tool_execution_end(_tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var stream_type := StreamType.FILE if tool_name.to_lower().contains("read") else StreamType.TOOL
	add_item(stream_type, I18n.t("agent.visuals.file") if stream_type == StreamType.FILE else I18n.t("agent.visuals.result"), 0.82 if not result.is_error else 0.45)
	activity = 1.0
	pass


func on_theme_changed() -> void:
	queue_redraw()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	activity = move_toward(activity, 0.0, delta * 0.75)
	# Event activity is discontinuous; use an exponential follower so drawing never jumps.
	var activity_follow := 1.0 - exp(-delta * (5.0 if activity > visual_activity else 2.2))
	visual_activity = lerpf(visual_activity, activity, activity_follow)
	output_activity = move_toward(output_activity, 0.0, delta * 0.65)
	for index in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[index]
		var next_progress := float(item["progress"]) + delta * PARTICLE_SPEED * float(item["speed"])
		var input_x := lerpf(-50.0, size.x * 0.5, next_progress)
		# Convert incoming packets at the visible outer ring instead of letting them
		# fade in front of the context window. The position-based threshold keeps the
		# collision stable when the control is resized.
		if item["type"] as StreamType != StreamType.ANSWER and input_x >= size.x * 0.5 - 94.0:
			add_absorption_effect(item)
			items.remove_at(index)
			activity = 1.0
			continue
		if next_progress >= 1.0:
			items.remove_at(index)
			continue
		item["progress"] = next_progress
		item["pulse"] = move_toward(float(item["pulse"]), 0.0, delta)
	for index in range(absorption_effects.size() - 1, -1, -1):
		var effect: Dictionary = absorption_effects[index]
		effect["age"] = float(effect["age"]) + delta
		if float(effect["age"]) >= ABSORPTION_DURATION:
			absorption_effects.remove_at(index)
	queue_redraw()
	pass


## Captures the minimum packet state needed by the short-lived intake animation.
## Keeping this separate from items prevents an absorbed packet from being drawn twice.
func add_absorption_effect(item: Dictionary) -> void:
	absorption_effects.append({
		"age": 0.0,
		"color": color_for_type(item["type"] as StreamType),
		"lane": float(item["lane"]),
		"weight": float(item["weight"]),
	})
	pass


func add_item(stream_type: StreamType, label: String, weight: float) -> void:
	# Never evict a packet that is visibly in transit. At saturation, wait for an
	# existing packet to reach its destination before admitting another one.
	if items.size() >= MAX_ITEMS:
		return
	items.append({
		"type": stream_type,
		"label": label,
		"weight": clampf(weight, 0.25, 1.0),
		"progress": 0.0,
		"speed": 0.82 + float(items.size() % 5) * 0.08,
		"lane": (items.size() % 7) - 3,
		"turn": turn_index,
		"pulse": 1.0,
	})
	queue_redraw()
	pass


func _draw() -> void:
	if size.x < 320.0 or size.y < 220.0:
		return
	var center := size * 0.5
	draw_river(center)
	for item: Dictionary in items:
		draw_item(item, center)
	# Draw the collapse below the opaque context body so the packet appears to
	# enter it; draw_context_window adds the corresponding visible core flash.
	draw_absorption_effects(center)
	draw_context_window(center)
	draw_output(center)
	pass


## Pulls each incoming packet from the left edge of the context ring into its
## core, while a type-colored ripple preserves the packet's source identity.
func draw_absorption_effects(center: Vector2) -> void:
	for effect: Dictionary in absorption_effects:
		var phase := clampf(float(effect["age"]) / ABSORPTION_DURATION, 0.0, 1.0)
		var color: Color = effect["color"]
		var weight: float = effect["weight"]
		var lane_y := float(effect["lane"]) * 8.0
		var impact_position := center + Vector2(-94.0, lane_y)
		var collapse := smoothstep(0.0, 0.55, phase)
		var particle_position := impact_position.lerp(center, collapse)
		var particle_alpha := 1.0 - smoothstep(0.38, 0.72, phase)
		var particle_radius := lerpf(7.0 + weight * 5.0, 2.0, collapse)
		draw_line(impact_position, particle_position, Color(color, particle_alpha * 0.28), 2.0 + weight * 2.0, true)
		draw_circle(particle_position, particle_radius * 2.2, Color(color, particle_alpha * 0.12))
		draw_circle(particle_position, particle_radius, Color(color, particle_alpha * 0.92))
		var ripple_phase := clampf(phase / 0.82, 0.0, 1.0)
		var ripple_radius := lerpf(78.0, 126.0, ripple_phase)
		var ripple_alpha := (1.0 - ripple_phase) * 0.24
		draw_arc(center, ripple_radius, 0.0, TAU, 80, Color(color, ripple_alpha), 2.4 - ripple_phase, true)
	pass


func draw_river(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	var left := Vector2(-40.0, center.y)
	var right := Vector2(size.x + 40.0, center.y)
	# Soft banks give the stream a readable silhouette without turning it into a panel.
	var bank_half_height := 82.0
	for bank_offset in [-bank_half_height, bank_half_height]:
		var bank_points := PackedVector2Array()
		for step in range(41):
			var x := float(step) / 40.0 * size.x
			var wave := sin(x * 0.006 + elapsed * 0.35) * 9.0
			bank_points.append(Vector2(x, center.y + bank_offset + wave))
		draw_polyline(bank_points, Color(accent, 0.2), 1.2, true)
	for band in range(7, 0, -1):
		var alpha := 0.012 + float(7 - band) * 0.007
		draw_line(left, right, Color(accent, alpha), 34.0 + band * 18.0, true)
	for lane in range(-3, 4):
		var wave_points := PackedVector2Array()
		for step in range(41):
			var x := float(step) / 40.0 * size.x
			var lane_distance := absf(float(lane))
			var y: float = center.y + lane * 18.0 + sin(x * 0.008 + elapsed * (0.55 + lane_distance * 0.04) + lane) * (7.0 + lane_distance * 2.0)
			wave_points.append(Vector2(x, y))
		draw_polyline(wave_points, Color(accent, 0.1 + visual_activity * 0.08), 1.4, true)
	# Converging guide lines make the context window read as an intake rather than an overlay.
	for side in [-1.0, 1.0]:
		var intake := PackedVector2Array([
			Vector2(0.0, center.y + side * bank_half_height),
			Vector2(center.x * 0.58, center.y + side * 54.0),
			Vector2(center.x - 82.0, center.y + side * 22.0),
		])
		draw_polyline(intake, Color(accent, 0.12 + visual_activity * 0.08), 2.0, true)
	pass


func draw_item(item: Dictionary, center: Vector2) -> void:
	var progress: float = item["progress"]
	var stream_type: StreamType = item["type"]
	var is_output := stream_type == StreamType.ANSWER
	var local_progress := progress if not is_output else 1.0 - progress
	var x := lerpf(-50.0, center.x, local_progress) if not is_output else lerpf(size.x + 50.0, center.x, local_progress)
	var lane: int = item["lane"]
	var lane_offset := lane * 19.0 + sin(progress * TAU * 1.5 + lane + elapsed) * 8.0
	var convergence := smoothstep(0.48, 1.0, progress)
	var y := center.y + lane_offset * (1.0 - convergence if not is_output else 0.42 + progress * 0.58)
	var position := Vector2(x, y)
	var color := color_for_type(stream_type)
	var weight: float = item["weight"]
	var radius := 5.0 + weight * 7.0
	var edge_fade := 1.0 - smoothstep(0.86, 1.0, progress)
	for trail_index in range(3, 0, -1):
		var trail_direction := 1.0 if is_output else -1.0
		var trail_position := position + Vector2(trail_direction * trail_index * 9.0, 0.0)
		draw_circle(trail_position, radius * (1.0 - trail_index * 0.18), Color(color, edge_fade * (0.13 - trail_index * 0.025)))
	draw_circle(position, radius * 2.1, Color(color, edge_fade * (0.05 + float(item["pulse"]) * 0.08)))
	draw_circle(position, radius, Color(color, edge_fade * 0.82))
	draw_circle(position - Vector2(radius * 0.28, radius * 0.28), radius * 0.32, Color(1.0, 1.0, 1.0, edge_fade * 0.62))
	var label_is_clear := progress > 0.12 and progress < 0.72 and x > 54.0 and x < size.x - 54.0
	if radius > 9.0 and label_is_clear and float(item["pulse"]) > 0.15:
		draw_centered_text(position + Vector2(0.0, radius + 14.0), String(item["label"]), Fonts.medium(), Typography.label_small_size, Color(color, edge_fade * 0.82))
	pass


func draw_context_window(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	var absorption := absorption_activity()
	# The body breathes slowly while the capacity gauge stays fixed and trustworthy.
	var breath_phase := sin(elapsed * TAU / 2.8)
	var breath := 0.5 + breath_phase * 0.5
	var gauge_radius := 80.0
	var body_radius := 72.0 + breath_phase * 1.8
	var ratio := context_ratio()
	var capacity_color := ColorBase.error if ratio >= 0.9 else (ColorBase.warning if ratio >= 0.72 else accent)
	for glow in range(4):
		var glow_radius := gauge_radius + 13.0 + glow * 11.0 + breath * (5.0 + glow * 1.5) + visual_activity * 5.0
		var glow_alpha := 0.032 - glow * 0.005 + breath * 0.012 + visual_activity * 0.014
		draw_circle(center, glow_radius + absorption * 6.0, Color(capacity_color, glow_alpha + absorption * 0.025))
	# A thin secondary wave gives the pulse a visible leading edge.
	var wave_radius := gauge_radius + 18.0 + breath * 24.0 + visual_activity * 7.0
	draw_arc(center, wave_radius, 0.0, TAU, 72, Color(capacity_color, (1.0 - breath) * 0.08 + visual_activity * 0.05), 1.4, true)
	draw_circle(center, body_radius + 3.0, Color(accent, 0.08 + breath * 0.035))
	draw_circle(center, body_radius, Color(ColorBase.deep_surface, 0.96))
	draw_arc(center, gauge_radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64, Color(capacity_color, 0.92), 3.2, true)
	draw_arc(center, gauge_radius, -PI * 0.5 + TAU * ratio, PI * 1.5, 64, Color(ColorBase.subtle_border, 0.38), 1.4, true)
	for tick in range(8):
		var angle := -PI * 0.5 + float(tick) * TAU / 8.0
		var tick_start := center + Vector2.from_angle(angle) * (gauge_radius + 6.0)
		var tick_end := center + Vector2.from_angle(angle) * (gauge_radius + 10.0)
		draw_line(tick_start, tick_end, Color(ColorBase.secondary_text, 0.28), 0.8, true)
	var core_radius := 10.5 + breath * 3.0 + visual_activity * 1.4 + absorption * 4.0
	draw_circle(center, core_radius * 1.75, Color(accent, 0.035 + breath * 0.025 + absorption * 0.08))
	draw_circle(center, core_radius, Color(accent, 0.62 + breath * 0.2 + absorption * 0.18))
	draw_circle(center - Vector2(core_radius * 0.24, core_radius * 0.24), core_radius * 0.25, Color(1.0, 1.0, 1.0, 0.16 + breath * 0.12))
	draw_centered_text(center + Vector2(0.0, 30.0), I18n.t("agent.visuals.context"), Fonts.semibold(), Typography.label_medium_size, ColorBase.primary_text)
	draw_centered_text(center + Vector2(0.0, 48.0), token_label(), Fonts.regular(), Typography.label_small_size, Color(capacity_color, 0.9))
	pass


## Combines overlapping intake events into one bounded core response. The clamp
## avoids a distracting flash when several packets arrive in the same frame.
func absorption_activity() -> float:
	var intensity := 0.0
	for effect: Dictionary in absorption_effects:
		var phase := clampf(float(effect["age"]) / ABSORPTION_DURATION, 0.0, 1.0)
		var pulse := sin(clampf(phase / 0.62, 0.0, 1.0) * PI) * (1.0 - smoothstep(0.68, 1.0, phase))
		intensity += pulse * (0.55 + float(effect["weight"]) * 0.45)
	return clampf(intensity, 0.0, 1.0)


## Answer-colored particles alone communicate generated output. Deliberately do
## not add a solid channel, glow band, or text label here: those compete with the
## river and duplicate information already carried by the particle color.
func draw_output(center: Vector2) -> void:
	var answer := color_for_type(StreamType.ANSWER)
	var alpha := 0.28 + output_activity * 0.48
	var stream_start := center.x + 82.0
	for index in range(4):
		var progress := fmod(elapsed * 0.3 + index * 0.25, 1.0)
		var particle_fade := 1.0 - smoothstep(0.72, 1.0, progress)
		var position := Vector2(lerpf(stream_start + 8.0, size.x, progress), center.y + sin(progress * TAU * 1.8 + index) * (5.0 + progress * 8.0))
		draw_circle(position, 3.0 + output_activity * 2.0, Color(answer, alpha * particle_fade))
	pass


func context_ratio() -> float:
	return clampf(float(prompt_tokens) / float(maxi(context_limit, 1)), 0.0, 1.0)


func token_label() -> String:
	if prompt_tokens <= 0:
		return I18n.t("agent.visuals.awaiting_tokens")
	return "%s / %s" % [compact_number(prompt_tokens), compact_number(context_limit)]


static func compact_number(value: int) -> String:
	if value >= 1000:
		return "%.1fK" % (float(value) / 1000.0)
	return str(value)


static func weight_for_text(text: String) -> float:
	return clampf(0.3 + float(text.length()) / 240.0, 0.3, 1.0)


static func stream_type_for_entry(entry: ChatEntry) -> int:
	match entry.kind:
		ChatEntry.KIND_USER:
			return StreamType.USER
		ChatEntry.KIND_SYSTEM, ChatEntry.KIND_SKILL, ChatEntry.KIND_AGENT_PROMPT:
			return StreamType.SYSTEM
		ChatEntry.KIND_FILE_TOOL:
			return StreamType.FILE
		ChatEntry.KIND_TOOL, ChatEntry.KIND_RESULT:
			return StreamType.TOOL
		ChatEntry.KIND_AGENT, ChatEntry.KIND_THINKING:
			return StreamType.HISTORY
	return -1


static func label_for_type(stream_type: StreamType) -> String:
	match stream_type:
		StreamType.USER:
			return I18n.t("agent.visuals.user")
		StreamType.SYSTEM:
			return I18n.t("agent.visuals.system")
		StreamType.FILE:
			return I18n.t("agent.visuals.file")
		StreamType.TOOL:
			return I18n.t("agent.visuals.tool")
		StreamType.REASONING:
			return I18n.t("agent.visuals.thought")
		StreamType.ANSWER:
			return I18n.t("agent.visuals.answer")
	return I18n.t("agent.visuals.history")


static func color_for_type(stream_type: StreamType) -> Color:
	match stream_type:
		StreamType.USER:
			return Color("59c8ff")
		StreamType.SYSTEM:
			return Color("b894ff")
		StreamType.FILE:
			return Color("5ee6a8")
		StreamType.TOOL:
			return Color("ffb75e")
		StreamType.REASONING:
			return Color("e98cff")
		StreamType.ANSWER:
			return Color("67f0dd")
	return Color("7e91ae")


static func public_label(tool_name: String) -> String:
	return StringUtils.truncate(VisualToolFormatter.readable_name(tool_name).to_upper(), 14)
