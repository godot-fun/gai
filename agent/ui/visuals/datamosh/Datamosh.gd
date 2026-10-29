class_name Datamosh
extends SimulationEffect

## Datamosh (数据坏帧): the interface plays like a video that lost its keyframes. Every frame the
## previous picture is dragged along per-macroblock motion vectors, and stuck blocks keep showing
## that smeared picture instead of the live one. Streamed text pushes pixels downward, reasoning
## jitters them, a running tool stirs a swirl around its spot, and a failed tool bursts the blocks
## outward into corrupted color. A successful tool or the end of a turn lands a keyframe that
## sweeps the screen clean.

const FIELD_SHADER: Shader = preload("res://agent/ui/visuals/datamosh/DatamoshField.gdshader")
const DISPLAY_SHADER: Shader = preload("res://agent/ui/visuals/datamosh/Datamosh.gdshader")
const PASS_KINDS: PackedInt32Array = [0, 1]
const MAX_SOURCES := 4
const BLOCK_PX := 16.0
const RUN_MOSH := 0.12
const MAX_MOSH := 0.38
const MOSH_DECAY_PER_SECOND := 0.22
const STREAM_MOSH_GAIN := 1.2
const REASONING_MOSH_SCALE := 0.4
const MAX_DRIFT_PX := 2.0
const STREAM_DRIFT_GAIN := 30.0
const DRIFT_DECAY_PER_SECOND := 1.5
const MAX_JITTER_PX := 2.0
const STREAM_JITTER_GAIN := 25.0
const JITTER_DECAY_PER_SECOND := 1.5
const CORRUPTION_DECAY_PER_SECOND := 0.7
const KEYFRAME_SWEEP_PER_SECOND := 3.5
const KEYFRAME_IDLE := 1.2
const RESEED_PER_SECOND := 2.5
const SWIRL_RADIUS := 0.16
const SWIRL_PX := 2.5
const SWIRL_MOSH := 0.55
const BURST_RADIUS := 0.26
const BURST_PX := 6.0
const SOURCE_DECAY_PER_SECOND := 0.6
const ERROR_BURST_MSEC := 600


class MotionSource extends RefCounted:
	var key: String = ""
	## Screen UV.
	var center: Vector2 = Vector2(0.5, 0.5)
	## Viewport-height units.
	var radius: float = 0.1
	var swirl: float = 0.0
	var burst: float = 0.0
	var mosh: float = 0.0
	## Held at full strength while its tool is still running.
	var holding: bool = false


var mosh: float = 0.0
var mosh_floor: float = 0.0
var drift: float = 0.0
var jitter: float = 0.0
var corruption: float = 0.0
var keyframe: float = KEYFRAME_IDLE
var sources: Array[MotionSource] = []


func field_shader() -> Shader:
	return FIELD_SHADER


func display_shader() -> Shader:
	return DISPLAY_SHADER


func pass_kinds() -> PackedInt32Array:
	return PASS_KINDS


func field_downscale() -> float:
	return 1.0


func reads_previous_frame() -> bool:
	return true


func activity_decay_per_second() -> float:
	return 0.8


func on_agent_start(session_id: int) -> void:
	super.on_agent_start(session_id)
	sources.clear()
	mosh_floor = RUN_MOSH
	drift = 0.0
	jitter = 0.0
	corruption = 0.0
	land_keyframe()
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	mosh_floor = 0.0
	if StringUtils.is_not_blank(error_message):
		burst_at(Vector2(0.5, 0.55), "end")
		if is_inside_tree():
			await get_tree().create_timer(ERROR_BURST_MSEC / 1000.0).timeout
	land_keyframe()
	await super.on_agent_end(session_id, error_message)
	pass


func on_turn_end(_session_id: int) -> void:
	land_keyframe()
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		jitter = minf(jitter + energy * STREAM_JITTER_GAIN, MAX_JITTER_PX)
		mosh = minf(mosh + energy * STREAM_MOSH_GAIN * REASONING_MOSH_SCALE, MAX_MOSH)
	else:
		drift = minf(drift + energy * STREAM_DRIFT_GAIN, MAX_DRIFT_PX)
		mosh = minf(mosh + energy * STREAM_MOSH_GAIN, MAX_MOSH)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	var source := add_source(tool_call_id, tool_anchor(tool_name), SWIRL_RADIUS)
	source.swirl = SWIRL_PX if tool_name.hash() % 2 == 0 else -SWIRL_PX
	source.mosh = SWIRL_MOSH
	source.holding = true
	bump_activity(0.6)
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var source := find_source(tool_call_id)
	if source != null:
		source.holding = false
	if result.is_error:
		burst_at(tool_anchor(tool_name), tool_call_id)
	else:
		land_keyframe()
	pass


## A keyframe sweeps every row clean from the top and drops the stuck-block level.
func land_keyframe() -> void:
	keyframe = 0.0
	mosh = minf(mosh, mosh_floor * 0.5)
	corruption = 0.0
	for source: MotionSource in sources:
		source.holding = false
		source.mosh *= 0.3
	pass


func burst_at(center: Vector2, key: String) -> void:
	var source := find_source(key)
	if source == null:
		source = add_source(key, center, BURST_RADIUS)
	source.radius = BURST_RADIUS
	source.burst = BURST_PX
	source.swirl *= 2.0
	source.mosh = 1.0
	source.holding = false
	corruption = 1.0
	failure_tint = 1.0
	keyframe = KEYFRAME_IDLE
	bump_activity(1.0)
	pass


func add_source(key: String, center: Vector2, radius: float) -> MotionSource:
	if sources.size() >= MAX_SOURCES:
		sources.remove_at(0)
	var source := MotionSource.new()
	source.key = key
	source.center = center
	source.radius = radius
	sources.append(source)
	return source


func find_source(key: String) -> MotionSource:
	for source: MotionSource in sources:
		if source.key == key:
			return source
	return null


func step_field(delta: float) -> void:
	mosh = move_toward(mosh, mosh_floor, MOSH_DECAY_PER_SECOND * delta)
	drift = move_toward(drift, 0.0, DRIFT_DECAY_PER_SECOND * delta)
	jitter = move_toward(jitter, 0.0, JITTER_DECAY_PER_SECOND * delta)
	corruption = move_toward(corruption, 0.0, CORRUPTION_DECAY_PER_SECOND * delta)
	if keyframe < KEYFRAME_IDLE:
		keyframe = minf(keyframe + KEYFRAME_SWEEP_PER_SECOND * delta, KEYFRAME_IDLE)
	var fade := exp(-SOURCE_DECAY_PER_SECOND * delta * 3.0)
	for index in range(sources.size() - 1, -1, -1):
		var source := sources[index]
		if source.holding:
			continue
		source.swirl *= fade
		source.burst *= fade
		source.mosh *= fade
		if absf(source.swirl) < 0.05 and source.burst < 0.05 and source.mosh < 0.01:
			sources.remove_at(index)
	pass


func apply_field_state() -> void:
	var shapes := PackedVector4Array()
	var motions := PackedVector4Array()
	shapes.resize(MAX_SOURCES)
	motions.resize(MAX_SOURCES)
	for index in range(sources.size()):
		var source := sources[index]
		shapes[index] = Vector4(source.center.x, source.center.y, source.radius, source.mosh)
		motions[index] = Vector4(source.swirl, source.burst, 0.0, 0.0)
	var block_seed := floorf(field_time * RESEED_PER_SECOND)
	chain.set_param("viewport_px", get_viewport().get_visible_rect().size)
	chain.set_param("block_px", BLOCK_PX)
	chain.set_param("drift_px", drift)
	chain.set_param("jitter_px", jitter)
	chain.set_param("block_seed", block_seed)
	chain.set_param("source_count", sources.size())
	chain.set_param("source_shapes", shapes)
	chain.set_param("source_motion", motions)
	display_material.set_shader_parameter("mosh", mosh)
	display_material.set_shader_parameter("corruption", corruption)
	display_material.set_shader_parameter("keyframe", keyframe)
	display_material.set_shader_parameter("block_px", BLOCK_PX)
	display_material.set_shader_parameter("block_seed", block_seed)
	display_material.set_shader_parameter("source_count", sources.size())
	display_material.set_shader_parameter("source_shapes", shapes)
	pass


func update_theme_presentation() -> void:
	if display_material == null:
		return
	display_material.set_shader_parameter("keyframe_color", VisualColor.appearance_color(ThemeColor.accent_theme_color()))
	display_material.set_shader_parameter("corrupt_tint", Colors.error)
	pass
