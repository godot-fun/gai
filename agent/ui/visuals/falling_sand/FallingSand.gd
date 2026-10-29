class_name FallingSand
extends SimulationEffect

## Falling sand hourglass (沙漏沉积): the run settles over the interface as sand strata. Streamed
## answers pour from a spout that sweeps along the window top like a typing caret and builds dunes,
## reasoning sifts a fine pale layer across the whole width, and each new turn lays a dark divider
## line. Every running tool pours its own colored stream from its column; a failed tool soaks the
## sand under that column so it clumps into steep towers that slump once they dry. Once the pile
## grows too tall the floor leaks slowly, like the neck of an hourglass. A successful run flips
## the hourglass and the whole record pours back up.

const FIELD_SHADER: Shader = preload("res://agent/ui/visuals/falling_sand/FallingSandField.gdshader")
const DISPLAY_SHADER: Shader = preload("res://agent/ui/visuals/falling_sand/FallingSand.gdshader")

enum Stamp { POUR, ROW, WET }

const PASS_COUNT := 4
const CONTENT_TAG := 0.5
const REASONING_TAG := 0.02
const DIVIDER_TAG := 0.98
const MAX_FAUCETS := 8
const POUR_RADIUS := 0.006
const CONTENT_DENSITY := 0.5
const FAUCET_RADIUS := 0.0045
const FAUCET_DENSITY := 0.5
## Pour disks are this squashed vertically, so they stand 1 / POUR_SQUASH times taller than wide.
const POUR_SQUASH := 0.4
const ROW_HALF_HEIGHT := 0.004
const REASONING_DENSITY := 0.035
const DIVIDER_DENSITY := 0.15
const DIVIDER_SECONDS := 0.2
const STREAM_FLOW_GAIN := 10.0
const FLOW_DECAY_PER_SECOND := 1.4
const MIN_FLOW := 0.02
const POUR_DRIFT_PER_SECOND := 0.11
const POUR_MIN_X := 0.16
const POUR_MAX_X := 0.84
const POUR_Y_OFFSET := 0.012
const WET_HALF_WIDTH := 0.05
## Wetness lost per second; grains stop sliding while wetness stays above one half.
const DRY_PER_SECOND := 0.18
## Fraction of the field the pile may fill before the floor starts to leak.
const FILL_LIMIT := 0.22
const DRAIN_RATE := 0.03
const FLIP_MSEC := 1300
const FALLBACK_FIELD := Vector2i(427, 240)

var faucets: Dictionary[String, Vector2] = {}
var content_flow: float = 0.0
var reasoning_flow: float = 0.0
var pour_x: float = 0.3
var pour_direction: float = 1.0
var divider_time: float = 0.0
var turn_index: int = 0
var gravity_up: bool = false
var dry_step: float = 0.0
var drain: float = 0.0
## CPU estimate of grains in the field; only used to decide when the floor leaks.
var estimated_grains: float = 0.0
var field_cells: Vector2i = FALLBACK_FIELD


func field_shader() -> Shader:
	return FIELD_SHADER


func display_shader() -> Shader:
	return DISPLAY_SHADER


func pass_kinds() -> PackedInt32Array:
	var kinds := PackedInt32Array()
	kinds.resize(PASS_COUNT)
	for index in range(PASS_COUNT):
		kinds[index] = index
	return kinds


func field_downscale() -> float:
	return 3.0


func activity_decay_per_second() -> float:
	return 0.9


func _ready() -> void:
	super._ready()
	field_cells = compute_field_size()
	chain.set_pass_param(0, "pour_squash", POUR_SQUASH)
	pass


func on_viewport_size_changed() -> void:
	super.on_viewport_size_changed()
	field_cells = compute_field_size()
	estimated_grains = 0.0
	pass


func on_agent_start(session_id: int) -> void:
	super.on_agent_start(session_id)
	faucets.clear()
	content_flow = 0.0
	reasoning_flow = 0.0
	pour_x = 0.3
	pour_direction = 1.0
	divider_time = 0.0
	turn_index = 0
	gravity_up = false
	drain = 0.0
	estimated_grains = 0.0
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	faucets.clear()
	content_flow = 0.0
	reasoning_flow = 0.0
	if StringUtils.is_not_blank(error_message):
		queue_impulse(Vector2(0.5, 0.0), 1.0, 1.0, Vector4(Stamp.WET, 0.0, 1.0, 0.0))
	else:
		gravity_up = true
		if is_inside_tree():
			await get_tree().create_timer(FLIP_MSEC / 1000.0).timeout
	await super.on_agent_end(session_id, error_message)
	pass


func on_turn_start(_session_id: int) -> void:
	if turn_index > 0:
		divider_time = DIVIDER_SECONDS
	turn_index += 1
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var flow := stream_energy_for_length(chunk.length()) * STREAM_FLOW_GAIN
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		reasoning_flow = minf(reasoning_flow + flow, 1.0)
	else:
		content_flow = minf(content_flow + flow, 1.0)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	if not faucets.has(tool_call_id) and faucets.size() >= MAX_FAUCETS:
		faucets.erase(faucets.keys()[0])
	faucets[tool_call_id] = Vector2(tool_anchor(tool_name).x, tool_tag(tool_name))
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var x := faucets[tool_call_id].x if faucets.has(tool_call_id) else tool_anchor(tool_name).x
	faucets.erase(tool_call_id)
	if result.is_error:
		failure_tint = 1.0
		queue_impulse(Vector2(x, ceiling_uv()), WET_HALF_WIDTH, 1.0, Vector4(Stamp.WET, 0.0, 1.0, 0.0))
	pass


func step_field(delta: float) -> void:
	content_flow = move_toward(content_flow, 0.0, FLOW_DECAY_PER_SECOND * delta)
	reasoning_flow = move_toward(reasoning_flow, 0.0, FLOW_DECAY_PER_SECOND * delta)
	dry_step = DRY_PER_SECOND * delta
	drain = DRAIN_RATE if not gravity_up and estimated_fill() > FILL_LIMIT else 0.0
	estimated_grains = maxf(estimated_grains - float(field_cells.x) * drain, 0.0)
	if gravity_up:
		return
	var top := ceiling_uv() + POUR_Y_OFFSET
	if content_flow > MIN_FLOW:
		advance_pour(delta)
		pour(Vector2(pour_x, top), POUR_RADIUS, content_flow * CONTENT_DENSITY, CONTENT_TAG)
	if reasoning_flow > MIN_FLOW:
		sprinkle_row(top, reasoning_flow * REASONING_DENSITY, REASONING_TAG)
	if divider_time > 0.0:
		divider_time -= delta
		sprinkle_row(top, DIVIDER_DENSITY, DIVIDER_TAG)
	for faucet: Vector2 in faucets.values():
		pour(Vector2(faucet.x, top), FAUCET_RADIUS, FAUCET_DENSITY, faucet.y)
	pass


## Sweeps the answer spout back and forth like a typing caret, faster while text streams in.
func advance_pour(delta: float) -> void:
	pour_x += pour_direction * POUR_DRIFT_PER_SECOND * delta * (0.5 + content_flow)
	if pour_x > POUR_MAX_X:
		pour_x = POUR_MAX_X
		pour_direction = -1.0
	elif pour_x < POUR_MIN_X:
		pour_x = POUR_MIN_X
		pour_direction = 1.0
	pass


func pour(position: Vector2, radius: float, density: float, tag: float) -> void:
	if queue_impulse(position, radius, density, Vector4(Stamp.POUR, tag, 0.0, 0.0)):
		var cells := radius * float(field_cells.y)
		estimated_grains += PI * cells * cells / POUR_SQUASH * density
	pass


func sprinkle_row(y: float, density: float, tag: float) -> void:
	if queue_impulse(Vector2(0.5, y), ROW_HALF_HEIGHT, density, Vector4(Stamp.ROW, tag, 0.0, 0.0)):
		estimated_grains += float(field_cells.x) * ROW_HALF_HEIGHT * 2.0 * float(field_cells.y) * density
	pass


func estimated_fill() -> float:
	return estimated_grains / float(maxi(field_cells.x * field_cells.y, 1))


## The simulation covers the entire visual overlay, including the application toolbar.
func ceiling_uv() -> float:
	return 0.0


func apply_field_state() -> void:
	chain.set_param("gravity_up", gravity_up)
	chain.set_param("ceiling_uv", ceiling_uv())
	chain.set_pass_param(0, "dry_step", dry_step)
	chain.set_pass_param(0, "drain", drain)
	display_material.set_shader_parameter("gravity_up", gravity_up)
	pass


func update_theme_presentation() -> void:
	if display_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	display_material.set_shader_parameter("accent_color", VisualColor.appearance_color(ThemeColor.accent_theme_color()))
	display_material.set_shader_parameter("error_color", Colors.error)
	display_material.set_shader_parameter("pale_color", Color(0.86, 0.82, 0.72) if dark else Color(0.62, 0.57, 0.48))
	display_material.set_shader_parameter("divider_color", Color(0.32, 0.29, 0.26) if dark else Color(0.25, 0.22, 0.2))
	display_material.set_shader_parameter("sand_opacity", 0.82 if dark else 0.76)
	pass


## Stable hue tag for a tool, kept clear of the content tag and the pale/divider ends.
static func tool_tag(tool_name: String) -> float:
	var tag := 0.1 + float(absi(tool_name.hash()) % 1000) / 1000.0 * 0.8
	return tag if absf(tag - CONTENT_TAG) > 0.08 else tag + 0.16
