class_name JarvisControl
extends VisualEffect

## Event-driven Jarvis orb overlay — shows while the active session agent runs.

const REVEAL_SCALE_MIN := 0.04
const REVEAL_DURATION_S := 0.82
const HIDE_DURATION_S := 0.68
const ORB_ALPHA := 0.88
const SENTENCE_INTERVAL_S := 0.2

var phase: OrbPhase.Phase = OrbPhase.Phase.IDLE

var viewport_container: SubViewportContainer
var sub_viewport: SubViewport
var jarvis_orb: JarvisOrb
var orb_tween: Tween
var active_session_id: int = 0
var chat_entry_index: int = 0
var entry_char_index: int = 0
var sentence_timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	build_scene()
	set_orb_visible(false, false)
	pass


func _process(delta: float) -> void:
	if active_session_id == 0 or jarvis_orb == null:
		return
	sentence_timer += delta
	if sentence_timer < SENTENCE_INTERVAL_S:
		return
	sentence_timer = 0.0
	offer_next_sentence()
	pass


func build_scene() -> void:
	viewport_container = SubViewportContainer.new()
	viewport_container.name = "Viewport"
	viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport_container.offset_right = 0.0
	viewport_container.offset_bottom = 0.0
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)

	sub_viewport = SubViewport.new()
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.own_world_3d = true
	sub_viewport.msaa_3d = Viewport.MSAA_4X
	viewport_container.add_child(sub_viewport)
	viewport_container.stretch_shrink = 1

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.glow_enabled = true
	environment.glow_intensity = 1.15
	environment.glow_strength = 0.85
	environment.glow_bloom = 0.28
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.05
	env.environment = environment
	sub_viewport.add_child(env)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.05, OrbVisualScale.CAMERA_DISTANCE)
	camera.fov = OrbVisualScale.CAMERA_FOV
	sub_viewport.add_child(camera)
	camera.look_at(Vector3.ZERO)

	jarvis_orb = JarvisOrb.new()
	sub_viewport.add_child(jarvis_orb)

	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.JARVIS


func set_visual_visible(show: bool, animated: bool) -> void:
	set_orb_visible(show, animated)
	pass


func reset_visual() -> void:
	if jarvis_orb != null:
		jarvis_orb.reset_growth()
	pass


func on_agent_start(session_id: int) -> void:
	transition_to(OrbPhase.Phase.AWAKE)
	active_session_id = session_id
	chat_entry_index = find_latest_user_entry(session_id)
	entry_char_index = 0
	sentence_timer = 0.0
	pass


func find_latest_user_entry(session_id: int) -> int:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return 0
	for i in range(session.chat_entries.size() - 1, -1, -1):
		var entry: ChatEntry = session.chat_entries[i]
		if entry.kind == ChatEntry.KIND_USER:
			return i
	return session.chat_entries.size()


## Returns one complete sentence at [param start_index]. An unfinished tail is never returned.
static func take_sentence(text: String, start_index: int) -> Dictionary:
	var start := clampi(start_index, 0, text.length())
	while start < text.length() and text.substr(start, 1).strip_edges().is_empty():
		start += 1
	for i in range(start, text.length()):
		if not StringUtils.is_sentence_end(text.substr(start, i - start + 1)):
			continue
		return {"text": text.substr(start, i - start + 1).strip_edges(), "next_index": i + 1}
	return {"text": "", "next_index": start}


func offer_next_sentence() -> void:
	var session := AgentSessionStore.load_session(active_session_id)
	if session == null:
		return
	while chat_entry_index < session.chat_entries.size():
		var entry: ChatEntry = session.chat_entries[chat_entry_index]
		var sentence := take_sentence(entry.body, entry_char_index)
		var text: String = sentence.text
		entry_char_index = sentence.next_index
		if not text.is_empty():
			jarvis_orb.add_step_text(text)
			return
		if chat_entry_index == session.chat_entries.size() - 1:
			return
		chat_entry_index += 1
		entry_char_index = 0
	pass


func on_agent_end(error_message: String) -> float:
	var is_stop: bool = error_message == "Stop." or error_message == "Stop..."
	var end_phase: OrbPhase.Phase = OrbPhase.Phase.SUCCESS
	if StringUtils.is_not_blank(error_message) and not is_stop:
		end_phase = OrbPhase.Phase.ERROR
	transition_to(end_phase)
	return 1.1 if end_phase == OrbPhase.Phase.ERROR else 0.75


func on_turn_start() -> void:
	jarvis_orb.clear_stream_queue()
	transition_to(OrbPhase.Phase.AWAKE)
	pass


func on_turn_end() -> void:
	transition_to(OrbPhase.Phase.TURN_COOLDOWN)
	pass


func on_message_update(_chunk: String, stream_kind: String) -> void:
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		transition_to(OrbPhase.Phase.REASONING)
	elif phase != OrbPhase.Phase.TOOL_EXEC:
		transition_to(OrbPhase.Phase.GENERATING)
	pass


func on_message_complete(_usage: OpenAiUsage) -> void:
	jarvis_orb.flush_growth()
	jarvis_orb.neuron_net.pulse_random(1.0)
	pass


func on_tool_execution_start(_tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	transition_to(OrbPhase.Phase.TOOL_EXEC)
	pass


func on_tool_execution_end(_tool_call_id: String, _tool_name: String, _agent_tool_result: AgentToolResult) -> void:
	if phase == OrbPhase.Phase.TOOL_EXEC:
		transition_to(OrbPhase.Phase.AWAKE)
	pass


func on_chat_entry_add(_entry: ChatEntry) -> void:
	pass


func transition_to(new_phase: OrbPhase.Phase) -> void:
	phase = new_phase
	if jarvis_orb != null:
		jarvis_orb.set_phase(new_phase)
	pass


func stop_orb_tween() -> void:
	if orb_tween != null and orb_tween.is_valid():
		orb_tween.kill()
	pass


func set_orb_visible(show: bool, animated: bool) -> void:
	if not show:
		if not visible:
			return
		stop_orb_tween()
		if not animated:
			finalize_orb_hidden()
			return
		ensure_center_pivot()
		orb_tween = build_orb_tween(false)
		orb_tween.chain().tween_callback(finalize_orb_hidden)
		return

	stop_orb_tween()
	visible = true
	ensure_center_pivot()
	if not animated:
		scale = Vector2.ONE
		modulate.a = ORB_ALPHA
		return

	scale = Vector2(REVEAL_SCALE_MIN, REVEAL_SCALE_MIN)
	modulate.a = 0.0
	orb_tween = build_orb_tween(true)
	pass


func build_orb_tween(revealing: bool) -> Tween:
	var duration := REVEAL_DURATION_S if revealing else HIDE_DURATION_S
	var ease_type := Tween.EASE_OUT if revealing else Tween.EASE_IN
	var end_scale := Vector2.ONE if revealing else Vector2(REVEAL_SCALE_MIN, REVEAL_SCALE_MIN)
	var end_alpha := ORB_ALPHA if revealing else 0.0
	var alpha_duration := duration * 0.92 if revealing else duration
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", end_scale, duration).set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	tween.tween_property(self, "modulate:a", end_alpha, alpha_duration).set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	return tween


func finalize_orb_hidden() -> void:
	visible = false
	modulate.a = 0.0
	scale = Vector2.ONE
	phase = OrbPhase.Phase.IDLE
	active_session_id = 0
	if jarvis_orb != null:
		jarvis_orb.clear_stream_queue()
		jarvis_orb.reset_growth()
		jarvis_orb.set_phase(OrbPhase.Phase.IDLE)
	pass


func ensure_center_pivot() -> void:
	pivot_offset = size * 0.5
	pass
