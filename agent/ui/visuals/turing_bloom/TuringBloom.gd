class_name TuringBloom
extends SimulationEffect

## A Gray-Scott tissue grows across the interface while the agent works. Reasoning steers it
## toward labyrinths, streamed answers toward coral, and each tool call plants a new colony at
## its own spot. Failures bleach the tissue; the end of the run starves it until it dissolves.

const FIELD_SHADER: Shader = preload("res://agent/ui/visuals/turing_bloom/TuringBloomField.gdshader")
const DISPLAY_SHADER: Shader = preload("res://agent/ui/visuals/turing_bloom/TuringBloom.gdshader")
const PASS_COUNT := 12
const MAZE_REGIME := Vector2(0.039, 0.058)
const CORAL_REGIME := Vector2(0.0545, 0.062)
const DISSOLVE_REGIME := Vector2(0.014, 0.082)
const MIX_FOLLOW_RATE := 1.4
const DRIVE_DECAY_PER_SECOND := 0.5
const SEED_COST := 0.2
const IDLE_GROWTH := 0.55
const LIGHT_COVERAGE_GAIN := 0.34
const DARK_COVERAGE_GAIN := 0.5

var pattern_mix: float = 0.0
var target_pattern_mix: float = 0.0
var dissolve: float = 0.0
var target_dissolve: float = 0.0
var stream_drive: float = 0.0
var seed_budget: float = 0.0


func field_shader() -> Shader:
	return FIELD_SHADER


func display_shader() -> Shader:
	return DISPLAY_SHADER


func pass_kinds() -> PackedInt32Array:
	var kinds := PackedInt32Array()
	kinds.resize(PASS_COUNT)
	return kinds


func field_downscale() -> float:
	return 3.0


func activity_decay_per_second() -> float:
	return 0.55


func on_agent_start(session_id: int) -> void:
	super.on_agent_start(session_id)
	pattern_mix = 0.0
	target_pattern_mix = 0.0
	dissolve = 0.0
	target_dissolve = 0.0
	stream_drive = 0.0
	seed_budget = 0.0
	for index in range(7):
		var edge := float(index) / 6.0
		queue_impulse(Vector2(lerpf(0.06, 0.94, edge), 0.12 if index % 2 == 0 else 0.94), 0.02, 1.0)
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	target_dissolve = 1.0
	stream_drive = 1.0
	await super.on_agent_end(session_id, error_message)
	pass


func on_turn_start(_session_id: int) -> void:
	queue_impulse(Vector2(randf_range(0.2, 0.8), randf_range(0.3, 0.7)), 0.024, 1.0)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := stream_energy_for_length(chunk.length())
	stream_drive = combine_energy(stream_drive, energy * 2.0)
	seed_budget += energy
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		target_pattern_mix = 0.0
	else:
		target_pattern_mix = 1.0
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	queue_impulse(tool_anchor(tool_name), 0.02, 1.0)
	stream_drive = combine_energy(stream_drive, 0.5)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	if result.is_error:
		failure_tint = 1.0
		return
	var anchor := tool_anchor(tool_name)
	for index in range(3):
		queue_impulse(anchor + Vector2.from_angle(float(index) * TAU / 3.0 + 0.5) * 0.05, 0.012, 1.0)
	pass


func step_field(delta: float) -> void:
	var follow := 1.0 - exp(-delta * MIX_FOLLOW_RATE)
	pattern_mix = lerpf(pattern_mix, target_pattern_mix, follow)
	dissolve = lerpf(dissolve, target_dissolve, follow)
	stream_drive = move_toward(stream_drive, 0.0, DRIVE_DECAY_PER_SECOND * delta)
	while seed_budget >= SEED_COST:
		seed_budget -= SEED_COST
		var y_range := Vector2(0.55, 0.92) if target_pattern_mix > 0.5 else Vector2(0.16, 0.5)
		queue_impulse(Vector2(randf_range(0.1, 0.9), randf_range(y_range.x, y_range.y)), 0.012, 1.0)
	pass


func current_regime() -> Vector2:
	return regime_for(pattern_mix, dissolve)


func current_growth() -> float:
	return lerpf(IDLE_GROWTH, 1.0, clampf(stream_drive, 0.0, 1.0))


func apply_field_state() -> void:
	var regime := current_regime()
	chain.set_param("feed", regime.x)
	chain.set_param("kill", regime.y)
	chain.set_param("growth", current_growth())
	pass


func update_theme_presentation() -> void:
	if display_material == null:
		return
	var accent := ThemeColor.accent_theme_color()
	var dark := ThemeColor.is_dark_theme()
	display_material.set_shader_parameter("tissue_color", VisualColor.appearance_color(accent, 0.0, 0.9, 1.0))
	display_material.set_shader_parameter("membrane_color", VisualColor.appearance_color(accent, 0.08, 0.6, 0.8).lightened(0.35))
	display_material.set_shader_parameter("error_color", Colors.error)
	display_material.set_shader_parameter("coverage_gain", DARK_COVERAGE_GAIN if dark else LIGHT_COVERAGE_GAIN)
	display_material.set_shader_parameter("glow_gain", 1.0 if dark else 0.4)
	pass


static func regime_for(mix_value: float, dissolve_value: float) -> Vector2:
	var living := MAZE_REGIME.lerp(CORAL_REGIME, clampf(mix_value, 0.0, 1.0))
	return living.lerp(DISSOLVE_REGIME, clampf(dissolve_value, 0.0, 1.0))
