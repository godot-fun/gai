class_name ContextMemoryRiver
extends VisualEffect

## A living context map: source material flows into the model, older items recede,
## and generated content leaves through the output channel.

const MAX_ITEMS := 96
# Mirrors MatrixRain's bounded reply slots: curved glyph rendering is relatively
# expensive, so only this many semantic text phrases may be visible at once.
const MAX_TEXT_ITEMS := 32
const PARTICLE_SPEED := 0.19
const INPUT_TRAVEL_SPEED := 240.0
const INPUT_SPEED_MIN := 0.55
const INPUT_SPEED_MAX := 1.45
const DEFAULT_CONTEXT_LIMIT := 128_000
const ABSORPTION_DURATION := 0.62
## Characters remain fully visible up to the lens center, then dissolve over this distance.
const TEXT_CENTER_FADE_DISTANCE := 54.0
const INPUT_APPROACH_PROGRESS := 0.72
const INPUT_PROGRESS_SAMPLE := 0.002
const INPUT_MAX_PROGRESS_STEP := 0.025
const TRAIL_SAMPLE_COUNT := 9
const TEXT_TRAIL_SAMPLE_STEP := 12.0
# Sample history by travelled screen distance rather than frame count. This keeps
# curve quality stable across frame rates and bounds memory per item.
const MAX_PATH_HISTORY_POINTS := 128
const MAX_TEXT_PATH_HISTORY_POINTS := 1024
const PATH_HISTORY_STEP := 2.0
# A fixed small count adds depth without scaling draw cost with stream traffic.
const DECORATIVE_MOTE_COUNT := 7
const DECORATIVE_TRAIL_SAMPLES := 8
const DECORATIVE_TRAIL_SAMPLE_STEP := 12.0
const DECORATIVE_SPAWN_INTERVAL := 0.55
const CONTEXT_RING_RADIUS := 52.0
## Horizontal threshold for decorative motes reaching the intake side of the lens.
const CONTEXT_RING_INSET := 58.0
const OUTPUT_SPIRAL_TURNS := 3.25
const OUTPUT_SPIRAL_RADIUS := 11.0
const OUTPUT_TRAIL_SAMPLES := 8
const OUTPUT_TRAIL_MIN_LENGTH := 28.0
const END_INPUT_SECONDS := 0.55
const END_OUTPUT_SECONDS := 0.65
const END_LENS_SECONDS := 0.32
const END_TIMEOUT_MSEC := 4000

enum StreamType { USER, SYSTEM, HISTORY, FILE, TOOL, WEB, THINKING, ERROR, ANSWER }


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
	var pulse: float = 1.0
	# These arrays share indices. Points are oldest -> newest and distances are
	# monotonically increasing, so trimming the oldest pair requires no rebasing.
	var path_history := PackedVector2Array()
	var path_distances := PackedFloat32Array()
	# Font metrics are immutable for an item and expensive enough to cache once.
	var glyph_advances := PackedFloat32Array()
	var label_width: float = 0.0
	var absorption_triggered: bool = false


class AbsorptionEffect extends RefCounted:
	# Lightweight snapshot detached from an item after it reaches the context ring.
	var age: float = 0.0
	var color: Color
	var weight: float
	var source_width: float
	var source_speed: float
	var output_spawned: bool = false


class OutputMote extends RefCounted:
	var progress: float = 0.0
	var speed: float
	var phase_offset: float
	var trail_length: float


var items: Array[StreamItem] = []
var absorption_effects: Array[AbsorptionEffect] = []
var decorative_motes: Array[StreamItem] = []
var output_motes: Array[OutputMote] = []
var elapsed: float = 0.0
var spawn_index: int = 0
var decorative_spawn_index: int = 0
var decorative_spawn_timer: float = 0.0
var output_spawn_index: int = 0
var prompt_tokens: int = 0
var completion_tokens: int = 0
var context_limit: int = DEFAULT_CONTEXT_LIMIT
var activity: float = 0.0
var visual_activity: float = 0.0
var output_activity: float = 0.0
var is_ending: bool = false
var lens_closing: bool = false
var lens_close_progress: float = 0.0
var stream_pending: Dictionary[int, String] = {}


func fade_in_seconds() -> float:
	return 0.35


func fade_out_seconds() -> float:
	return 0.45


func on_agent_start(_session_id: int) -> void:
	is_ending = false
	lens_closing = false
	lens_close_progress = 0.0
	stream_pending.clear()
	activity = 1.0
	queue_redraw()
	pass


func on_agent_end(_session_id: int, _error_message: String) -> void:
	# Stop admitting new work, then let the existing visual story finish in order:
	# intake -> absorption -> output -> lens close.
	is_ending = true
	output_activity = 1.0
	if not is_inside_tree():
		return
	var deadline := Time.get_ticks_msec() + END_TIMEOUT_MSEC
	while not visual_flow_is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	lens_closing = true
	while lens_close_progress < 1.0:
		await get_tree().process_frame
	pass


func on_turn_start(_session_id: int) -> void:
	activity = 1.0
	pass


func on_turn_end(_session_id: int) -> void:
	output_activity = maxf(output_activity, 0.6)
	pass


func on_chat_entry_add(_session_id: int, entry: ChatEntry) -> void:
	var stream_type := stream_type_for_entry(entry)
	if stream_type < 0:
		return
	drain_complete_sentences(stream_type as StreamType, compact_line(entry.body))
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.strip_edges().is_empty():
		return
	var stream_type := StreamType.THINKING if stream_kind == OpenAiClient.STREAM_KIND_REASONING else StreamType.ANSWER
	var fallback := I18n.t("agent.visuals.thought") if stream_type == StreamType.THINKING else I18n.t("agent.visuals.answer")
	if stream_type == StreamType.ANSWER:
		output_activity = 1.0
	else:
		add_stream_fragment(stream_type, chunk, fallback)
		activity = 1.0
	pass


func on_message_complete(_session_id: int, usage: OpenAiUsage) -> void:
	prompt_tokens = maxi(usage.prompt_tokens, 0)
	completion_tokens = maxi(usage.completion_tokens, 0)
	# Keep the gauge meaningful for providers whose actual context limit is unknown.
	while prompt_tokens > context_limit:
		context_limit *= 2
	activity = 1.0
	queue_redraw()
	pass


## File tools have no start chat entry; other tools are drawn from [method on_chat_entry_add] only.
func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	if not ToolHelper.is_file_tool(tool_name):
		return
	add_item(stream_type_for_tool_name(tool_name), ToolVisualDisplay.upper_name(tool_name), 0.7)
	activity = 1.0
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	activity = 1.0
	if result.is_error:
		output_activity = maxf(output_activity, 0.35)
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
	if lens_closing:
		lens_close_progress = minf(lens_close_progress + delta / END_LENS_SECONDS, 1.0)
	var center := size * 0.5
	for index in range(items.size() - 1, -1, -1):
		var item := items[index]
		if item.stream_type == StreamType.ANSWER:
			item.progress = advance_answer_progress(item, delta)
		elif advance_semantic_item(item, delta, center):
			items.remove_at(index)
			continue
		if item.progress >= 1.0:
			items.remove_at(index)
			continue
	for index in range(absorption_effects.size() - 1, -1, -1):
		var effect := absorption_effects[index]
		effect.age += delta
		if not effect.output_spawned and effect.age >= ABSORPTION_DURATION * 0.5:
			effect.output_spawned = true
			spawn_output_mote(effect.source_width, effect.source_speed)
		if effect.age >= ABSORPTION_DURATION:
			absorption_effects.remove_at(index)
	update_decorative_motes(delta, center)
	update_output_motes(delta)
	queue_redraw()
	pass


func advance_answer_progress(item: StreamItem, delta: float) -> float:
	var progress_step := delta * PARTICLE_SPEED * item.speed
	if is_ending:
		progress_step = maxf(progress_step, delta / END_INPUT_SECONDS)
	return item.progress + progress_step


## Returns true only after the complete phrase has passed through the fade zone.
func advance_semantic_item(item: StreamItem, delta: float, center: Vector2) -> bool:
	var previous_position := item_position(item.progress, item, center, false)
	var next_progress := advance_input_progress(item, center, input_travel_distance(item, delta, center))
	var next_position := item_position(next_progress, item, center, false)
	if not item.absorption_triggered and previous_position.x < center.x and next_position.x >= center.x:
		item.absorption_triggered = true
		add_absorption_effect(item)
		activity = 1.0
	if next_progress >= 1.0:
		return true
	item.progress = next_progress
	item.pulse = move_toward(item.pulse, 0.0, delta)
	cache_item_path(item, center)
	return false


func input_travel_distance(item: StreamItem, delta: float, center: Vector2) -> float:
	var distance := delta * INPUT_TRAVEL_SPEED * item.speed
	if is_ending:
		distance = maxf(distance, input_path_length(item, center) * delta / END_INPUT_SECONDS)
	return distance


## Decorative motes follow the same distance-based motion as semantic items.
## Staggered creation guarantees they enter through the left edge instead of
## appearing halfway along a time-looped path when the visual becomes visible.
func update_decorative_motes(delta: float, center: Vector2) -> void:
	decorative_spawn_timer -= delta
	if not is_ending and decorative_motes.size() < DECORATIVE_MOTE_COUNT and decorative_spawn_timer <= 0.0:
		spawn_decorative_mote()
		decorative_spawn_timer = DECORATIVE_SPAWN_INTERVAL
	for index in range(decorative_motes.size() - 1, -1, -1):
		var mote := decorative_motes[index]
		mote.progress = advance_input_progress(mote, center, input_travel_distance(mote, delta, center))
		var position := item_position(mote.progress, mote, center, false)
		cache_item_path(mote, center)
		if position.x >= center.x - CONTEXT_RING_INSET:
			add_absorption_effect(mote)
			decorative_motes.remove_at(index)
	pass


func spawn_decorative_mote() -> void:
	var mote := StreamItem.new()
	mote.stream_type = decorative_spawn_index % 6 as StreamType
	mote.speed = randf_range(INPUT_SPEED_MIN, INPUT_SPEED_MAX)
	mote.source_y_ratio = 0.06 + fmod(float(decorative_spawn_index) * 0.61803398875 + 0.31, 1.0) * 0.88
	mote.curve_direction = -1.0 if decorative_spawn_index % 2 == 0 else 1.0
	decorative_motes.append(mote)
	decorative_spawn_index += 1
	pass


func spawn_output_mote(source_width: float = OUTPUT_TRAIL_MIN_LENGTH, source_speed: float = 1.0) -> void:
	var mote := OutputMote.new()
	mote.speed = source_speed
	mote.phase_offset = float(output_spawn_index % 6) * TAU / 6.0
	mote.trail_length = output_trail_length(source_width, size * 0.5)
	output_motes.append(mote)
	output_spawn_index += 1
	output_activity = 1.0
	pass


func update_output_motes(delta: float) -> void:
	for index in range(output_motes.size() - 1, -1, -1):
		var mote := output_motes[index]
		var progress_step := delta * PARTICLE_SPEED * mote.speed
		if is_ending:
			progress_step = maxf(progress_step, delta / END_OUTPUT_SECONDS)
		mote.progress += progress_step
		if mote.progress >= 1.0:
			output_motes.remove_at(index)
	pass


## Captures the minimum packet state needed by the short-lived intake animation.
## Keeping this separate from items prevents an absorbed packet from being drawn twice.
func add_absorption_effect(item: StreamItem) -> void:
	var effect := AbsorptionEffect.new()
	effect.color = color_for_type(item.stream_type)
	effect.weight = item.weight
	effect.source_width = item.label_width
	effect.source_speed = item.speed
	absorption_effects.append(effect)
	pass


func add_item(stream_type: StreamType, label: String, weight: float) -> void:
	if is_ending:
		return
	# Never evict a packet that is visibly in transit. At saturation, wait for an
	# existing packet to reach its destination before admitting another one.
	if items.size() >= MAX_ITEMS:
		return
	# ANSWER items are small output particles and do not pay the per-glyph curved
	# text cost. Limit only the semantic phrases travelling on the left side.
	if stream_type != StreamType.ANSWER and active_text_item_count() >= MAX_TEXT_ITEMS:
		return
	# A golden-ratio sequence distributes arrivals across the full height without
	# random state, obvious repetition, or dependence on the current item count.
	var source_y_ratio := 0.06 + fmod(float(spawn_index) * 0.61803398875 + 0.17, 1.0) * 0.88
	var curve_direction := -1.0 if spawn_index % 2 == 0 else 1.0
	var item := StreamItem.new()
	item.stream_type = stream_type
	item.label = label
	item.weight = clampf(weight, 0.25, 1.0)
	item.speed = randf_range(INPUT_SPEED_MIN, INPUT_SPEED_MAX)
	item.lane = (items.size() % 7) - 3
	item.source_y_ratio = source_y_ratio
	item.curve_direction = curve_direction
	cache_text_metrics(item)
	items.append(item)
	spawn_index += 1
	queue_redraw()
	pass


func active_text_item_count() -> int:
	var count := 0
	for item: StreamItem in items:
		if item.stream_type != StreamType.ANSWER:
			count += 1
	return count


func visual_flow_is_empty() -> bool:
	return items.is_empty() and decorative_motes.is_empty() and absorption_effects.is_empty() and output_motes.is_empty()


## Buffers token chunks until [ChatEntryCursor] sees a complete sentence, matching Matrix/Jarvis.
func add_stream_fragment(stream_type: StreamType, chunk: String, _fallback: String) -> void:
	if is_ending:
		return
	var pending_key := stream_type as int
	var pending := compact_line(String(stream_pending.get(pending_key, "")) + chunk)
	stream_pending[pending_key] = drain_complete_sentences(stream_type, pending)
	pass


## Emits one [ChatEntryCursor] sentence at a time; returns any unfinished tail.
func drain_complete_sentences(stream_type: StreamType, text: String) -> String:
	var rest := text
	while StringUtils.is_not_blank(rest):
		var parse := ChatEntryCursor.parse_sentence(rest, 0)
		if parse.text.is_empty():
			break
		add_item(stream_type, parse.text, weight_for_text(parse.text))
		rest = compact_line(rest.substr(parse.next_index))
	return rest


func _draw() -> void:
	if size.x < 320.0 or size.y < 220.0:
		return
	var center := size * 0.5
	draw_decorative_motes(center)
	for item: StreamItem in items:
		draw_item(item, center)
	# Intake and output sit below the lens outline, preserving a crisp portal edge
	# while remaining visible through its transparent center.
	draw_absorption_effects(center)
	draw_output(center)
	draw_context_window(center)
	pass


## Low-density circles preserve the earlier particle language as atmosphere.
## They carry no event text, but otherwise use the same motion rules as phrases.
func draw_decorative_motes(center: Vector2) -> void:
	for mote: StreamItem in decorative_motes:
		var progress := mote.progress
		var fade_in := smoothstep(0.0, 0.08, progress)
		var alpha := fade_in
		var color := color_for_type(mote.stream_type)
		var trail := PackedVector2Array()
		var position := item_position(progress, mote, center, false)
		if mote.path_history.size() >= 2:
			var current_distance := cached_current_distance(mote, position)
			for sample in range(DECORATIVE_TRAIL_SAMPLES, -1, -1):
				trail.append(cached_point_at_distance(mote, position, current_distance, float(sample) * DECORATIVE_TRAIL_SAMPLE_STEP))
		else:
			trail.append(position)
		if trail.size() > 1:
			draw_polyline(trail, VisualColor.stroke(color, alpha * 0.12), 1.0, true)
		position = trail[trail.size() - 1]
		var radius := 2.2 + float(mote.stream_type % 3) * 0.65
		draw_circle(position, radius * 2.0, VisualColor.stroke(color, alpha * 0.055))
		draw_circle(position, radius, VisualColor.stroke(color, alpha * 0.72))
	pass


## Adds a type-colored core pulse without taking ownership of the incoming text.
func draw_absorption_effects(center: Vector2) -> void:
	for effect: AbsorptionEffect in absorption_effects:
		var phase := clampf(effect.age / ABSORPTION_DURATION, 0.0, 1.0)
		var color := effect.color
		var ripple_phase := clampf(phase / 0.82, 0.0, 1.0)
		var ripple_radius := lerpf(54.0, 84.0, ripple_phase)
		draw_arc(center, ripple_radius, 0.0, TAU, 72, VisualColor.stroke(color, (1.0 - ripple_phase) * 0.2), 1.6, true)
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
		var trail_progress := output_trail_length(item.label_width, center) / output_channel_length(center)
		var trail_points := PackedVector2Array()
		for trail_index in range(OUTPUT_TRAIL_SAMPLES, -1, -1):
			var sample_ratio := float(trail_index) / float(OUTPUT_TRAIL_SAMPLES)
			var sample_progress := maxf(progress - sample_ratio * trail_progress, 0.0)
			trail_points.append(item_position(sample_progress, item, center, true))
		if trail_points.size() > 1:
			draw_polyline(trail_points, VisualColor.stroke(color, edge_fade * 0.18), maxf(1.0, radius * 0.26), true)
		draw_circle(position, radius * 1.7, VisualColor.stroke(color, edge_fade * 0.06))
		draw_circle(position, radius * 0.72, VisualColor.stroke(color, edge_fade * 0.88))
	else:
		# Incoming sources are semantic, so lay their real labels glyph-by-glyph on
		# the cached path instead of drawing a rigid horizontal label.
		var arrival_alpha := smoothstep(0.0, 0.04, progress)
		var text_alpha := arrival_alpha * (0.76 + item.pulse * 0.18)
		draw_text_on_path(item, position, label, VisualColor.stroke(color, text_alpha), VisualColor.stroke(color, arrival_alpha * 0.18), center.x)
	pass


## Lays each glyph directly onto the packet's travelled curve. The newest point
## is the right edge of the label. Characters are placed in reverse order so the
## phrase still reads left-to-right, and the tail continues behind its first glyph.
func draw_text_on_path(item: StreamItem, current: Vector2, text: String, color: Color, tail_color: Color, center_x: float) -> void:
	var font := Fonts.medium()
	var font_size := Typography.label_small_size
	if item.path_history.size() < 2:
		return
	var current_distance := cached_current_distance(item, current)
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
		var glyph_color := color
		glyph_color.a *= center_fade_alpha(glyph_position.x, center_x)
		draw_set_transform(glyph_position, rotation)
		draw_string(font, Vector2(-advance * 0.5, baseline_offset), text.substr(index, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, glyph_color)
		distance_from_head += advance * 0.5
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Continue along the same cached path so the tail meets the first glyph without
	# a visible kink or a separately invented curve.
	var tail_start_distance := distance_from_head + 5.0
	var tail_points := PackedVector2Array()
	for sample in range(TRAIL_SAMPLE_COUNT + 1):
		var sample_distance := tail_start_distance + float(TRAIL_SAMPLE_COUNT - sample) * TEXT_TRAIL_SAMPLE_STEP
		tail_points.append(cached_point_at_distance(item, current, current_distance, sample_distance))
	var faded_tail_color := tail_color
	faded_tail_color.a *= center_fade_alpha(tail_points[tail_points.size() - 1].x, center_x)
	draw_polyline(tail_points, faded_tail_color, 1.0, true)
	pass


static func center_fade_alpha(x: float, center_x: float) -> float:
	return 1.0 - smoothstep(center_x, center_x + TEXT_CENTER_FADE_DISTANCE, x)


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
	var text_point_count := ceili((item.label_width + TEXT_CENTER_FADE_DISTANCE + 48.0) / PATH_HISTORY_STEP)
	var history_limit := mini(maxi(MAX_PATH_HISTORY_POINTS, text_point_count), MAX_TEXT_PATH_HISTORY_POINTS)
	if item.path_history.size() > history_limit:
		item.path_history.remove_at(0)
		item.path_distances.remove_at(0)
	pass


static func cached_current_distance(item: StreamItem, current: Vector2) -> float:
	var last_index := item.path_history.size() - 1
	return item.path_distances[last_index] + item.path_history[last_index].distance_to(current)


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


## S-curve from the left edge into the lens center, then straight through until
## the final glyph finishes its spatial fade.
func item_position(progress: float, item: StreamItem, center: Vector2, is_output: bool) -> Vector2:
	var eased := smoothstep(0.0, 1.0, progress)
	var source_y := item.source_y_ratio * size.y
	var lane_offset := source_y - center.y
	var curve_direction := item.curve_direction
	if is_output:
		var x := lerpf(center.x + CONTEXT_RING_RADIUS, size.x + 50.0, eased)
		var spiral_envelope := smoothstep(0.0, 0.12, eased)
		var phase := eased * TAU * OUTPUT_SPIRAL_TURNS + item.source_y_ratio * TAU - elapsed * 0.9
		return Vector2(x, center.y + sin(phase) * OUTPUT_SPIRAL_RADIUS * spiral_envelope)
	var input_start := Vector2(-50.0, center.y + lane_offset)
	if progress >= INPUT_APPROACH_PROGRESS:
		var through_progress := inverse_lerp(INPUT_APPROACH_PROGRESS, 1.0, progress)
		var exit := center + Vector2(item.label_width + TEXT_CENTER_FADE_DISTANCE + 8.0, 0.0)
		return center.lerp(exit, through_progress)
	var approach_progress := progress / INPUT_APPROACH_PROGRESS
	var approach_eased := smoothstep(0.0, 1.0, approach_progress)
	var pull := smoothstep(0.42, 1.0, approach_eased)
	var drift := sin(approach_progress * TAU * 1.65 + item.source_y_ratio * 9.0) * 30.0 * (1.0 - pull)
	var control_a := Vector2(center.x * 0.2, center.y + lane_offset * 1.28 + curve_direction * 96.0)
	# End tangent aims right so the approach meets the through segment without a kink.
	var control_b := Vector2(lerpf(center.x * 0.68, center.x - 44.0, pull), lerpf(center.y - lane_offset * 0.52 - curve_direction * 76.0, center.y, pull))
	var position := cubic_bezier(input_start, control_a, control_b, center, approach_eased)
	position.y += drift
	return position


## Advances by screen distance rather than raw Bezier time, keeping the visible
## speed stable across the curved approach and the straight pass through the lens.
func advance_input_progress(item: StreamItem, center: Vector2, travel_distance: float) -> float:
	var progress := item.progress
	var remaining := maxf(travel_distance, 0.0)
	while remaining > 0.001 and progress < 1.0:
		var probe := minf(progress + INPUT_PROGRESS_SAMPLE, 1.0)
		var sample_distance := item_position(progress, item, center, false).distance_to(item_position(probe, item, center, false))
		var pixels_per_progress := sample_distance / maxf(probe - progress, 0.0001)
		var progress_step := minf(remaining / maxf(pixels_per_progress, 0.001), INPUT_MAX_PROGRESS_STEP)
		progress_step = minf(progress_step, 1.0 - progress)
		var next_progress := progress + progress_step
		var actual_distance := item_position(progress, item, center, false).distance_to(item_position(next_progress, item, center, false))
		progress = next_progress
		remaining -= maxf(actual_distance, 0.001)
	return progress


func input_path_length(item: StreamItem, center: Vector2) -> float:
	var length := 0.0
	var previous := item_position(0.0, item, center, false)
	for index in range(1, 41):
		var point := item_position(float(index) / 40.0, item, center, false)
		length += previous.distance_to(point)
		previous = point
	return length


static func cubic_bezier(start: Vector2, control_a: Vector2, control_b: Vector2, end: Vector2, progress: float) -> Vector2:
	var inverse := 1.0 - progress
	return inverse * inverse * inverse * start + 3.0 * inverse * inverse * progress * control_a + 3.0 * inverse * progress * progress * control_b + progress * progress * progress * end


func draw_context_window(center: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	var absorption := absorption_activity()
	var ratio := context_ratio()
	var capacity_color := Colors.error if ratio >= 0.9 else (Colors.warning if ratio >= 0.72 else accent)
	# A transparent lens replaces the previous solid dashboard. The input collapse
	# and output braid remain visible through it, making the center read as a
	# transformation point instead of a separate widget.
	var close_eased := smoothstep(0.0, 1.0, lens_close_progress)
	var lens_alpha := 1.0 - close_eased
	var gauge_radius := lerpf(CONTEXT_RING_RADIUS, 44.0, close_eased)
	if absorption > 0.0:
		draw_arc(center, gauge_radius + 7.0 + absorption * 4.0, 0.0, TAU, 64, Color(capacity_color, absorption * 0.08 * lens_alpha), 2.0, true)
	if lens_closing:
		var closing_wave_radius := lerpf(CONTEXT_RING_RADIUS, CONTEXT_RING_RADIUS + 30.0, close_eased)
		draw_arc(center, closing_wave_radius, 0.0, TAU, 64, Color(capacity_color, sin(close_eased * PI) * 0.1), 1.2, true)
	draw_arc(center, gauge_radius, 0.0, TAU, 72, Color(Colors.subtle_border, 0.34 * lens_alpha), 1.0, true)
	if ratio > 0.0:
		draw_arc(center, gauge_radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, maxi(2, int(72.0 * ratio)), Color(capacity_color, 0.92 * lens_alpha), 2.2, true)
	var text_alpha := 1.0 - smoothstep(0.0, 0.55, lens_close_progress)
	draw_centered_text(center + Vector2(0.0, 72.0), I18n.t("agent.visuals.context"), Fonts.semibold(), Typography.label_small_size, Color(Colors.primary_text, 0.82 * text_alpha))
	draw_centered_text(center + Vector2(0.0, 88.0), token_label(), Fonts.regular(), Typography.label_small_size, Color(capacity_color, 0.82 * text_alpha))
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
	# No permanent output rail: each generated mote carries only its own curved
	# history, leaving negative space between responses.
	for mote: OutputMote in output_motes:
		var progress := mote.progress
		var particle_fade := smoothstep(0.0, 0.06, progress) * (1.0 - smoothstep(0.72, 1.0, progress))
		var phase := output_spiral_phase(progress, mote.phase_offset)
		var depth := cos(phase) * 0.5 + 0.5
		var trail_progress := mote.trail_length / output_channel_length(center)
		var tail_points := PackedVector2Array()
		for sample in range(OUTPUT_TRAIL_SAMPLES, -1, -1):
			var sample_ratio := float(sample) / float(OUTPUT_TRAIL_SAMPLES)
			var sample_progress := maxf(progress - sample_ratio * trail_progress, 0.0)
			tail_points.append(output_spiral_position(sample_progress, mote.phase_offset, center))
		draw_polyline(tail_points, VisualColor.stroke(answer, alpha * particle_fade * 0.16), lerpf(0.8, 1.5, depth), true)
		var position := tail_points[tail_points.size() - 1]
		var radius := lerpf(2.0, 4.2 + output_activity, depth)
		draw_circle(position, radius * 2.0, VisualColor.stroke(answer, alpha * particle_fade * 0.07))
		draw_circle(position, radius, VisualColor.stroke(answer, alpha * particle_fade * lerpf(0.48, 1.0, depth)))
	pass


func output_spiral_position(progress: float, phase_offset: float, center: Vector2) -> Vector2:
	var envelope := smoothstep(0.0, 0.1, progress)
	var phase := output_spiral_phase(progress, phase_offset)
	var x := lerpf(center.x + CONTEXT_RING_RADIUS, size.x + 50.0, progress)
	return Vector2(x, center.y + sin(phase) * OUTPUT_SPIRAL_RADIUS * envelope)


func output_channel_length(center: Vector2) -> float:
	return maxf(size.x + 50.0 - (center.x + CONTEXT_RING_RADIUS), 1.0)


## A phrase controls the visible trace length without shortening the mote lifetime.
func output_trail_length(source_width: float, center: Vector2) -> float:
	var available_width := output_channel_length(center)
	return clampf(source_width, OUTPUT_TRAIL_MIN_LENGTH, available_width)


func output_spiral_phase(progress: float, phase_offset: float) -> float:
	return progress * TAU * OUTPUT_SPIRAL_TURNS + phase_offset - elapsed * 0.9


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


static func compact_line(text: String) -> String:
	var compact := text.replace("\r", " ").replace("\n", " ").replace("\t", " ").strip_edges()
	while compact.contains("  "):
		compact = compact.replace("  ", " ")
	return compact


static func stream_type_for_tool_name(tool_name: String) -> StreamType:
	if ToolHelper.is_file_tool(tool_name):
		return StreamType.FILE
	if ToolHelper.is_web_tool(tool_name):
		return StreamType.WEB
	return StreamType.TOOL


static func stream_type_for_entry(entry: ChatEntry) -> int:
	if ChatEntry.is_context_kind(entry.kind):
		return StreamType.SYSTEM
	match entry.kind:
		ChatEntry.KIND_USER:
			return StreamType.USER
		ChatEntry.KIND_FILE_TOOL, ChatEntry.KIND_WEB_TOOL, ChatEntry.KIND_TOOL:
			return stream_type_for_tool_name(entry.title)
		ChatEntry.KIND_WEB:
			return StreamType.WEB
		ChatEntry.KIND_RESULT:
			return StreamType.TOOL
		ChatEntry.KIND_GIT_DIFF:
			return StreamType.FILE
		ChatEntry.KIND_THINKING:
			return StreamType.THINKING
		ChatEntry.KIND_AGENT:
			return StreamType.HISTORY
		ChatEntry.KIND_ERROR:
			return StreamType.ERROR
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
		StreamType.WEB:
			return I18n.t("agent.visuals.web")
		StreamType.THINKING:
			return I18n.t("agent.visuals.thought")
		StreamType.ERROR:
			return I18n.t("agent.visuals.error")
		StreamType.ANSWER:
			return I18n.t("agent.visuals.answer")
	return I18n.t("agent.visuals.history")


## Title / accent hues aligned with [agent/ui/chat/bubble] (File, Tool, WebTool, Thinking, etc.).
static func neon_base_for_type(stream_type: StreamType) -> Color:
	match stream_type:
		StreamType.USER:
			return ThemeColor.accent_theme_color()
		StreamType.SYSTEM:
			return Colors.secondary_text
		StreamType.HISTORY:
			return Colors.secondary_text
		StreamType.FILE:
			return Colors.warning
		StreamType.TOOL:
			return Colors.success
		StreamType.WEB:
			return Colors.info
		StreamType.THINKING:
			return Colors.purple
		StreamType.ERROR:
			return Colors.error
		StreamType.ANSWER:
			return Colors.primary_text
	return Colors.secondary_text


static func color_for_type(stream_type: StreamType) -> Color:
	return VisualColor.appearance_color(neon_base_for_type(stream_type))
