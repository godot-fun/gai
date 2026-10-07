class_name NeuralAurora
extends VisualEffect

## Full-screen shader-driven aurora that visualizes an agent as a digital sky waking up.
##
## Design boundary: this controller translates discrete [AgentEvents] into a small set of
## continuous shader parameters. Keep the flowing field, waves, arcs, cracks, and completion
## particles in the shader; do not replace them with large CPU-side node or particle graphs.
## See `DESIGN.md` beside this file for the event vocabulary and extension guidelines.

const SHADER_PATH := "res://agent/ui/visuals/neural_aurora/NeuralAurora.gdshader"
## Must match the completion timeline used by the shader. [VisualControl] keeps this effect
## visible for the returned duration before starting its ordinary fade-out.
const COMPLETE_SECONDS := 1.35
const MIN_TOOL_PLAY_SECONDS := 1.05
const TOOL_RESULT_HOLD_SECONDS := 0.75
const FAILURE_REVEAL_SECONDS := 0.78

var field: ColorRect
var tool_label: Label
var shader_material: ShaderMaterial
var elapsed: float = 0.0

## Long-lived field controls use a current/target pair. Events change targets abruptly while
## `_process()` applies exponential smoothing, preventing visible jumps between agent phases.
var energy: float = 0.0
var target_energy: float = 0.0
var detail: float = 0.0
var target_detail: float = 0.0

## One-shot controls are normalized envelopes. They begin at 1 (or just above 0 for the
## travelling tool head), then `_process()` advances or decays them back to rest.
var output_pulse: float = 0.0
var tool_pulse: float = 0.0
var tool_angle: float = 0.0
var success_pulse: float = 0.0
var failure_pulse: float = 0.0
## Failure drives a one-way explosion: streaks launch at the core and leave the viewport.
var failure_progress: float = 0.0

## Tool events are often faster than their animation. Calls and results are queued so every arc
## reaches the edge and every result remains readable before the next tool takes ownership.
var pending_tool_calls: Array[Dictionary] = []
var pending_tool_results: Dictionary[String, AgentToolResult] = {}
var playing_tool: Dictionary = {}
var tool_play_seconds: float = 0.0
var tool_result_hold_seconds: float = 0.0

## A turn reverses the signed time direction. Interpolating the sign makes the fluid slow,
## stop, and reverse instead of snapping to the opposite direction.
var direction: float = 1.0
var target_direction: float = 1.0

## Completion is monotonic: aurora -> bright ring -> sparse dust -> transparent.
var completion: float = 0.0
var completing: bool = false
var ended_with_error: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	field = ColorRect.new()
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shader_material = ShaderMaterial.new()
	field.material = shader_material
	add_child(field)
	# Text remains a normal Label so tool names stay crisp and accessible at every resolution;
	# all atmospheric imagery is still rendered by the single full-screen shader draw call.
	tool_label = Label.new()
	tool_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tool_label.position = Vector2(-180.0, Margin.ma_12)
	tool_label.size = Vector2(360.0, ControlSize.md)
	tool_label.modulate.a = 0.0
	add_child(tool_label)
	visible = false
	# Load the GPU program without blocking the UI thread. Lifecycle events may arrive while the
	# resource is loading; their CPU state is retained and sent on the next `_process()` frame.
	var loaded_shader: Shader = await ResourceHelper.async_load(SHADER_PATH)
	if loaded_shader == null or not is_instance_valid(shader_material):
		return
	shader_material.shader = loaded_shader
	apply_theme()
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.NEURAL_AURORA


func fade_in_seconds() -> float:
	return 0.42


func fade_out_seconds() -> float:
	return 0.5


func reset_visual() -> void:
	elapsed = 0.0
	energy = 0.0
	target_energy = 0.0
	detail = 0.0
	target_detail = 0.0
	output_pulse = 0.0
	tool_pulse = 0.0
	tool_angle = 0.0
	success_pulse = 0.0
	failure_pulse = 0.0
	failure_progress = 0.0
	pending_tool_calls.clear()
	pending_tool_results.clear()
	playing_tool.clear()
	tool_play_seconds = 0.0
	tool_result_hold_seconds = 0.0
	direction = 1.0
	target_direction = 1.0
	completion = 0.0
	completing = false
	ended_with_error = false
	tool_label.modulate.a = 0.0
	pass


func on_agent_start(_session_id: int) -> void:
	# Wake the center first. Low detail lets the curtains unfold before reasoning begins.
	target_energy = 0.72
	target_detail = 0.18
	pass


func on_agent_end(error_message: String) -> void:
	# The asynchronous tail waits for queued tools before beginning the closing ritual.
	ended_with_error = StringUtils.is_not_blank(error_message)
	var fallback_result := AgentToolResult.error(error_message) if ended_with_error else AgentToolResult.ok("completed")
	if not playing_tool.is_empty():
		var playing_id := String(playing_tool["id"])
		if not pending_tool_results.has(playing_id):
			pending_tool_results[playing_id] = fallback_result
	for call: Dictionary in pending_tool_calls:
		var pending_id := String(call["id"])
		if not pending_tool_results.has(pending_id):
			pending_tool_results[pending_id] = fallback_result
	target_energy = 1.0
	if not is_inside_tree():
		return
	while not pending_tool_calls.is_empty() or not playing_tool.is_empty() or tool_result_hold_seconds > 0.0:
		await get_tree().process_frame
	if ended_with_error:
		failure_pulse = 1.0
		failure_progress = 0.0
	completing = true
	while completion < 1.0:
		await get_tree().process_frame
	pass


func on_turn_start() -> void:
	# Direction reversal is the visual punctuation between independent model turns.
	target_direction *= -1.0
	target_energy = 0.82
	pass


func on_turn_end() -> void:
	target_detail = minf(target_detail, 0.42)
	pass


func on_message_update(_chunk: String, stream_kind: String) -> void:
	# Reasoning energizes the persistent fine structure. Content uses a short warm wave so a
	# user can distinguish "thinking" from "speaking" without reading additional UI.
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		target_energy = 1.0
		target_detail = 1.0
	else:
		output_pulse = 1.0
		target_energy = maxf(target_energy, 0.78)
	pass


func on_message_complete(_usage: OpenAiUsage) -> void:
	target_detail = 0.38
	pass


func on_tool_execution_start(tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	pending_tool_calls.append({"id": tool_call_id, "name": tool_name})
	start_next_tool()
	pass


func on_tool_execution_end(tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	pending_tool_results[tool_call_id] = result
	pass


func on_theme_changed() -> void:
	apply_theme()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	# Exponential followers are frame-rate independent and preserve the same feel at 30/60/120 Hz.
	energy = lerpf(energy, target_energy, 1.0 - exp(-delta * 2.5))
	detail = lerpf(detail, target_detail, 1.0 - exp(-delta * 3.5))
	direction = lerpf(direction, target_direction, 1.0 - exp(-delta * 4.0))
	output_pulse = move_toward(output_pulse, 0.0, delta * 0.52)
	advance_tool_timeline(delta)
	# Keep the result at full strength for its readable hold, then let it trail into the next phase.
	if tool_result_hold_seconds <= 0.0:
		success_pulse = move_toward(success_pulse, 0.0, delta * 0.62)
		failure_pulse = move_toward(failure_pulse, 0.0, delta * 1.35)
	advance_failure(delta)
	if completing:
		completion = minf(completion + delta / COMPLETE_SECONDS, 1.0)
	set_shader_parameters()
	pass


func advance_failure(delta: float) -> void:
	if failure_pulse > 0.0:
		failure_progress = minf(failure_progress + delta / FAILURE_REVEAL_SECONDS, 1.0)
	pass


func advance_tool_timeline(delta: float) -> void:
	if tool_result_hold_seconds > 0.0:
		tool_result_hold_seconds = maxf(0.0, tool_result_hold_seconds - delta)
		if tool_result_hold_seconds <= 0.0:
			playing_tool.clear()
			tool_label.modulate.a = 0.0
			start_next_tool()
		return
	if playing_tool.is_empty():
		start_next_tool()
		return
	tool_play_seconds += delta
	tool_pulse = clampf(tool_play_seconds / MIN_TOOL_PLAY_SECONDS, 0.01, 1.0)
	var tool_call_id := String(playing_tool["id"])
	if tool_play_seconds < MIN_TOOL_PLAY_SECONDS or not pending_tool_results.has(tool_call_id):
		return
	complete_playing_tool(pending_tool_results[tool_call_id])
	pass


func start_next_tool() -> void:
	if not playing_tool.is_empty() or tool_result_hold_seconds > 0.0 or pending_tool_calls.is_empty():
		return
	playing_tool = pending_tool_calls.pop_front()
	tool_play_seconds = 0.0
	tool_pulse = 0.01
	tool_angle = angle_for_text(String(playing_tool["name"]))
	tool_label.text = VisualToolFormatter.upper_name(String(playing_tool["name"]))
	tool_label.add_theme_color_override("font_color", ThemeColor.accent_theme_color())
	tool_label.modulate.a = 1.0
	target_energy = 1.0
	pass


func complete_playing_tool(result: AgentToolResult) -> void:
	var tool_call_id := String(playing_tool["id"])
	pending_tool_results.erase(tool_call_id)
	tool_pulse = 0.0
	if result.is_error:
		failure_pulse = 1.0
		failure_progress = 0.0
		tool_label.add_theme_color_override("font_color", ColorBase.error)
	else:
		success_pulse = 1.0
		tool_label.add_theme_color_override("font_color", ColorBase.success)
	tool_result_hold_seconds = TOOL_RESULT_HOLD_SECONDS
	pass


func apply_theme() -> void:
	if shader_material == null:
		return
	shader_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	shader_material.set_shader_parameter("success_color", ColorBase.success)
	shader_material.set_shader_parameter("error_color", ColorBase.error)
	tool_label.add_theme_font_override("font", Fonts.semibold())
	tool_label.add_theme_font_size_override("font_size", Typography.label_large_size)
	tool_label.add_theme_color_override("font_color", ThemeColor.accent_theme_color())
	pass


func set_shader_parameters() -> void:
	# Keep this as the only CPU -> GPU synchronization point. Adding a new visual channel should
	# normally mean adding one controller envelope and one uniform, not another render node.
	shader_material.set_shader_parameter("energy", energy)
	shader_material.set_shader_parameter("detail", detail)
	shader_material.set_shader_parameter("output_pulse", output_pulse)
	shader_material.set_shader_parameter("tool_pulse", tool_pulse)
	shader_material.set_shader_parameter("tool_angle", tool_angle)
	shader_material.set_shader_parameter("success_pulse", success_pulse)
	shader_material.set_shader_parameter("failure_pulse", failure_pulse)
	shader_material.set_shader_parameter("failure_progress", failure_progress)
	shader_material.set_shader_parameter("direction", direction)
	shader_material.set_shader_parameter("completion", completion)
	shader_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	pass


static func angle_for_text(text: String) -> float:
	return lerpf(-PI * 0.82, PI * 0.82, float(abs(text.hash()) % 1000) / 999.0)
