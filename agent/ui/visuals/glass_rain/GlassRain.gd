class_name GlassRain
extends SimulationEffect

## The interface is seen through a rainy window. Reasoning fogs the glass, streamed answers rain
## beads onto it and slowly clear the fog, and each tool call opens a rivulet that runs down from
## its own column, wiping a clear trail. Beads merge and slide once heavy enough. Failures strike
## lightning and a squall; the end of the run stops the rain and lets the fog lift.

const FIELD_SHADER: Shader = preload("res://agent/ui/visuals/glass_rain/GlassRainField.gdshader")
const DISPLAY_SHADER: Shader = preload("res://agent/ui/visuals/glass_rain/GlassRain.gdshader")
const PASS_COUNT := 2
const BASE_FOG := 0.22
const MAX_FOG := 0.85
const FOG_RELAX_PER_SECOND := 0.05
const RAIN_DECAY_PER_SECOND := 0.25
const BEADS_PER_SECOND_AT_FULL_RAIN := 70.0
const MAX_BEADS_PER_FRAME := 4
const MAX_FAUCETS := 6
const FAUCET_RATE := 0.45
const LIGHTNING_DECAY_PER_SECOND := 3.2
const LIGHT_FOG_VEIL := 0.18
const DARK_FOG_VEIL := 0.28
const LIGHT_RIM_SHADE := 0.45
const DARK_RIM_SHADE := 0.12

var fog_target: float = BASE_FOG
var rain_intensity: float = 0.0
var lightning: float = 0.0
var bead_budget: float = 0.0
## Each faucet is (screen x, remaining seconds, mass per frame).
var faucets: Array[Vector3] = []


func field_shader() -> Shader:
	return FIELD_SHADER


func display_shader() -> Shader:
	return DISPLAY_SHADER


func pass_kinds() -> PackedInt32Array:
	var kinds := PackedInt32Array()
	kinds.resize(PASS_COUNT)
	return kinds


func activity_decay_per_second() -> float:
	return 0.55


func on_agent_start(session_id: int) -> void:
	super.on_agent_start(session_id)
	fog_target = BASE_FOG
	rain_intensity = 0.25
	lightning = 0.0
	bead_budget = 0.0
	faucets.clear()
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	fog_target = 0.0
	rain_intensity = 0.0
	faucets.clear()
	if StringUtils.is_not_blank(error_message):
		lightning = 1.0
	await super.on_agent_end(session_id, error_message)
	pass


func on_turn_start(_session_id: int) -> void:
	rain_intensity = combine_energy(rain_intensity, 0.3)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		fog_target = minf(MAX_FOG, fog_target + energy * 1.6)
	else:
		rain_intensity = combine_energy(rain_intensity, energy * 2.2)
		fog_target = maxf(BASE_FOG * 0.5, fog_target - energy * 0.8)
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	rain_intensity = combine_energy(rain_intensity, 0.35)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	open_faucet(tool_anchor(tool_name).x, 0.9)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var anchor_x := tool_anchor(tool_name).x
	if result.is_error:
		failure_tint = 1.0
		lightning = 1.0
		rain_intensity = 1.0
		for offset: float in [-0.12, 0.0, 0.12]:
			open_faucet(clampf(anchor_x + offset, 0.04, 0.96), 0.7)
	else:
		open_faucet(anchor_x, 0.4)
	pass


func open_faucet(x: float, seconds: float) -> void:
	if faucets.size() >= MAX_FAUCETS:
		faucets.pop_front()
	faucets.append(Vector3(x, seconds, FAUCET_RATE))
	pass


func step_field(delta: float) -> void:
	rain_intensity = move_toward(rain_intensity, 0.0, RAIN_DECAY_PER_SECOND * delta)
	lightning = move_toward(lightning, 0.0, LIGHTNING_DECAY_PER_SECOND * delta)
	if fog_target > BASE_FOG:
		fog_target = move_toward(fog_target, BASE_FOG, FOG_RELAX_PER_SECOND * delta)
	for index in range(faucets.size() - 1, -1, -1):
		var faucet := faucets[index]
		queue_impulse(Vector2(faucet.x, 0.075), 0.008, faucet.z, Vector4(1.0, 0.0, 0.0, 0.0))
		faucet.y -= delta
		if faucet.y <= 0.0:
			faucets.remove_at(index)
		else:
			faucets[index] = faucet
	bead_budget += rain_intensity * BEADS_PER_SECOND_AT_FULL_RAIN * delta
	var beads := 0
	while bead_budget >= 1.0 and beads < MAX_BEADS_PER_FRAME:
		bead_budget -= 1.0
		beads += 1
		queue_impulse(Vector2(randf_range(0.02, 0.98), randf_range(0.08, 0.98)), randf_range(0.006, 0.012), randf_range(0.2, 0.5))
	bead_budget = minf(bead_budget, float(MAX_BEADS_PER_FRAME))
	pass


func apply_field_state() -> void:
	chain.set_param("fog_target", fog_target)
	display_material.set_shader_parameter("lightning", lightning)
	pass


func update_theme_presentation() -> void:
	if display_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	display_material.set_shader_parameter("accent_color", VisualColor.appearance_color(ThemeColor.accent_theme_color()))
	display_material.set_shader_parameter("error_color", Colors.error)
	display_material.set_shader_parameter("fog_color", Color(0.58, 0.63, 0.7) if dark else Color(0.93, 0.95, 0.97))
	display_material.set_shader_parameter("fog_veil", DARK_FOG_VEIL if dark else LIGHT_FOG_VEIL)
	display_material.set_shader_parameter("glint_gain", 1.0 if dark else 0.55)
	display_material.set_shader_parameter("rim_shade", DARK_RIM_SHADE if dark else LIGHT_RIM_SHADE)
	pass
