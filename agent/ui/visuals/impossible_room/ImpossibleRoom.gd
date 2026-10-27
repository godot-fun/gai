class_name ImpossibleRoom
extends VisualEffect

## Makes the application surface behave like an impossible moving room. The toolbar remains
## visually anchored while the content below it slides as a perspective plane, then settles with
## spring inertia. Transcript sentences and tool lifecycle events provide the physical impulses.

const ROOM_SHADER: Shader = preload("res://agent/ui/visuals/impossible_room/ImpossibleRoom.gdshader")
const SPRING_STRENGTH := 74.0
const SPRING_DAMPING := 13.5
const MAX_DISPLACEMENT_PX := 148.0
const MAX_VELOCITY_PX := 1180.0
const IDLE_EPSILON := 0.025

var screen_rect: ColorRect
var room_material: ShaderMaterial
var displacement_px: float = 0.0
var velocity_px: float = 0.0
var impact: float = 0.0
var event_direction: float = 1.0


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "MovingRoomSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room_material = ShaderMaterial.new()
	room_material.shader = ROOM_SHADER
	room_material.set_shader_parameter("toolbar_height_px", float(AgentLayout.TOOLBAR_HEIGHT))
	room_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	screen_rect.material = room_material
	add_child(screen_rect)
	gdf.events.theme_color_changed.connect(update_accent_color)
	pass


func fade_in_seconds() -> float:
	return 0.16


func fade_out_seconds() -> float:
	return 0.22


func on_agent_start(_session_id: int) -> void:
	reset_motion()
	kick(510.0)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	if StringUtils.is_not_blank(error_message):
		kick(920.0, -event_direction)
	else:
		kick(650.0)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 1150 and (absf(displacement_px) > 0.8 or absf(velocity_px) > 8.0):
		await get_tree().process_frame
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty() or stream_kind != OpenAiClient.STREAM_KIND_REASONING:
		return
	# Reasoning creates restrained pressure instead of one kick per streamed token.
	velocity_px = clampf(velocity_px + event_direction * minf(float(chunk.length()) * 1.8, 24.0), -MAX_VELOCITY_PX, MAX_VELOCITY_PX)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	kick(860.0)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	# A result pushes the room back across its previous path. Failures deliberately overshoot.
	kick(1040.0 if result.is_error else 720.0, -event_direction)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	if not RuntimeManager.runtimes.is_empty():
		var sentence := ChatEntryCursor.take_next_sentence()
		if not sentence.is_empty():
			kick(impulse_for_sentence(sentence.text))
	step_motion(delta)
	apply_shader_state()
	pass


func step_motion(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	var acceleration := -displacement_px * SPRING_STRENGTH - velocity_px * SPRING_DAMPING
	velocity_px = clampf(velocity_px + acceleration * safe_delta, -MAX_VELOCITY_PX, MAX_VELOCITY_PX)
	displacement_px = clampf(displacement_px + velocity_px * safe_delta, -MAX_DISPLACEMENT_PX, MAX_DISPLACEMENT_PX)
	impact = move_toward(impact, 0.0, safe_delta * 2.7)
	if absf(displacement_px) < IDLE_EPSILON and absf(velocity_px) < IDLE_EPSILON:
		displacement_px = 0.0
		velocity_px = 0.0
	pass


func kick(impulse: float, direction: float = 0.0) -> void:
	if direction == 0.0:
		event_direction = -event_direction
	else:
		event_direction = signf(direction)
	velocity_px = clampf(velocity_px + event_direction * impulse, -MAX_VELOCITY_PX, MAX_VELOCITY_PX)
	impact = clampf(impact + impulse / MAX_VELOCITY_PX, 0.0, 1.0)
	pass


func apply_shader_state() -> void:
	if room_material == null:
		return
	room_material.set_shader_parameter("displacement_px", displacement_px)
	room_material.set_shader_parameter("velocity", velocity_px / MAX_VELOCITY_PX)
	room_material.set_shader_parameter("impact", impact)
	pass


func update_accent_color() -> void:
	if room_material != null:
		room_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	pass


func reset_motion() -> void:
	displacement_px = 0.0
	velocity_px = 0.0
	impact = 0.0
	event_direction = 1.0
	apply_shader_state()
	pass


static func impulse_for_sentence(text: String) -> float:
	return clampf(300.0 + sqrt(float(text.strip_edges().length())) * 54.0, 360.0, 780.0)
