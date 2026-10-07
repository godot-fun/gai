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
const MAX_REPLY_RAIN_SPEED := 180.0
const GLYPHS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ{}[]<>/\\|+-=*:#@$%&!?"

enum ToolState { NONE, RUNNING, SUCCESS, FAILED }

var columns: Array[Dictionary] = []
var active_tools: Dictionary[String, int] = {}
var elapsed: float = 0.0
var glyph_clock: float = 0.0
var glyph_frame: int = 0
var reasoning_energy: float = 0.0
var layout_width: float = -1.0
var active_session_id: int = 0
var sentence_timer: float = 0.0
var sentence_cursor: VisualChatSentenceCursor = VisualChatSentenceCursor.new()
var reply_glyphs: Array[Dictionary] = []
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
	glyph_frame = 0
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


func on_agent_end(error_message: String) -> float:
	return 0.35 if StringUtils.is_not_blank(error_message) else 0.2


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
	var column: Dictionary = columns[column_index]
	column["tool_id"] = tool_call_id
	column["tool_label"] = compact_tool_name(tool_name)
	column["tool_state"] = ToolState.RUNNING
	column["highlight"] = 1.0
	column["release_pending"] = false
	column["head_y"] = -float(column["step_y"])
	active_tools[tool_call_id] = column_index
	reasoning_energy = 1.0
	queue_redraw()
	pass


func on_tool_execution_end(tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if not active_tools.has(tool_call_id):
		return
	var column_index: int = active_tools[tool_call_id]
	if column_index >= 0 and column_index < columns.size():
		var column: Dictionary = columns[column_index]
		column["tool_state"] = ToolState.FAILED if result.is_error else ToolState.SUCCESS
		column["highlight"] = 1.0
		column["release_pending"] = true
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
		glyph_frame += 1
		glyph_clock = fmod(glyph_clock, GLYPH_REFRESH_SECONDS)
	reasoning_energy = move_toward(reasoning_energy, 0.12, delta * 0.48)
	for column: Dictionary in columns:
		column["head_y"] = float(column["head_y"]) + float(column["speed"]) * delta
		var wrap_height := size.y + float(column["length"]) * float(column["step_y"])
		if float(column["head_y"]) > wrap_height:
			if bool(column["release_pending"]):
				clear_tool_column(column)
			column["head_y"] = -float(column["length"]) * float(column["step_y"])
			column["cycle"] = int(column["cycle"]) + 1
		var state: ToolState = int(column["tool_state"]) as ToolState
		if state == ToolState.SUCCESS or state == ToolState.FAILED:
			column["highlight"] = move_toward(float(column["highlight"]), 0.72, delta * 0.72)
	for index in range(reply_glyphs.size() - 1, -1, -1):
		var reply_glyph: Dictionary = reply_glyphs[index]
		reply_glyph["y"] = float(reply_glyph["y"]) + float(reply_glyph["speed"]) * delta
		if float(reply_glyph["y"]) > size.y + 32.0:
			if bool(reply_glyph["releases_rain_slot"]):
				active_reply_rain_count = maxi(active_reply_rain_count - 1, 0)
			reply_glyphs.remove_at(index)
	queue_redraw()
	pass


func clear_tool_column(column: Dictionary) -> void:
	column["tool_id"] = ""
	column["tool_label"] = ""
	column["tool_state"] = ToolState.NONE
	column["highlight"] = 0.0
	column["release_pending"] = false
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
		reply_glyphs.append({
			"text": characters.substr(character_index, 1),
			"x": x,
			"y": start_y,
			"speed": rain_speed,
			"releases_rain_slot": row == REPLY_COLUMN_LENGTH - 1 or character_index == characters.length() - 1,
		})
	pass


func ensure_columns() -> void:
	if size.x < 1.0 or is_equal_approx(layout_width, size.x):
		return
	layout_width = size.x
	var old_tools: Array[Dictionary] = []
	for column: Dictionary in columns:
		if not String(column["tool_id"]).is_empty():
			old_tools.append(column)
	columns.clear()
	active_tools.clear()
	var count := clampi(floori(size.x / MIN_COLUMN_STEP), 12, MAX_COLUMNS)
	var spacing := size.x / float(count)
	for index in range(count):
		var seed := index * 7919 + 104729
		columns.append({
			"x": (float(index) + 0.5) * spacing,
			"head_y": -float(seed % 900),
			"speed": 74.0 + float(seed % 93),
			"length": 8 + seed % (MAX_TRAIL_LENGTH - 7),
			"step_y": 18.0 + float(seed % 4),
			"seed": seed,
			"cycle": 0,
			"tool_id": "",
			"tool_label": "",
			"tool_state": ToolState.NONE,
			"highlight": 0.0,
			"release_pending": false,
		})
	for old_tool: Dictionary in old_tools:
		var id := String(old_tool["tool_id"])
		var new_index := find_tool_column(id)
		if new_index < 0:
			continue
		columns[new_index]["tool_id"] = id
		columns[new_index]["tool_label"] = old_tool["tool_label"]
		columns[new_index]["tool_state"] = old_tool["tool_state"]
		columns[new_index]["highlight"] = old_tool["highlight"]
		columns[new_index]["release_pending"] = old_tool["release_pending"]
		if int(old_tool["tool_state"]) == ToolState.RUNNING:
			active_tools[id] = new_index
	pass


func find_tool_column(tool_call_id: String) -> int:
	if columns.is_empty():
		return -1
	var hash_value: int = tool_call_id.hash()
	var preferred: int = absi(hash_value) % columns.size()
	for offset: int in range(columns.size()):
		var index: int = (preferred + offset * 7) % columns.size()
		if String(columns[index]["tool_id"]).is_empty():
			return index
	return preferred


func _draw() -> void:
	if size.x < 160.0 or size.y < 140.0:
		return
	var overlay_alpha := 0.12 if ThemeColor.is_dark_theme() else 0.055
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.035, 0.018, overlay_alpha))
	for column: Dictionary in columns:
		draw_column(column)
	for reply_glyph: Dictionary in reply_glyphs:
		draw_reply_glyph(reply_glyph)
	pass


func draw_reply_glyph(reply_glyph: Dictionary) -> void:
	var y: float = reply_glyph["y"]
	if y < -28.0 or y > size.y + 28.0:
		return
	var edge_fade: float = smoothstep(-24.0, 48.0, y) * (1.0 - smoothstep(size.y - 100.0, size.y + 24.0, y))
	var position := Vector2(float(reply_glyph["x"]), y)
	var color := ThemeColor.accent_theme_color()
	draw_centered_text(position, String(reply_glyph["text"]), Fonts.semibold(), Typography.label_medium_size, Color(color, edge_fade * 0.92))
	pass


func draw_column(column: Dictionary) -> void:
	var accent := matrix_color()
	var state: ToolState = int(column["tool_state"]) as ToolState
	var highlight: float = column["highlight"]
	var color := tool_color(state) if state != ToolState.NONE else accent
	var trail_length: int = column["length"]
	var step_y: float = column["step_y"]
	var head_y: float = column["head_y"]
	var x: float = column["x"]
	var seed: int = column["seed"] + int(column["cycle"]) * 131
	for row in range(trail_length):
		var y := head_y - float(row) * step_y
		if y < -step_y or y > size.y + step_y:
			continue
		var fade := 1.0 - float(row) / float(trail_length)
		fade = fade * fade
		var glyph := glyph_at(seed, row, glyph_frame)
		var alpha := (0.08 + fade * 0.42) * (1.0 + reasoning_energy * 0.32)
		if state != ToolState.NONE:
			alpha = minf(1.0, alpha + highlight * (0.18 + fade * 0.58))
		var draw_color := Color(color, alpha)
		if row == 0:
			draw_color = Color(1.0, 1.0, 1.0, 0.62 + highlight * 0.35)
		var jitter := sin(elapsed * 36.0 + float(row)) * 2.5 * highlight if state == ToolState.FAILED else 0.0
		draw_centered_text(Vector2(x + jitter, y), glyph, Fonts.medium(), Typography.label_small_size, draw_color)
	if state != ToolState.NONE and not String(column["tool_label"]).is_empty():
		var label_y := head_y - float(trail_length) * step_y - 5.0
		draw_centered_text(Vector2(x, label_y), String(column["tool_label"]), Fonts.semibold(), Typography.label_small_size, Color(color, 0.45 + highlight * 0.5))
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


static func glyph_at(seed: int, row: int, frame: int) -> String:
	var refresh_offset: int = frame / (2 + absi(seed + row) % 4)
	var index: int = absi(seed * 31 + row * 17 + refresh_offset * 13) % GLYPHS.length()
	return GLYPHS.substr(index, 1)


static func compact_tool_name(tool_name: String) -> String:
	var label := VisualToolFormatter.title_name(tool_name).to_upper()
	if label.length() > 10:
		label = label.left(10)
	return label
