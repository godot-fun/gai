class_name ContextMemoryRiver
extends VisualEffect

## A living context map: source material flows into the model, old items crystallize,
## and generated content leaves through the output channel.

const MAX_ITEMS := 28
const PARTICLE_SPEED := 0.19
const DEFAULT_CONTEXT_LIMIT := 128_000

enum StreamType { USER, SYSTEM, HISTORY, FILE, TOOL, REASONING, ANSWER }

var items: Array[Dictionary] = []
var elapsed: float = 0.0
var turn_index: int = 0
var prompt_tokens: int = 0
var completion_tokens: int = 0
var context_limit: int = DEFAULT_CONTEXT_LIMIT
var activity: float = 0.0
var output_activity: float = 0.0
var fade_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.CONTEXT_MEMORY_RIVER


func set_visual_visible(show: bool, animated: bool) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	if show:
		visible = true
		modulate.a = 0.0 if animated else 1.0
		if animated:
			fade_tween = create_tween()
			fade_tween.tween_property(self, "modulate:a", 1.0, 0.35)
		return
	if not animated:
		visible = false
		modulate.a = 1.0
		return
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.45)
	fade_tween.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
	)
	pass


func reset_visual() -> void:
	items.clear()
	elapsed = 0.0
	turn_index = 0
	prompt_tokens = 0
	completion_tokens = 0
	activity = 0.0
	output_activity = 0.0
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	activity = 1.0
	queue_redraw()
	pass


func on_agent_end(error_message: String) -> float:
	add_item(StreamType.ANSWER, "ERROR" if StringUtils.is_not_blank(error_message) else "ANSWER", 0.72)
	output_activity = 1.0
	return 0.6


func on_turn_start() -> void:
	turn_index += 1
	age_context()
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
	add_item(stream_type, "THOUGHT" if stream_type == StreamType.REASONING else "ANSWER", weight_for_text(chunk))
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
	add_item(stream_type, "FILE" if stream_type == StreamType.FILE else "RESULT", 0.82 if not result.is_error else 0.45)
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
	output_activity = move_toward(output_activity, 0.0, delta * 0.65)
	for item: Dictionary in items:
		item["progress"] = minf(float(item["progress"]) + delta * PARTICLE_SPEED * float(item["speed"]), 1.0)
		item["pulse"] = move_toward(float(item["pulse"]), 0.0, delta)
	queue_redraw()
	pass


func add_item(stream_type: StreamType, label: String, weight: float) -> void:
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
	if items.size() > MAX_ITEMS:
		items.pop_front()
	queue_redraw()
	pass


func age_context() -> void:
	for index in range(items.size() - 1, -1, -1):
		if turn_index - int(items[index]["turn"]) < 3:
			continue
		items.remove_at(index)
	pass


func _draw() -> void:
	if size.x < 320.0 or size.y < 220.0:
		return
	var center := size * 0.5
	draw_river(center)
	for item: Dictionary in items:
		draw_item(item, center)
	draw_context_window(center)
	draw_output(center)
	pass


func draw_river(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	var left := Vector2(-40.0, center.y)
	var right := Vector2(size.x + 40.0, center.y)
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
		draw_polyline(wave_points, Color(accent, 0.1 + activity * 0.08), 1.4, true)
	pass


func draw_item(item: Dictionary, center: Vector2) -> void:
	var progress: float = item["progress"]
	var stream_type: StreamType = item["type"]
	var is_output := stream_type == StreamType.ANSWER
	var local_progress := progress if not is_output else 1.0 - progress
	var x := lerpf(-50.0, center.x, local_progress) if not is_output else lerpf(size.x + 50.0, center.x, local_progress)
	var lane: int = item["lane"]
	var y := center.y + lane * 19.0 + sin(progress * TAU * 1.5 + lane + elapsed) * 8.0
	var position := Vector2(x, y)
	var color := color_for_type(stream_type)
	var weight: float = item["weight"]
	var radius := 5.0 + weight * 7.0
	draw_circle(position, radius * 2.1, Color(color, 0.05 + float(item["pulse"]) * 0.08))
	draw_circle(position, radius, Color(color, 0.82))
	draw_circle(position - Vector2(radius * 0.28, radius * 0.28), radius * 0.32, Color.WHITE * Color(1.0, 1.0, 1.0, 0.62))
	if radius > 9.0:
		draw_centered_text(position + Vector2(0.0, radius + 14.0), String(item["label"]), Fonts.medium(), Typography.label_small_size, Color(color, 0.82))
	pass


func draw_context_window(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	var breath := 0.5 + sin(elapsed * 2.2) * 0.5
	var radius := 72.0
	for glow in range(4):
		draw_circle(center, radius + 12.0 + glow * 10.0, Color(accent, 0.035 - glow * 0.006 + activity * 0.012))
	draw_circle(center, radius, Color(ColorBase.deep_surface, 0.96))
	draw_arc(center, radius + 8.0, -PI * 0.5, -PI * 0.5 + TAU * context_ratio(), 64, Color(accent, 0.92), 6.0, true)
	draw_arc(center, radius + 8.0, -PI * 0.5 + TAU * context_ratio(), PI * 1.5, 64, Color(ColorBase.subtle_border, 0.42), 3.0, true)
	draw_circle(center, 11.0 + breath * 3.0 + activity * 4.0, Color(accent, 0.72))
	draw_centered_text(center + Vector2(0.0, 30.0), "CONTEXT", Fonts.semibold(), Typography.label_medium_size, ColorBase.primary_text)
	draw_centered_text(center + Vector2(0.0, 48.0), token_label(), Fonts.regular(), Typography.label_small_size, Color(accent, 0.9))
	pass


func draw_output(center: Vector2) -> void:
	var answer := color_for_type(StreamType.ANSWER)
	var x := center.x + minf(size.x * 0.29, 350.0)
	var alpha := 0.28 + output_activity * 0.48
	draw_line(Vector2(center.x + 86.0, center.y), Vector2(size.x, center.y), Color(answer, alpha * 0.22), 14.0, true)
	for index in range(4):
		var progress := fmod(elapsed * 0.3 + index * 0.25, 1.0)
		var position := Vector2(lerpf(center.x + 90.0, size.x, progress), center.y + sin(progress * TAU + index) * 13.0)
		draw_circle(position, 3.0 + output_activity * 2.0, Color(answer, alpha))
	draw_centered_text(Vector2(x, center.y - 42.0), "GENERATED RESPONSE", Fonts.semibold(), Typography.label_small_size, Color(answer, 0.75))
	pass


func context_ratio() -> float:
	return clampf(float(prompt_tokens) / float(maxi(context_limit, 1)), 0.0, 1.0)


func token_label() -> String:
	if prompt_tokens <= 0:
		return "AWAITING TOKENS"
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
			return "USER"
		StreamType.SYSTEM:
			return "SYSTEM"
		StreamType.FILE:
			return "FILE"
		StreamType.TOOL:
			return "TOOL"
		StreamType.REASONING:
			return "THOUGHT"
		StreamType.ANSWER:
			return "ANSWER"
	return "HISTORY"


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
	var words := tool_name.replace("_", " ").replace("-", " ").strip_edges()
	return StringUtils.truncate(words.to_upper(), 14)


func draw_centered_text(position: Vector2, text: String, font: Font, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, position - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	pass
