class_name NeuralAurora
extends VisualEffect

## Full-screen shader-driven aurora. CPU state only follows agent lifecycle events.

const SHADER := preload("res://agent/ui/visuals/neural_aurora/NeuralAurora.gdshader")
const COMPLETE_SECONDS := 1.35

var field: ColorRect
var tool_label: Label
var shader_material: ShaderMaterial
var elapsed: float = 0.0
var energy: float = 0.0
var target_energy: float = 0.0
var detail: float = 0.0
var target_detail: float = 0.0
var output_pulse: float = 0.0
var tool_pulse: float = 0.0
var success_pulse: float = 0.0
var failure_pulse: float = 0.0
var direction: float = 1.0
var target_direction: float = 1.0
var completion: float = 0.0
var completing: bool = false
var fade_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	field = ColorRect.new()
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shader_material = ShaderMaterial.new()
	shader_material.shader = SHADER
	field.material = shader_material
	add_child(field)
	tool_label = Label.new()
	tool_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tool_label.position = Vector2(-180.0, Margin.ma_12)
	tool_label.size = Vector2(360.0, ControlSize.md)
	tool_label.modulate.a = 0.0
	add_child(tool_label)
	apply_theme()
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.NEURAL_AURORA


func set_visual_visible(show: bool, animated: bool) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	if show:
		visible = true
		modulate.a = 0.0 if animated else 1.0
		if animated:
			fade_tween = create_tween()
			fade_tween.tween_property(self, "modulate:a", 1.0, 0.42)
		return
	if not animated:
		visible = false
		modulate.a = 1.0
		return
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	fade_tween.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
	)
	pass


func reset_visual() -> void:
	elapsed = 0.0
	energy = 0.0
	target_energy = 0.0
	detail = 0.0
	target_detail = 0.0
	output_pulse = 0.0
	tool_pulse = 0.0
	success_pulse = 0.0
	failure_pulse = 0.0
	direction = 1.0
	target_direction = 1.0
	completion = 0.0
	completing = false
	tool_label.modulate.a = 0.0
	pass


func on_agent_start(_session_id: int) -> void:
	target_energy = 0.72
	target_detail = 0.18
	pass


func on_agent_end(error_message: String) -> float:
	if StringUtils.is_not_blank(error_message):
		failure_pulse = 1.0
	completing = true
	target_energy = 1.0
	return COMPLETE_SECONDS


func on_turn_start() -> void:
	target_direction *= -1.0
	target_energy = 0.82
	pass


func on_turn_end() -> void:
	target_detail = minf(target_detail, 0.42)
	pass


func on_message_update(_chunk: String, stream_kind: String) -> void:
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


func on_tool_execution_start(_tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	tool_pulse = 0.01
	shader_material.set_shader_parameter("tool_angle", angle_for_text(tool_name))
	tool_label.text = public_tool_name(tool_name)
	tool_label.modulate.a = 1.0
	target_energy = 1.0
	pass


func on_tool_execution_end(_tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	tool_pulse = 0.0
	if result.is_error:
		failure_pulse = 1.0
	else:
		success_pulse = 1.0
	tool_label.modulate.a = 0.0
	pass


func on_theme_changed() -> void:
	apply_theme()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	energy = lerpf(energy, target_energy, 1.0 - exp(-delta * 2.5))
	detail = lerpf(detail, target_detail, 1.0 - exp(-delta * 3.5))
	direction = lerpf(direction, target_direction, 1.0 - exp(-delta * 4.0))
	output_pulse = move_toward(output_pulse, 0.0, delta * 0.52)
	if tool_pulse > 0.0:
		tool_pulse = minf(tool_pulse + delta * 0.72, 1.0)
	success_pulse = move_toward(success_pulse, 0.0, delta * 0.62)
	failure_pulse = move_toward(failure_pulse, 0.0, delta * 2.4)
	if completing:
		completion = minf(completion + delta / COMPLETE_SECONDS, 1.0)
	set_shader_parameters()
	pass


func apply_theme() -> void:
	if shader_material == null:
		return
	shader_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	shader_material.set_shader_parameter("success_color", ColorBase.success)
	shader_material.set_shader_parameter("error_color", ColorBase.error)
	tool_label.add_theme_font_override("font", Fonts.semibold())
	tool_label.add_theme_font_size_override("font_size", Typography.label_large_size)
	tool_label.add_theme_color_override("font_color", ColorBase.primary_text)
	pass


func set_shader_parameters() -> void:
	shader_material.set_shader_parameter("energy", energy)
	shader_material.set_shader_parameter("detail", detail)
	shader_material.set_shader_parameter("output_pulse", output_pulse)
	shader_material.set_shader_parameter("tool_pulse", tool_pulse)
	shader_material.set_shader_parameter("success_pulse", success_pulse)
	shader_material.set_shader_parameter("failure_pulse", failure_pulse)
	shader_material.set_shader_parameter("direction", direction)
	shader_material.set_shader_parameter("completion", completion)
	shader_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	pass


static func angle_for_text(text: String) -> float:
	return lerpf(-PI * 0.82, PI * 0.82, float(abs(text.hash()) % 1000) / 999.0)


static func public_tool_name(tool_name: String) -> String:
	var readable := tool_name.replace("_", " ").replace("-", " ").strip_edges()
	return readable.to_upper() if not readable.is_empty() else "TOOL"
