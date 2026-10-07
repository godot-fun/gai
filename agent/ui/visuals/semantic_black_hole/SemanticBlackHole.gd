class_name SemanticBlackHole
extends VisualEffect

## Converts agent lifecycle events into a gravitational information field.
##
## The controller owns only smooth scalar envelopes, tool direction, and readable text. The
## full-screen shader renders the horizon, accretion disk, semantic dust, lensing, jets,
## wormhole, failure disturbance, and final evaporation. See DESIGN.md for the visual contract.

const SHADER_PATH := "res://agent/ui/visuals/semantic_black_hole/SemanticBlackHole.gdshader"
const COMPLETE_SECONDS := 2.3
const SUCCESS_RETURN_SECONDS := 1.15
const SUCCESS_ABSORB_SECONDS := 0.22
const COMPLETE_LABEL_SECONDS := 0.55
const FAILED_LABEL_SECONDS := 1.0

enum ToolBadgeState { CONNECTING, RETURNING, COMPLETE, FAILED }

var field: ColorRect
var tool_badge: PanelContainer
var tool_name_label: Label
var tool_status_label: Label
var shader_material: ShaderMaterial

## Persistent values use exponential followers so event boundaries never produce hard jumps.
var gravity: float = 0.0
var target_gravity: float = 0.0
var disk_energy: float = 0.0
var target_disk_energy: float = 0.0
var reasoning_density: float = 0.0
var target_reasoning_density: float = 0.0

## Event envelopes are normalized. Tool openness holds while a tool runs; all others decay.
var jet_energy: float = 0.0
var wormhole_open: float = 0.0
var target_wormhole_open: float = 0.0
var wormhole_angle: float = -0.6
## Success uses separate travel and brightness values. Coupling them would fade the packet as it
## approaches the horizon, making it appear to vanish before reaching the black hole.
var success_return: float = 0.0
var success_return_progress: float = 0.0
var success_absorb_time: float = 0.0
var failure_shock: float = 0.0
var context_density: float = 0.0
var completion: float = 0.0
var completing: bool = false
var ended_with_error: bool = false
var tool_badge_state: ToolBadgeState = ToolBadgeState.CONNECTING
var tool_badge_alpha: float = 0.0
var target_tool_badge_alpha: float = 0.0
var tool_badge_hold_seconds: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	field = ColorRect.new()
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shader_material = ShaderMaterial.new()
	field.material = shader_material
	add_child(field)
	tool_badge = PanelContainer.new()
	tool_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool_badge.custom_minimum_size = Vector2(220.0, 0.0)
	tool_badge.modulate.a = 0.0
	var labels := VBoxContainer.new()
	labels.add_theme_constant_override("separation", Margin.ma_1)
	tool_name_label = Label.new()
	tool_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_status_label = Label.new()
	tool_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.add_child(tool_name_label)
	labels.add_child(tool_status_label)
	tool_badge.add_child(labels)
	add_child(tool_badge)
	visible = false
	# Loading asynchronously prevents a first-use hitch. State can safely accumulate before the
	# shader arrives because every current value is uploaded from one place on each visible frame.
	var loaded_shader: Shader = await ResourceHelper.async_load(SHADER_PATH)
	if loaded_shader == null or not is_instance_valid(shader_material):
		return
	shader_material.shader = loaded_shader
	apply_theme()
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.SEMANTIC_BLACK_HOLE


func fade_in_seconds() -> float:
	return 0.45


func fade_out_seconds() -> float:
	return 0.45


func reset_visual() -> void:
	gravity = 0.0
	target_gravity = 0.0
	disk_energy = 0.0
	target_disk_energy = 0.0
	reasoning_density = 0.0
	target_reasoning_density = 0.0
	jet_energy = 0.0
	wormhole_open = 0.0
	target_wormhole_open = 0.0
	success_return = 0.0
	success_return_progress = 0.0
	success_absorb_time = 0.0
	failure_shock = 0.0
	context_density = 0.0
	completion = 0.0
	completing = false
	ended_with_error = false
	tool_badge_state = ToolBadgeState.CONNECTING
	tool_badge_alpha = 0.0
	target_tool_badge_alpha = 0.0
	tool_badge_hold_seconds = 0.0
	if tool_badge != null:
		tool_badge.modulate.a = 0.0
	pass


func on_agent_start(_session_id: int) -> void:
	# Establish the gravity well before making the disk energetic.
	target_gravity = 0.78
	target_disk_energy = 0.52
	context_density = 0.35
	pass


func on_agent_end(error_message: String) -> void:
	ended_with_error = StringUtils.is_not_blank(error_message)
	if ended_with_error:
		failure_shock = 1.0
	completing = true
	target_wormhole_open = 0.0
	target_tool_badge_alpha = 0.0
	if is_inside_tree():
		await get_tree().create_timer(COMPLETE_SECONDS).timeout
	pass


func on_turn_start() -> void:
	# Deepen the well each turn; the whirlpool always spins the same way and pulls inward.
	target_gravity = 0.9
	target_disk_energy = 0.72
	pass


func on_turn_end() -> void:
	target_reasoning_density = 0.24
	pass


func on_chat_entry_add(entry: ChatEntry) -> void:
	# Text length affects density sublinearly so very large contexts cannot saturate the screen.
	context_density = clampf(context_density + sqrt(float(entry.body.length())) / 80.0, 0.0, 1.0)
	pass


func on_message_update(_chunk: String, stream_kind: String) -> void:
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		target_reasoning_density = 1.0
		target_disk_energy = 1.0
		target_gravity = 1.0
	else:
		# Repeated chunks sustain the jet; the envelope decays naturally after streaming stops.
		jet_energy = 1.0
		target_disk_energy = maxf(target_disk_energy, 0.78)
	pass


func on_message_complete(_usage: OpenAiUsage) -> void:
	target_reasoning_density = 0.2
	pass


func on_tool_execution_start(_tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	wormhole_angle = angle_for_tool(tool_name)
	target_wormhole_open = 1.0
	tool_name_label.text = VisualToolFormatter.upper_name(tool_name)
	set_tool_badge_state(ToolBadgeState.CONNECTING)
	target_tool_badge_alpha = 1.0
	tool_badge_hold_seconds = 0.0
	target_disk_energy = 1.0
	pass


func on_tool_execution_end(_tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	target_wormhole_open = 0.0
	if result.is_error:
		failure_shock = 1.0
		set_tool_badge_state(ToolBadgeState.FAILED)
		tool_badge_hold_seconds = FAILED_LABEL_SECONDS
	else:
		success_return = 1.0
		success_return_progress = 0.0
		success_absorb_time = 0.0
		set_tool_badge_state(ToolBadgeState.RETURNING)
	pass


func on_theme_changed() -> void:
	apply_theme()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	gravity = follow(gravity, target_gravity, delta, 2.4)
	disk_energy = follow(disk_energy, target_disk_energy, delta, 3.0)
	reasoning_density = follow(reasoning_density, target_reasoning_density, delta, 3.8)
	wormhole_open = follow(wormhole_open, target_wormhole_open, delta, 7.0)
	jet_energy = move_toward(jet_energy, 0.0, delta * 0.48)
	advance_success_return(delta)
	failure_shock = move_toward(failure_shock, 0.0, delta * 1.45)
	context_density = move_toward(context_density, 0.28, delta * 0.04)
	advance_tool_badge(delta)
	if completing:
		completion = minf(completion + delta / COMPLETE_SECONDS, 1.0)
	layout_tool_label()
	set_shader_parameters()
	pass


func advance_tool_badge(delta: float) -> void:
	if tool_badge_hold_seconds > 0.0:
		tool_badge_hold_seconds = maxf(0.0, tool_badge_hold_seconds - delta)
		if tool_badge_hold_seconds <= 0.0 and tool_badge_state in [ToolBadgeState.COMPLETE, ToolBadgeState.FAILED]:
			target_tool_badge_alpha = 0.0
	var fade_speed := 9.0 if target_tool_badge_alpha > tool_badge_alpha else 6.0
	tool_badge_alpha = follow(tool_badge_alpha, target_tool_badge_alpha, delta, fade_speed)
	tool_badge.modulate.a = tool_badge_alpha
	pass


func advance_success_return(delta: float) -> void:
	if success_return <= 0.0:
		return
	if success_return_progress < 1.0:
		success_return_progress = minf(success_return_progress + delta / SUCCESS_RETURN_SECONDS, 1.0)
		return
	# Hold a bright packet on the photon ring briefly so arrival reads as absorption, then fade.
	success_absorb_time += delta
	if success_absorb_time >= SUCCESS_ABSORB_SECONDS:
		success_return = move_toward(success_return, 0.0, delta * 6.0)
		if success_return <= 0.0 and tool_badge_state == ToolBadgeState.RETURNING:
			set_tool_badge_state(ToolBadgeState.COMPLETE)
			tool_badge_hold_seconds = COMPLETE_LABEL_SECONDS
	pass


func apply_theme() -> void:
	if shader_material == null:
		return
	shader_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	shader_material.set_shader_parameter("success_color", ColorBase.success)
	shader_material.set_shader_parameter("error_color", ColorBase.error)
	tool_name_label.add_theme_font_override("font", Fonts.semibold())
	tool_name_label.add_theme_font_size_override("font_size", Typography.label_large_size)
	tool_status_label.add_theme_font_override("font", Fonts.medium())
	tool_status_label.add_theme_font_size_override("font_size", Typography.label_small_size)
	apply_tool_badge_style()
	pass


func set_tool_badge_state(state: ToolBadgeState) -> void:
	tool_badge_state = state
	match state:
		ToolBadgeState.CONNECTING:
			tool_status_label.text = I18n.t("agent.visuals.connecting")
		ToolBadgeState.RETURNING:
			tool_status_label.text = I18n.t("agent.visuals.returning")
		ToolBadgeState.COMPLETE:
			tool_status_label.text = I18n.t("agent.visuals.complete")
		ToolBadgeState.FAILED:
			tool_status_label.text = I18n.t("agent.visuals.failed")
	apply_tool_badge_style()
	pass


func apply_tool_badge_style() -> void:
	if tool_badge == null:
		return
	var state_color := tool_badge_color()
	var panel_style := StyleBoxHelper.create_style_box_flat(Color(ColorBase.deep_surface, 0.82), ControlSize.radius_md, Margin.ma_3, Margin.ma_2, Color(state_color, 0.52), ControlSize.border_xs)
	tool_badge.add_theme_stylebox_override("panel", panel_style)
	tool_name_label.add_theme_color_override("font_color", state_color)
	tool_status_label.add_theme_color_override("font_color", Color(state_color, 0.78))
	pass


func tool_badge_color() -> Color:
	match tool_badge_state:
		ToolBadgeState.RETURNING, ToolBadgeState.COMPLETE:
			return ColorBase.success
		ToolBadgeState.FAILED:
			return ColorBase.error
	return ThemeColor.accent_theme_color()


func layout_tool_label() -> void:
	# Label position follows the wormhole but remains clamped inside the viewport.
	var radius := minf(size.x, size.y) * 0.36
	var center := size * 0.5
	var anchor := center + Vector2.from_angle(wormhole_angle) * radius
	tool_badge.position = Vector2(clampf(anchor.x - tool_badge.size.x * 0.5, Margin.ma_4, size.x - tool_badge.size.x - Margin.ma_4), clampf(anchor.y + Margin.ma_6, Margin.ma_4, size.y - tool_badge.size.y - Margin.ma_4))
	pass


func set_shader_parameters() -> void:
	shader_material.set_shader_parameter("gravity", gravity)
	shader_material.set_shader_parameter("disk_energy", disk_energy)
	shader_material.set_shader_parameter("reasoning_density", reasoning_density)
	shader_material.set_shader_parameter("jet_energy", jet_energy)
	shader_material.set_shader_parameter("wormhole_open", wormhole_open)
	shader_material.set_shader_parameter("wormhole_angle", wormhole_angle)
	shader_material.set_shader_parameter("success_return", success_return)
	shader_material.set_shader_parameter("success_return_progress", success_return_progress)
	shader_material.set_shader_parameter("failure_shock", failure_shock)
	shader_material.set_shader_parameter("context_density", context_density)
	shader_material.set_shader_parameter("completion", completion)
	shader_material.set_shader_parameter("error_completion", 1.0 if ended_with_error else 0.0)
	shader_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	pass


static func follow(current: float, target: float, delta: float, speed: float) -> float:
	return lerpf(current, target, 1.0 - exp(-delta * speed))


static func angle_for_tool(tool_name: String) -> float:
	return lerpf(-PI * 0.9, PI * 0.9, float(abs(tool_name.hash()) % 1000) / 999.0)
