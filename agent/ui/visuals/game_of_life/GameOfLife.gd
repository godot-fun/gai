class_name GameOfLife
extends SimulationEffect

## Conway's Game of Life (康威生命游戏) running on the GPU over the interface. Every turn plants
## a Gosper glider gun, every tool seeds an acorn that blooms for hundreds of generations in its
## own hue, and a finished tool launches spaceships while a failed one spills red soup. Streamed
## answers sprinkle soup along a typing caret and reasoning releases stray gliders. After the
## run, the colony keeps evolving while it fades.

const FIELD_SHADER: Shader = preload("res://agent/ui/visuals/game_of_life/GameOfLifeField.gdshader")
const DISPLAY_SHADER: Shader = preload("res://agent/ui/visuals/game_of_life/GameOfLife.gdshader")

enum Pattern { SOUP, GLIDER, LWSS, ACORN, R_PENTOMINO, GOSPER_GUN }

## Rows of each stamp, "O" alive; index matches [enum Pattern] (SOUP has no stamp).
const PATTERN_ROWS: Array[Array] = [
	[],
	[".O.", "..O", "OOO"],
	[".O..O", "O....", "O...O", "OOOO."],
	[".O.....", "...O...", "OO..OOO"],
	[".OO", "OO.", ".O."],
	[
		"........................O...........",
		"......................O.O...........",
		"............OO......OO............OO",
		"...........O...O....OO............OO",
		"OO........O.....O...OO..............",
		"OO........O...O.OO....O.O...........",
		"..........O.....O.......O...........",
		"...........O...O....................",
		"............OO......................",
	],
]
const MAX_PATTERNS := 8
const PASS_COUNT := 2
const IDLE_GENERATIONS_PER_SECOND := 8.0
const MAX_GENERATIONS_PER_SECOND := 24.0
const STREAM_HEAT_GAIN := 5.0
const STREAM_HEAT_DECAY_PER_SECOND := 0.45
const TRAIL_FADE_PER_SECOND := 3.2
const SOUP_COST := 0.07
const GLIDER_COST := 0.16
const MAX_SPAWNS_PER_FRAME := 2
const CARET_STEP := 0.05
const CONTENT_TAG := 0.5
const ERROR_TAG := 1.0

var pattern_atlas: ImageTexture
var pattern_rects: PackedVector4Array = PackedVector4Array()
var generation_clock: float = 0.0
var step_now: bool = false
var trail_decay: float = 1.0
var stream_heat: float = 0.0
var content_seed: float = 0.0
var reasoning_seed: float = 0.0
var caret: Vector2 = Vector2(0.24, 0.62)
var turn_index: int = 0


func field_shader() -> Shader:
	return FIELD_SHADER


func display_shader() -> Shader:
	return DISPLAY_SHADER


func pass_kinds() -> PackedInt32Array:
	var kinds := PackedInt32Array()
	kinds.resize(PASS_COUNT)
	for index in range(PASS_COUNT):
		kinds[index] = 0 if index == 0 else 1
	return kinds


func field_downscale() -> float:
	return 6.0


func activity_decay_per_second() -> float:
	return 0.45


func _ready() -> void:
	super._ready()
	build_pattern_atlas()
	chain.set_pass_param(0, "pattern_atlas", pattern_atlas)
	chain.set_pass_param(0, "pattern_rects", pattern_rects)
	pass


func on_agent_start(session_id: int) -> void:
	super.on_agent_start(session_id)
	generation_clock = 0.0
	stream_heat = 0.0
	content_seed = 0.0
	reasoning_seed = 0.0
	caret = Vector2(0.24, 0.62)
	turn_index = 0
	queue_impulse(Vector2(0.5, 0.55), 0.09, 0.32, Vector4(Pattern.SOUP, 0.0, CONTENT_TAG, 0.0))
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	stream_heat = 0.0
	if StringUtils.is_not_blank(error_message):
		queue_impulse(Vector2(0.5, 0.5), 0.1, 0.45, Vector4(Pattern.SOUP, 0.0, ERROR_TAG, 0.0))
	await super.on_agent_end(session_id, error_message)
	pass


func on_turn_start(_session_id: int) -> void:
	var spot := Vector2(0.3 + 0.4 * fposmod(float(turn_index) * 0.618, 1.0), 0.32 + 0.3 * fposmod(float(turn_index) * 0.382, 1.0))
	queue_impulse(spot, 0.0, 1.0, Vector4(Pattern.GOSPER_GUN, turn_index % 4, CONTENT_TAG, float(turn_index % 2)))
	turn_index += 1
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := stream_energy_for_length(chunk.length())
	stream_heat = minf(stream_heat + energy * STREAM_HEAT_GAIN, 1.0)
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		reasoning_seed += energy
	else:
		content_seed += energy * 1.5
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	queue_impulse(caret, 0.0, 1.0, Vector4(Pattern.R_PENTOMINO, 0.0, CONTENT_TAG, 0.0))
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	queue_impulse(tool_anchor(tool_name), 0.0, 1.0, Vector4(Pattern.ACORN, absi(tool_name.hash()) % 4, tool_tag(tool_name), 0.0))
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var anchor := tool_anchor(tool_name)
	if result.is_error:
		failure_tint = 1.0
		queue_impulse(anchor, 0.05, 0.5, Vector4(Pattern.SOUP, 0.0, ERROR_TAG, 0.0))
		return
	var tag := tool_tag(tool_name)
	queue_impulse(anchor + Vector2(0.04, 0.0), 0.0, 1.0, Vector4(Pattern.LWSS, 0.0, tag, 0.0))
	queue_impulse(anchor - Vector2(0.04, 0.0), 0.0, 1.0, Vector4(Pattern.LWSS, 2.0, tag, 0.0))
	pass


func step_field(delta: float) -> void:
	stream_heat = move_toward(stream_heat, 0.0, STREAM_HEAT_DECAY_PER_SECOND * delta)
	trail_decay = exp(-TRAIL_FADE_PER_SECOND * delta)
	generation_clock += delta * current_generations_per_second()
	step_now = generation_clock >= 1.0
	if step_now:
		generation_clock = minf(generation_clock - 1.0, 1.0)
	var spawns := 0
	while content_seed >= SOUP_COST and spawns < MAX_SPAWNS_PER_FRAME:
		content_seed -= SOUP_COST
		spawns += 1
		advance_caret()
		queue_impulse(caret, 0.012, 0.55, Vector4(Pattern.SOUP, 0.0, CONTENT_TAG, 0.0))
	while reasoning_seed >= GLIDER_COST and spawns < MAX_SPAWNS_PER_FRAME:
		reasoning_seed -= GLIDER_COST
		spawns += 1
		var spot := Vector2(randf_range(0.1, 0.9), randf_range(0.2, 0.85))
		queue_impulse(spot, 0.0, 1.0, Vector4(Pattern.GLIDER, randi() % 4, randf_range(0.2, 0.8), float(randi() % 2)))
	pass


func current_generations_per_second() -> float:
	return lerpf(IDLE_GENERATIONS_PER_SECOND, MAX_GENERATIONS_PER_SECOND, stream_heat)


## Moves the soup caret like text being typed: left to right, then down a line.
func advance_caret() -> void:
	caret.x += CARET_STEP
	if caret.x > 0.78:
		caret.x = 0.24
		caret.y = 0.56 if caret.y > 0.82 else caret.y + 0.06
	pass


func apply_field_state() -> void:
	chain.set_pass_param(0, "step_now", step_now)
	chain.set_pass_param(0, "trail_decay", trail_decay)
	pass


func update_theme_presentation() -> void:
	if display_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	display_material.set_shader_parameter("accent_color", VisualColor.appearance_color(ThemeColor.accent_theme_color()))
	display_material.set_shader_parameter("error_color", Colors.error)
	display_material.set_shader_parameter("light_mode", 0.0 if dark else 1.0)
	display_material.set_shader_parameter("cell_opacity", 0.86 if dark else 0.78)
	display_material.set_shader_parameter("trail_opacity", 0.3 if dark else 0.22)
	pass


func build_pattern_atlas() -> void:
	var width := 1
	var height := 0
	for rows: Array in PATTERN_ROWS:
		if not rows.is_empty():
			width = maxi(width, str(rows[0]).length())
			height += rows.size()
	var image := Image.create_empty(width, maxi(height, 1), false, Image.FORMAT_R8)
	pattern_rects.resize(MAX_PATTERNS)
	var row_offset := 0
	for index in range(PATTERN_ROWS.size()):
		var rows: Array = PATTERN_ROWS[index]
		if rows.is_empty():
			continue
		pattern_rects[index] = Vector4(0.0, row_offset, str(rows[0]).length(), rows.size())
		for y in range(rows.size()):
			var row := str(rows[y])
			for x in range(row.length()):
				if row[x] == "O":
					image.set_pixel(x, row_offset + y, Color.WHITE)
		row_offset += rows.size()
	pattern_atlas = ImageTexture.create_from_image(image)
	pass


## Stable species tag for a tool, kept clear of the content tag and the error tag.
static func tool_tag(tool_name: String) -> float:
	var tag := 0.08 + float(absi(tool_name.hash()) % 1000) / 1000.0 * 0.84
	return tag if absf(tag - CONTENT_TAG) > 0.08 else tag + 0.16


static func pattern_population(pattern: Pattern) -> int:
	var count := 0
	for row: Variant in PATTERN_ROWS[pattern]:
		count += str(row).count("O")
	return count
