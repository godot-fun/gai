class_name ContextMemoryRiver
extends VisualEffect

## A living context map: source material flows into the model, older items recede,
## and generated content leaves through the output channel.

const MAX_ITEMS := 96
const PARTICLE_SPEED := 0.19
const DEFAULT_CONTEXT_LIMIT := 128_000
const ABSORPTION_DURATION := 0.62
# Output braids are cheap fixed curves; incoming text uses cached paths below.
const RIVER_SAMPLE_COUNT := 64
const TRAIL_SAMPLE_COUNT := 4
# Sample history by travelled screen distance rather than frame count. This keeps
# curve quality stable across frame rates and bounds memory per item.
const MAX_PATH_HISTORY_POINTS := 128
const PATH_HISTORY_STEP := 2.0
# Short phrases remain readable while keeping per-character draw calls bounded.
const MAX_FLOATING_TEXT_LENGTH := 18
const STREAM_COALESCE_PROGRESS := 0.2

enum StreamType { USER, SYSTEM, HISTORY, FILE, TOOL, REASONING, ANSWER }


class StreamItem extends RefCounted:
	# Event identity and visual weight remain fixed during flight.
	var stream_type: StreamType
	var label: String
	var weight: float
	var progress: float = 0.0
	var speed: float
	var lane: int
	var source_y_ratio: float
	var curve_direction: float
	var turn: int
	var pulse: float = 1.0
	# These arrays share indices. Points are oldest -> newest and distances are
	# monotonically increasing, so trimming the oldest pair requires no rebasing.
	var path_history := PackedVector2Array()
	var path_distances := PackedFloat32Array()
	# Font metrics are immutable for an item and expensive enough to cache once.
	var glyph_advances := PackedFloat32Array()
	var label_width: float = 0.0


class AbsorptionEffect extends RefCounted:
	# Lightweight snapshot detached from an item after it reaches the context ring.
	var age: float = 0.0
	var color: Color
	var label: String
	var lane: float
	var weight: float


var items: Array[StreamItem] = []
var absorption_effects: Array[AbsorptionEffect] = []
var elapsed: float = 0.0
var turn_index: int = 0
var spawn_index: int = 0
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
	spawn_index = 0
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
	var fallback := label_for_type(stream_type as StreamType)
	add_item(stream_type as StreamType, floating_text(entry.body, fallback), weight_for_text(entry.body))
	pass


func on_message_update(chunk: String, stream_kind: String) -> void:
	if chunk.strip_edges().is_empty():
		return
	var stream_type := StreamType.REASONING if stream_kind == OpenAiClient.STREAM_KIND_REASONING else StreamType.ANSWER
	var fallback := I18n.t("agent.visuals.thought") if stream_type == StreamType.REASONING else I18n.t("agent.visuals.answer")
	add_stream_fragment(stream_type, chunk, fallback)
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
	add_item(stream_type, public_label(tool_name), 0.82 if not result.is_error else 0.45)
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
	var center := size * 0.5
	for index in range(items.size() - 1, -1, -1):
		var item := items[index]
		var next_progress := item.progress + delta * PARTICLE_SPEED * item.speed
		var input_x := lerpf(-50.0, size.x * 0.5, next_progress)
		# Convert incoming phrases at the visible outer ring instead of letting them
		# overlap the opaque context body. Backward iteration keeps removal safe.
		if item.stream_type != StreamType.ANSWER and input_x >= size.x * 0.5 - 82.0:
			add_absorption_effect(item)
			items.remove_at(index)
			activity = 1.0
			continue
		if next_progress >= 1.0:
			items.remove_at(index)
			continue
		item.progress = next_progress
		item.pulse = move_toward(item.pulse, 0.0, delta)
		cache_item_path(item, center)
	for index in range(absorption_effects.size() - 1, -1, -1):
		var effect := absorption_effects[index]
		effect.age += delta
		if effect.age >= ABSORPTION_DURATION:
			absorption_effects.remove_at(index)
	queue_redraw()
	pass


## Captures the minimum packet state needed by the short-lived intake animation.
## Keeping this separate from items prevents an absorbed packet from being drawn twice.
func add_absorption_effect(item: StreamItem) -> void:
	var effect := AbsorptionEffect.new()
	effect.color = color_for_type(item.stream_type)
	effect.label = item.label
	effect.lane = float(item.lane)
	effect.weight = item.weight
	absorption_effects.append(effect)
	pass


func add_item(stream_type: StreamType, label: String, weight: float) -> void:
	# Never evict a packet that is visibly in transit. At saturation, wait for an
	# existing packet to reach its destination before admitting another one.
	if items.size() >= MAX_ITEMS:
		return
	# A golden-ratio sequence distributes arrivals across the full height without
	# random state, obvious repetition, or dependence on the current item count.
	var source_y_ratio := 0.06 + fmod(float(spawn_index) * 0.61803398875 + 0.17, 1.0) * 0.88
	var curve_direction := -1.0 if spawn_index % 2 == 0 else 1.0
	var item := StreamItem.new()
	item.stream_type = stream_type
	item.label = label
	item.weight = clampf(weight, 0.25, 1.0)
	item.speed = 0.82 + float(items.size() % 5) * 0.08
	item.lane = (items.size() % 7) - 3
	item.source_y_ratio = source_y_ratio
	item.curve_direction = curve_direction
	item.turn = turn_index
	cache_text_metrics(item)
	items.append(item)
	spawn_index += 1
	queue_redraw()
	pass


## Streaming APIs commonly deliver one or two characters per chunk. Merge nearby
## chunks into one visual item so draw cost follows phrases instead of token count.
## Only young items are eligible: changing an older label would alter spacing
## after that phrase is already well inside the scene.
func add_stream_fragment(stream_type: StreamType, chunk: String, fallback: String) -> void:
	if not items.is_empty():
		var latest := items[items.size() - 1]
		if latest.stream_type == stream_type and latest.progress <= STREAM_COALESCE_PROGRESS and latest.label.length() < MAX_FLOATING_TEXT_LENGTH:
			latest.label = floating_text(latest.label + chunk, fallback)
			latest.weight = weight_for_text(latest.label)
			latest.pulse = 1.0
			cache_text_metrics(latest)
			queue_redraw()
			return
	add_item(stream_type, floating_text(chunk, fallback), weight_for_text(chunk))
	pass


func _draw() -> void:
	if size.x < 320.0 or size.y < 220.0:
		return
	var center := size * 0.5
	for item: StreamItem in items:
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
	for effect: AbsorptionEffect in absorption_effects:
		var phase := clampf(effect.age / ABSORPTION_DURATION, 0.0, 1.0)
		var color := effect.color
		var label := effect.label
		var weight := effect.weight
		var lane_y := effect.lane * 8.0
		var impact_position := center + Vector2(-82.0, lane_y * 0.42)
		var collapse := smoothstep(0.0, 0.55, phase)
		var particle_position := impact_position.lerp(center, collapse)
		var particle_alpha := 1.0 - smoothstep(0.38, 0.72, phase)
		var text_rotation := clampf((center - impact_position).angle(), -0.42, 0.42)
		var tail_anchor := text_left_anchor(particle_position, label, text_rotation)
		draw_line(impact_position, tail_anchor, Color(color, particle_alpha * 0.24), 1.0 + weight, true)
		draw_rotated_centered_text(particle_position, label, text_rotation, Color(color, particle_alpha * 0.92))
		var ripple_phase := clampf(phase / 0.82, 0.0, 1.0)
		var ripple_radius := lerpf(68.0, 104.0, ripple_phase)
		draw_arc(center, ripple_radius, 0.0, TAU, 72, Color(color, (1.0 - ripple_phase) * 0.2), 1.6, true)
	pass


func draw_item(item: StreamItem, center: Vector2) -> void:
	var progress := item.progress
	var stream_type := item.stream_type
	var is_output := stream_type == StreamType.ANSWER
	var position := item_position(progress, item, center, is_output)
	var color := color_for_type(stream_type)
	var weight := item.weight
	var radius := 3.0 + weight * 3.5
	var edge_fade := 1.0 - smoothstep(0.86, 1.0, progress)
	var label := item.label
	if is_output:
		# Answers remain compact particles; drawing answer text again would compete
		# with the chat response and multiply glyph draw calls.
		var trail_points := PackedVector2Array()
		for trail_index in range(TRAIL_SAMPLE_COUNT, -1, -1):
			var trail_progress := maxf(progress - float(trail_index) * 0.009, 0.0)
			trail_points.append(item_position(trail_progress, item, center, true))
		if trail_points.size() > 1:
			draw_polyline(trail_points, Color(color, edge_fade * 0.18), maxf(1.0, radius * 0.26), true)
		draw_circle(position, radius * 1.7, Color(color, edge_fade * 0.06))
		draw_circle(position, radius * 0.72, Color(color, edge_fade * 0.88))
	else:
		# Incoming sources are semantic, so lay their real labels glyph-by-glyph on
		# the cached path instead of drawing a rigid horizontal label.
		var text_alpha := edge_fade * (0.76 + item.pulse * 0.18)
		draw_text_on_path(item, position, label, Color(color, text_alpha), Color(color, edge_fade * 0.18))
	pass


func text_left_anchor(position: Vector2, text: String, rotation: float) -> Vector2:
	var font := Fonts.medium()
	var font_size := Typography.label_small_size
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# draw_string uses position.y as its baseline. Align the tail with the visual
	# center between the font ascent and descent instead of with that baseline.
	var visual_center_y := (font.get_descent(font_size) - font.get_ascent(font_size)) * 0.5
	return position + Vector2(-width * 0.5 - 5.0, visual_center_y).rotated(rotation)


## Lays each glyph directly onto the packet's travelled curve. The newest point
## is the right edge of the label. Characters are placed in reverse order so the
## phrase still reads left-to-right, and the tail continues behind its first glyph.
func draw_text_on_path(item: StreamItem, current: Vector2, text: String, color: Color, tail_color: Color) -> void:
	var font := Fonts.medium()
	var font_size := Typography.label_small_size
	if item.path_history.size() < 2:
		return
	var current_distance := item.path_distances[item.path_distances.size() - 1] + item.path_history[item.path_history.size() - 1].distance_to(current)
	var distance_from_head := 2.0
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline_offset := (ascent - descent) * 0.5
	for index in range(text.length() - 1, -1, -1):
		var advance := item.glyph_advances[index]
		distance_from_head += advance * 0.5
		var glyph_position := cached_point_at_distance(item, current, current_distance, distance_from_head)
		# Sampling both sides estimates the local tangent. Every glyph gets its own
		# rotation, allowing the phrase itself to bend around the curve.
		var before := cached_point_at_distance(item, current, current_distance, distance_from_head + 2.0)
		var after := cached_point_at_distance(item, current, current_distance, maxf(distance_from_head - 2.0, 0.0))
		var rotation := clampf((after - before).angle(), -0.72, 0.72)
		draw_set_transform(glyph_position, rotation)
		draw_string(font, Vector2(-advance * 0.5, baseline_offset), text.substr(index, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		distance_from_head += advance * 0.5
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Continue along the same cached path so the tail meets the first glyph without
	# a visible kink or a separately invented curve.
	var tail_start_distance := distance_from_head + 5.0
	var tail_points := PackedVector2Array()
	for sample in range(TRAIL_SAMPLE_COUNT + 1):
		var sample_distance := tail_start_distance + float(TRAIL_SAMPLE_COUNT - sample) * 8.0
		tail_points.append(cached_point_at_distance(item, current, current_distance, sample_distance))
	draw_polyline(tail_points, tail_color, 1.0, true)
	pass


func cache_text_metrics(item: StreamItem) -> void:
	var font := Fonts.medium()
	var font_size := Typography.label_small_size
	item.glyph_advances.clear()
	item.label_width = 0.0
	for glyph: String in item.label:
		var advance := maxf(font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, 4.0)
		item.glyph_advances.append(advance)
		item.label_width += advance
	pass


## Records only newly travelled points. Rendering can then reuse the actual path
## instead of resampling the complete Bézier curve for every glyph every frame.
## path_history and path_distances must always be appended and trimmed together.
func cache_item_path(item: StreamItem, center: Vector2) -> void:
	if item.stream_type == StreamType.ANSWER:
		return
	var position := item_position(item.progress, item, center, false)
	if not item.path_history.is_empty() and item.path_history[item.path_history.size() - 1].distance_to(position) < PATH_HISTORY_STEP:
		return
	var path_distance := 0.0
	if not item.path_history.is_empty():
		path_distance = item.path_distances[item.path_distances.size() - 1] + item.path_history[item.path_history.size() - 1].distance_to(position)
	item.path_history.append(position)
	item.path_distances.append(path_distance)
	if item.path_history.size() > MAX_PATH_HISTORY_POINTS:
		item.path_history.remove_at(0)
		item.path_distances.remove_at(0)
	pass


## Finds a point behind the moving head by binary-searching cached cumulative
## distances. distance_from_head grows toward older points. This avoids repeated
## linear scans and allocating a reversed path during every redraw.
static func cached_point_at_distance(item: StreamItem, current: Vector2, current_distance: float, distance_from_head: float) -> Vector2:
	var target := current_distance - distance_from_head
	var last_index := item.path_history.size() - 1
	if target >= item.path_distances[last_index]:
		# Between the newest cached point and the current unsampled head.
		var segment_length := current_distance - item.path_distances[last_index]
		return item.path_history[last_index].lerp(current, (target - item.path_distances[last_index]) / maxf(segment_length, 0.001))
	if target <= item.path_distances[0]:
		# A new phrase can be wider than its recorded history. Extend the oldest
		# tangent so its early characters remain spaced rather than stacking.
		var oldest := item.path_history[0]
		var tangent := (oldest - item.path_history[1]).normalized()
		return oldest + tangent * (item.path_distances[0] - target)
	var low := 0
	var high := last_index
	# Locate the adjacent cached distances enclosing the requested target.
	while low + 1 < high:
		var middle := (low + high) / 2
		if item.path_distances[middle] <= target:
			low = middle
		else:
			high = middle
	var span := item.path_distances[high] - item.path_distances[low]
	return item.path_history[low].lerp(item.path_history[high], (target - item.path_distances[low]) / maxf(span, 0.001))


func draw_rotated_centered_text(position: Vector2, text: String, rotation: float, color: Color) -> void:
	draw_set_transform(position, rotation)
	draw_centered_text(Vector2.ZERO, text, Fonts.medium(), Typography.label_small_size, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	pass


## Uses eased cubic paths so packets accelerate into the context instead of
## sliding along rigid horizontal lanes. Opposing control points intentionally
## produce the pronounced S-shaped movement used by the curved text layout.
func item_position(progress: float, item: StreamItem, center: Vector2, is_output: bool) -> Vector2:
	var eased := smoothstep(0.0, 1.0, progress)
	var source_y := item.source_y_ratio * size.y
	var lane_offset := source_y - center.y
	var curve_direction := item.curve_direction
	if is_output:
		var output_start := center + Vector2(82.0, lane_offset * 0.04)
		var output_end := Vector2(size.x + 50.0, center.y + lane_offset * 0.45)
		return cubic_bezier(output_start, output_start + Vector2(150.0, -lane_offset * 0.28), output_end - Vector2(210.0, lane_offset * 0.75), output_end, eased)
	var input_start := Vector2(-50.0, center.y + lane_offset)
	var impact := center + Vector2(-82.0, lane_offset * 0.06)
	var pull := smoothstep(0.42, 1.0, eased)
	var drift := sin(progress * TAU * 1.65 + item.source_y_ratio * 9.0 + elapsed * 0.8) * 30.0 * (1.0 - pull)
	var control_a := Vector2(center.x * 0.2, center.y + lane_offset * 1.28 + curve_direction * 96.0)
	var control_b := Vector2(center.x * 0.68, center.y - lane_offset * 0.52 - curve_direction * 76.0)
	var position := cubic_bezier(input_start, control_a, control_b, impact, eased)
	position.y += drift
	return position


static func cubic_bezier(start: Vector2, control_a: Vector2, control_b: Vector2, end: Vector2, progress: float) -> Vector2:
	var inverse := 1.0 - progress
	return inverse * inverse * inverse * start + 3.0 * inverse * inverse * progress * control_a + 3.0 * inverse * progress * progress * control_b + progress * progress * progress * end


func draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.72),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius * 0.72),
		center + Vector2(-radius, 0.0),
	])
	draw_colored_polygon(points, color)
	pass


func draw_context_window(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	var absorption := absorption_activity()
	var breath_phase := sin(elapsed * TAU / 2.8)
	var breath := 0.5 + breath_phase * 0.5
	var ratio := context_ratio()
	var capacity_color := ColorBase.error if ratio >= 0.9 else (ColorBase.warning if ratio >= 0.72 else accent)
	# The loom stays circular and minimal: one quiet body and one truthful gauge.
	var body_radius := 64.0 + breath_phase * 0.8
	var gauge_radius := 74.0
	draw_circle(center, gauge_radius + 12.0 + absorption * 5.0, Color(capacity_color, 0.025 + absorption * 0.035))
	draw_circle(center, body_radius, Color(ColorBase.deep_surface, 0.97))
	draw_arc(center, body_radius, 0.0, TAU, 72, Color(accent, 0.16 + visual_activity * 0.1), 1.2, true)
	draw_arc(center, gauge_radius, -PI * 0.5, PI * 1.5, 80, Color(ColorBase.subtle_border, 0.3), 1.3, true)
	if ratio > 0.0:
		draw_arc(center, gauge_radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, maxi(2, int(80.0 * ratio)), Color(capacity_color, 0.94), 3.0, true)
	# The shuttle moves vertically while active, suggesting synthesis rather than storage.
	var shuttle_y := sin(elapsed * 2.1) * (5.0 + visual_activity * 4.0)
	var shuttle_center := center + Vector2(0.0, shuttle_y - 17.0)
	draw_diamond(shuttle_center, 10.0 + absorption * 3.5, Color(accent, 0.18 + breath * 0.12 + absorption * 0.24))
	draw_diamond(shuttle_center, 5.0 + absorption * 1.5, Color(accent, 0.82))
	draw_centered_text(center + Vector2(0.0, 8.0), I18n.t("agent.visuals.context"), Fonts.semibold(), Typography.label_medium_size, ColorBase.primary_text)
	draw_centered_text(center + Vector2(0.0, 27.0), token_label(), Fonts.regular(), Typography.label_small_size, Color(capacity_color, 0.9))
	pass


## Combines overlapping intake events into one bounded core response. The clamp
## avoids a distracting flash when several packets arrive in the same frame.
func absorption_activity() -> float:
	var intensity := 0.0
	for effect: AbsorptionEffect in absorption_effects:
		var phase := clampf(effect.age / ABSORPTION_DURATION, 0.0, 1.0)
		var pulse := sin(clampf(phase / 0.62, 0.0, 1.0) * PI) * (1.0 - smoothstep(0.68, 1.0, phase))
		intensity += pulse * (0.55 + effect.weight * 0.45)
	return clampf(intensity, 0.0, 1.0)


## Answer-colored particles alone communicate generated output. Deliberately do
## not add a solid channel, glow band, or text label here: those compete with the
## river and duplicate information already carried by the particle color.
func draw_output(center: Vector2) -> void:
	var answer := color_for_type(StreamType.ANSWER)
	var alpha := 0.22 + output_activity * 0.5
	var stream_start := center.x + 66.0
	# Three interlaced threads carry the synthesized answer away from the loom.
	for strand in range(3):
		var strand_points := PackedVector2Array()
		for step in range(RIVER_SAMPLE_COUNT + 1):
			var progress := float(step) / float(RIVER_SAMPLE_COUNT)
			var x := lerpf(stream_start, size.x, progress)
			var envelope := sin(progress * PI) * (0.35 + smoothstep(0.0, 0.35, progress) * 0.65)
			var y := center.y + sin(progress * TAU * 3.0 + strand * TAU / 3.0 - elapsed * 0.9) * envelope * 9.0
			strand_points.append(Vector2(x, y))
		draw_polyline(strand_points, Color(answer, 0.12 + output_activity * 0.16), 1.5, true)
	for index in range(5):
		var progress := fmod(elapsed * 0.22 + index * 0.2, 1.0)
		var particle_fade := 1.0 - smoothstep(0.72, 1.0, progress)
		var position := Vector2(lerpf(stream_start + 6.0, size.x, progress), center.y + sin(progress * TAU * 3.0 + index * TAU / 3.0 - elapsed * 0.9) * sin(progress * PI) * 9.0)
		draw_diamond(position, 2.5 + output_activity * 1.8, Color(answer, alpha * particle_fade))
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


static func floating_text(text: String, fallback: String) -> String:
	var compact := text.replace("\r", " ").replace("\n", " ").replace("\t", " ").strip_edges()
	while compact.contains("  "):
		compact = compact.replace("  ", " ")
	if compact.is_empty():
		return fallback
	return StringUtils.truncate(compact, MAX_FLOATING_TEXT_LENGTH)


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
