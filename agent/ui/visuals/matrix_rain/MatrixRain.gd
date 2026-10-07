class_name MatrixRain
extends VisualEffect

## Event-driven code rain. Reasoning accelerates the fall, tools reserve highlighted
## columns, and answer text falls as reply glyphs.

const MIN_COLUMN_STEP := 22.0
const MAX_COLUMNS := 112
const MAX_TRAIL_LENGTH := 22
const GLYPH_REFRESH_SECONDS := 0.075
const SENTENCE_INTERVAL_SECONDS := 0.2
const MAX_REPLY_RAINS := 64
const REPLY_COLUMN_LENGTH := 18
const MIN_REPLY_RAIN_SPEED := 80.0
const MAX_REPLY_RAIN_SPEED := 240.0
const END_DROP_SECONDS := 0.55
const END_DROP_MIN_SPEED := 1200.0

enum ToolState { NONE, RUNNING, SUCCESS, FAILED }


class RainColumn extends RefCounted:
	var x: float = 0.0
	var head_y: float = 0.0
	var speed: float = 0.0
	var length: int = 0
	var step_y: float = 0.0
	var random_seed: int = 0
	var cycle: int = 0
	var tool_id: String = ""
	var tool_label: String = ""
	var tool_state: ToolState = ToolState.NONE
	var highlight: float = 0.0
	var release_pending: bool = false


class ReplyGlyph extends RefCounted:
	var text: String = ""
	var x: float = 0.0
	var y: float = 0.0
	var speed: float = 0.0
	var releases_rain_slot: bool = false


var columns: Array[RainColumn] = []
var active_tools: Dictionary[String, int] = {}
var elapsed: float = 0.0
var glyph_clock: float = 0.0
var glyph_tick: int = 0
var reasoning_energy: float = 0.0
var layout_width: float = -1.0
var active_session_id: int = 0
var sentence_timer: float = 0.0
var sentence_cursor: VisualChatSentenceCursor = VisualChatSentenceCursor.new()
var reply_glyphs: Array[ReplyGlyph] = []
var reply_sentence_index: int = 0
var active_reply_rain_count: int = 0
var pending_sentence: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.MATRIX_RAIN


func fade_in_seconds() -> float:
	return 0.3


func fade_out_seconds() -> float:
	return 0.5


func reset_visual() -> void:
	columns.clear()
	active_tools.clear()
	elapsed = 0.0
	glyph_clock = 0.0
	glyph_tick = 0
	reasoning_energy = 0.0
	layout_width = -1.0
	active_session_id = 0
	sentence_timer = 0.0
	sentence_cursor.clear()
	reply_glyphs.clear()
	reply_sentence_index = 0
	active_reply_rain_count = 0
	pending_sentence = ""
	queue_redraw()
	pass


func on_agent_start(session_id: int) -> void:
	active_session_id = session_id
	sentence_cursor.reset_for_session(session_id)
	pending_sentence = ""
	reasoning_energy = 0.28
	ensure_columns()
	queue_redraw()
	pass


func on_agent_end(error_message: String) -> void:
	active_session_id = 0
	pending_sentence = ""
	ensure_columns()
	for column: RainColumn in columns:
		var column_exit_y := size.y + float(column.length) * column.step_y + 48.0
		column.speed = maxf(END_DROP_MIN_SPEED, (column_exit_y - column.head_y) / END_DROP_SECONDS)
	for reply_glyph: ReplyGlyph in reply_glyphs:
		var glyph_exit_y := size.y + 48.0
		reply_glyph.speed = maxf(END_DROP_MIN_SPEED, (glyph_exit_y - reply_glyph.y) / END_DROP_SECONDS)
	reasoning_energy = 1.0 if StringUtils.is_not_blank(error_message) else 0.72
	queue_redraw()
	if not is_inside_tree():
		return
	while active_session_id == 0:
		var all_columns_exited := true
		for column: RainColumn in columns:
			var tail_y := column.head_y - float(column.length - 1) * column.step_y
			if tail_y <= size.y:
				all_columns_exited = false
				break
		if all_columns_exited and reply_glyphs.is_empty():
			break
		await get_tree().process_frame
	pass


func on_turn_start() -> void:
	reasoning_energy = maxf(reasoning_energy, 0.52)
	pass


func on_turn_end() -> void:
	drain_available_sentences()
	reasoning_energy = minf(reasoning_energy, 0.32)
	pass


func on_message_update(chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		reasoning_energy = minf(1.0, reasoning_energy + 0.08 + float(chunk.length()) / 220.0)
	queue_redraw()
	pass


func on_tool_execution_start(tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	ensure_columns()
	var column_index := find_tool_column(tool_call_id)
	if column_index < 0:
		return
	var column := columns[column_index]
	column.tool_id = tool_call_id
	column.tool_label = compact_tool_name(tool_name)
	column.tool_state = ToolState.RUNNING
	column.highlight = 1.0
	column.release_pending = false
	column.head_y = -column.step_y
	active_tools[tool_call_id] = column_index
	reasoning_energy = 1.0
	queue_redraw()
	pass


func on_tool_execution_end(tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if not active_tools.has(tool_call_id):
		return
	var column_index: int = active_tools[tool_call_id]
	if column_index >= 0 and column_index < columns.size():
		var column := columns[column_index]
		column.tool_state = ToolState.FAILED if result.is_error else ToolState.SUCCESS
		column.highlight = 1.0
		column.release_pending = true
	active_tools.erase(tool_call_id)
	queue_redraw()
	pass


func on_theme_changed() -> void:
	queue_redraw()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	ensure_columns()
	elapsed += delta
	sentence_timer += delta
	if active_session_id != 0 and sentence_timer >= SENTENCE_INTERVAL_SECONDS:
		sentence_timer = fmod(sentence_timer, SENTENCE_INTERVAL_SECONDS)
		offer_next_sentence()
	glyph_clock += delta
	if glyph_clock >= GLYPH_REFRESH_SECONDS:
		glyph_tick += 1
		glyph_clock = fmod(glyph_clock, GLYPH_REFRESH_SECONDS)
	reasoning_energy = move_toward(reasoning_energy, 0.12, delta * 0.48)
	for column: RainColumn in columns:
		column.head_y += column.speed * delta
		var wrap_height := size.y + float(column.length) * column.step_y
		if active_session_id != 0 and column.head_y > wrap_height:
			if column.release_pending:
				clear_tool_column(column)
			column.head_y = -float(column.length) * column.step_y
			column.cycle += 1
		var state := column.tool_state
		if state == ToolState.SUCCESS or state == ToolState.FAILED:
			column.highlight = move_toward(column.highlight, 0.72, delta * 0.72)
	for index in range(reply_glyphs.size() - 1, -1, -1):
		var reply_glyph := reply_glyphs[index]
		reply_glyph.y += reply_glyph.speed * delta
		if reply_glyph.y > size.y + 32.0:
			if reply_glyph.releases_rain_slot:
				active_reply_rain_count = maxi(active_reply_rain_count - 1, 0)
			reply_glyphs.remove_at(index)
	queue_redraw()
	pass


func clear_tool_column(column: RainColumn) -> void:
	column.tool_id = ""
	column.tool_label = ""
	column.tool_state = ToolState.NONE
	column.highlight = 0.0
	column.release_pending = false
	pass


func offer_next_sentence() -> bool:
	if active_reply_rain_count >= MAX_REPLY_RAINS:
		return false
	var sentence := pending_sentence
	if sentence.is_empty():
		sentence = sentence_cursor.take_next_from_session(active_session_id)
	if sentence.is_empty():
		return false
	if active_reply_rain_count + reply_rain_count(sentence) > MAX_REPLY_RAINS:
		pending_sentence = sentence
		return false
	pending_sentence = ""
	ingest_sentence(sentence)
	return true


func drain_available_sentences() -> void:
	while active_session_id != 0 and offer_next_sentence():
		pass
	pass


func reply_rain_count(sentence: String) -> int:
	var character_count := 0
	for character: String in sentence:
		if not character.strip_edges().is_empty():
			character_count += 1
	return mini(ceili(float(character_count) / float(REPLY_COLUMN_LENGTH)), MAX_REPLY_RAINS)


func ingest_sentence(sentence: String) -> void:
	spawn_reply_rain(sentence)
	queue_redraw()
	pass


func spawn_reply_rain(sentence: String) -> void:
	var characters: String = ""
	for character: String in sentence:
		if not character.strip_edges().is_empty():
			characters += character
	if characters.is_empty():
		return
	reply_sentence_index += 1
	var spacing := maxf(MIN_COLUMN_STEP, size.x / float(maxi(columns.size(), 1)))
	var first_slot: int = (reply_sentence_index * 11) % maxi(columns.size(), 1)
	var rain_speed: float = 0.0
	for character_index: int in range(characters.length()):
		var local_column: int = character_index / REPLY_COLUMN_LENGTH
		var row: int = character_index % REPLY_COLUMN_LENGTH
		if row == 0:
			if active_reply_rain_count >= MAX_REPLY_RAINS:
				return
			active_reply_rain_count += 1
			rain_speed = randf_range(MIN_REPLY_RAIN_SPEED, MAX_REPLY_RAIN_SPEED)
		var slot: int = (first_slot + local_column) % maxi(columns.size(), 1)
		var x: float = (float(slot) + 0.5) * spacing
		var start_y: float = -36.0 - float(row) * 22.0 - float(local_column) * 48.0
		var reply_glyph := ReplyGlyph.new()
		reply_glyph.text = characters.substr(character_index, 1)
		reply_glyph.x = x
		reply_glyph.y = start_y
		reply_glyph.speed = rain_speed
		reply_glyph.releases_rain_slot = row == REPLY_COLUMN_LENGTH - 1 or character_index == characters.length() - 1
		reply_glyphs.append(reply_glyph)
	pass


func ensure_columns() -> void:
	if size.x < 1.0 or is_equal_approx(layout_width, size.x):
		return
	layout_width = size.x
	var old_tools: Array[RainColumn] = []
	for column: RainColumn in columns:
		if not column.tool_id.is_empty():
			old_tools.append(column)
	columns.clear()
	active_tools.clear()
	var count := clampi(floori(size.x / MIN_COLUMN_STEP), 12, MAX_COLUMNS)
	var spacing := size.x / float(count)
	for index in range(count):
		var random_seed := index * 7919 + 104729
		var column := RainColumn.new()
		column.x = (float(index) + 0.5) * spacing
		column.head_y = -float(random_seed % 900)
		column.speed = 74.0 + float(random_seed % 93)
		column.length = 8 + random_seed % (MAX_TRAIL_LENGTH - 7)
		column.step_y = 18.0 + float(random_seed % 4)
		column.random_seed = random_seed
		columns.append(column)
	for old_tool: RainColumn in old_tools:
		var id := old_tool.tool_id
		var new_index := find_tool_column(id)
		if new_index < 0:
			continue
		var new_column := columns[new_index]
		new_column.tool_id = id
		new_column.tool_label = old_tool.tool_label
		new_column.tool_state = old_tool.tool_state
		new_column.highlight = old_tool.highlight
		new_column.release_pending = old_tool.release_pending
		if old_tool.tool_state == ToolState.RUNNING:
			active_tools[id] = new_index
	pass


func find_tool_column(tool_call_id: String) -> int:
	if columns.is_empty():
		return -1
	var hash_value: int = tool_call_id.hash()
	var preferred: int = absi(hash_value) % columns.size()
	for offset: int in range(columns.size()):
		var index: int = (preferred + offset * 7) % columns.size()
		if columns[index].tool_id.is_empty():
			return index
	return preferred


func _draw() -> void:
	if size.x < 160.0 or size.y < 140.0:
		return
	# Rain overlays the chat surface, so paint no full-rect wash: a translucent film over the
	# whole effect reads as a blur layer on the content below even without a blur shader.
	for column: RainColumn in columns:
		draw_column(column)
	for reply_glyph: ReplyGlyph in reply_glyphs:
		draw_reply_glyph(reply_glyph)
	pass


func draw_reply_glyph(reply_glyph: ReplyGlyph) -> void:
	var y := reply_glyph.y
	if y < -28.0 or y > size.y + 28.0:
		return
	var edge_fade: float = smoothstep(-24.0, 48.0, y) * (1.0 - smoothstep(size.y - 100.0, size.y + 24.0, y))
	var position := Vector2(reply_glyph.x, y)
	var color := ThemeColor.accent_theme_color()
	draw_centered_text(position, reply_glyph.text, Fonts.semibold(), Typography.label_medium_size, Color(color, edge_fade * 0.92))
	pass


func draw_column(column: RainColumn) -> void:
	var accent := matrix_color()
	var state := column.tool_state
	var highlight := column.highlight
	var color := tool_color(state) if state != ToolState.NONE else accent
	var trail_length := column.length
	var step_y := column.step_y
	var head_y := column.head_y
	var x := column.x
	var random_seed := column.random_seed + column.cycle * 131
	for row in range(trail_length):
		var y := head_y - float(row) * step_y
		if y < -step_y or y > size.y + step_y:
			continue
		var fade := 1.0 - float(row) / float(trail_length)
		fade = fade * fade
		var glyph := RandomUtils.random_char_at(random_seed, row, glyph_tick)
		var alpha := (0.08 + fade * 0.42) * (1.0 + reasoning_energy * 0.32)
		if state != ToolState.NONE:
			alpha = minf(1.0, alpha + highlight * (0.18 + fade * 0.58))
		var draw_color := Color(color, alpha)
		if row == 0:
			draw_color = Color(1.0, 1.0, 1.0, 0.62 + highlight * 0.35)
		var jitter := sin(elapsed * 36.0 + float(row)) * 2.5 * highlight if state == ToolState.FAILED else 0.0
		draw_centered_text(Vector2(x + jitter, y), glyph, Fonts.medium(), Typography.label_small_size, draw_color)
	if state != ToolState.NONE and not column.tool_label.is_empty():
		var label_y := head_y - float(trail_length) * step_y - 5.0
		draw_centered_text(Vector2(x, label_y), column.tool_label, Fonts.semibold(), Typography.label_small_size, Color(color, 0.45 + highlight * 0.5))
	pass


func matrix_color() -> Color:
	var classic_green := Color("42f58d")
	return classic_green.lerp(ThemeColor.accent_theme_color(), 0.34)


static func tool_color(state: ToolState) -> Color:
	match state:
		ToolState.SUCCESS:
			return ColorBase.success
		ToolState.FAILED:
			return ColorBase.error
	return ThemeColor.accent_theme_color()


static func compact_tool_name(tool_name: String) -> String:
	var label := VisualToolFormatter.title_name(tool_name).to_upper()
	if label.length() > 10:
		label = label.left(10)
	return label
