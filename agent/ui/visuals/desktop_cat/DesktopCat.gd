class_name DesktopCat
extends VisualEffect

## An event-driven desktop companion drawn without external assets.

const TOOL_REACH_MIN_SECONDS := 0.55
const REACTION_SECONDS := 0.9
const END_HOLD_SECONDS := 2.0
const REACH_PARTICLE_DELAY_PROGRESS := 0.5
const STAGE_SIZE := Vector2(330.0, 245.0)
const FUR_ORANGE := Color(0.91, 0.55, 0.25)
const FUR_LIGHT := Color(1.0, 0.83, 0.58)
const FUR_SHADOW := Color(0.68, 0.34, 0.16)
const LINE_BROWN := Color(0.24, 0.16, 0.14)
const EAR_PINK := Color(0.95, 0.57, 0.58)

enum CatState { IDLE, THINKING, TOOL_START, TOOL_WAITING, TOOL_SUCCESS, TOOL_FAILED, SUCCESS, FAILED, CANCELLED }

var state: CatState = CatState.IDLE
var elapsed: float = 0.0
var state_seconds: float = 0.0
var reasoning_active: bool = false
var active_tools: Dictionary[String, Dictionary] = {}
var animation_queue: Array[Dictionary] = []
var animation_event_active: bool = false
var active_tool_name: String = ""
var card_text: String = ""
var sit_blend: float = 0.0
var paw_blend: float = 0.0
var ear_blend: float = 0.0
var state_blend: float = 1.0
var tail_offset: float = 0.0
var tail_velocity: float = 0.0
var tail_tool_blend: float = 0.0
var tail_swing_phase: float = 0.0
var tail_bob_phase: float = 0.0
var tail_posture: float = 0.0
var whisker_phase: float = 0.0
var gaze: Vector2 = Vector2.ZERO
var body_lean: float = 0.0
var impact_pulse: float = 0.0
var gesture_blend: float = 0.0
var resting_paw_activity: float = 0.0
var mouth_blend: float = 0.35


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.DESKTOP_CAT


func fade_in_seconds() -> float:
	return 0.25


func fade_out_seconds() -> float:
	return 0.25


func reset_visual() -> void:
	active_tools.clear()
	animation_queue.clear()
	animation_event_active = false
	active_tool_name = ""
	reasoning_active = false
	card_text = ""
	sit_blend = 0.0
	paw_blend = 0.0
	ear_blend = 0.0
	state_blend = 1.0
	gaze = Vector2.ZERO
	body_lean = 0.0
	impact_pulse = 0.0
	gesture_blend = 0.0
	resting_paw_activity = 0.0
	mouth_blend = 0.35
	tail_tool_blend = 0.0
	tail_offset = 0.0
	tail_velocity = 0.0
	tail_swing_phase = 0.0
	tail_bob_phase = 0.0
	tail_posture = 0.0
	whisker_phase = 0.0
	elapsed = 0.0
	state_seconds = 0.0
	state = CatState.IDLE
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	set_state(CatState.THINKING)
	pass


func on_agent_end(error_message: String) -> float:
	# The final result takes priority over cosmetic events that have not finished playing.
	active_tools.clear()
	animation_queue.clear()
	animation_event_active = false
	reasoning_active = false
	if StringUtils.is_blank(error_message):
		card_text = "DONE"
		set_state(CatState.SUCCESS)
	elif error_message.strip_edges().to_lower().begins_with("stop"):
		card_text = "STOPPED"
		set_state(CatState.CANCELLED)
	else:
		card_text = compact_label(error_message, 22)
		set_state(CatState.FAILED)
	return END_HOLD_SECONDS


func on_turn_start() -> void:
	reasoning_active = true
	if active_tools.is_empty() and not animation_event_active and animation_queue.is_empty():
		set_state(CatState.THINKING)
	pass


func on_turn_end() -> void:
	reasoning_active = false
	if active_tools.is_empty() and not animation_event_active and animation_queue.is_empty() and state not in [CatState.SUCCESS, CatState.FAILED, CatState.CANCELLED]:
		set_state(CatState.IDLE)
	pass


func on_message_update(_chunk: String, stream_kind: String) -> void:
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING and active_tools.is_empty() and not animation_event_active and animation_queue.is_empty():
		reasoning_active = true
		set_state(CatState.THINKING)
	pass


func on_tool_execution_start(tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	active_tools[tool_call_id] = {"name": tool_name, "seconds": 0.0}
	enqueue_tool_animation(CatState.TOOL_START, tool_name)
	pass


func on_tool_execution_end(tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	active_tools.erase(tool_call_id)
	enqueue_tool_animation(CatState.TOOL_FAILED if result.is_error else CatState.TOOL_SUCCESS, tool_name)
	pass


func on_theme_changed() -> void:
	queue_redraw()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	state_seconds += delta
	var sit_target := 0.0 if state == CatState.IDLE else 1.0
	var paw_target := 1.0 if state in [CatState.TOOL_START, CatState.TOOL_WAITING] else 0.0
	var ear_target := 1.0 if state == CatState.THINKING else 0.0
	var lean_target := -5.0 if state in [CatState.TOOL_START, CatState.TOOL_WAITING] else 0.0
	var gesture_target := 1.0 if should_raise_paw() else 0.0
	var resting_paw_target := 1.0 if state in [CatState.TOOL_SUCCESS, CatState.SUCCESS] else (0.28 if state == CatState.THINKING else 0.0)
	var mouth_target := 1.0 if state in [CatState.TOOL_SUCCESS, CatState.SUCCESS] else (0.0 if state in [CatState.TOOL_FAILED, CatState.FAILED] else 0.35)
	sit_blend = smooth_value(sit_blend, sit_target, 7.5, delta)
	paw_blend = smooth_value(paw_blend, paw_target, 10.0, delta)
	ear_blend = smooth_value(ear_blend, ear_target, 8.0, delta)
	body_lean = smooth_value(body_lean, lean_target, 8.0, delta)
	gesture_blend = smooth_value(gesture_blend, gesture_target, 6.5, delta)
	resting_paw_activity = smooth_value(resting_paw_activity, resting_paw_target, 5.5, delta)
	mouth_blend = smooth_value(mouth_blend, mouth_target, 3.2, delta)
	var tail_tool_target := 1.0 if state in [CatState.TOOL_START, CatState.TOOL_WAITING] else 0.0
	# A slow independent blend makes tool work more energetic without changing an animation's phase.
	tail_tool_blend = smooth_value(tail_tool_blend, tail_tool_target, 1.8, delta)
	tail_swing_phase = fmod(tail_swing_phase + delta * lerpf(0.72, 1.18, tail_tool_blend), TAU)
	whisker_phase = fmod(whisker_phase + delta * lerpf(1.0, 1.45, tail_tool_blend), TAU * 10.0)
	var tail_posture_target := 10.0 if state in [CatState.TOOL_FAILED, CatState.FAILED] else (-7.0 if state in [CatState.TOOL_SUCCESS, CatState.SUCCESS] else 0.0)
	tail_posture = smooth_value(tail_posture, tail_posture_target, 5.0, delta)
	state_blend = smooth_value(state_blend, 1.0, 8.0, delta)
	gaze = gaze.lerp(gaze_target(), 1.0 - exp(-7.0 * delta))
	impact_pulse = move_toward(impact_pulse, 0.0, delta * 4.5)
	advance_tail(delta)
	for tool_call_id: String in active_tools.keys():
		var tool: Dictionary = active_tools[tool_call_id]
		tool["seconds"] = float(tool["seconds"]) + delta
		active_tools[tool_call_id] = tool
	advance_animation_queue()
	queue_redraw()
	pass


func enqueue_tool_animation(next_state: CatState, tool_name: String) -> void:
	animation_queue.append({"state": next_state, "tool_name": tool_name})
	if not animation_event_active:
		play_next_animation_event()
	pass


func play_next_animation_event() -> void:
	if animation_queue.is_empty():
		animation_event_active = false
		return
	var event: Dictionary = animation_queue.pop_front()
	animation_event_active = true
	active_tool_name = String(event["tool_name"])
	var next_state: CatState = event["state"]
	if next_state in [CatState.TOOL_SUCCESS, CatState.TOOL_FAILED]:
		card_text = VisualToolFormatter.title_name(active_tool_name)
	set_state(next_state)
	pass


func advance_animation_queue() -> void:
	if not animation_event_active:
		return
	var event_duration := TOOL_REACH_MIN_SECONDS if state == CatState.TOOL_START else REACTION_SECONDS
	if state_seconds < event_duration:
		return
	animation_event_active = false
	if not animation_queue.is_empty():
		play_next_animation_event()
	elif not active_tools.is_empty():
		active_tool_name = first_active_tool_name()
		set_state(CatState.TOOL_WAITING)
	else:
		set_state(CatState.THINKING if reasoning_active else CatState.IDLE)
	pass


func set_state(next_state: CatState) -> void:
	if state == next_state:
		return
	state = next_state
	state_seconds = 0.0
	state_blend = 0.0
	if next_state in [CatState.TOOL_SUCCESS, CatState.TOOL_FAILED]:
		impact_pulse = 1.0
	queue_redraw()
	pass


func _draw() -> void:
	if size.x < 180.0 or size.y < 150.0:
		return
	var available_size := size - Vector2(Margin.ma_4 * 2.0, Margin.ma_4 * 2.0)
	var stage_scale := minf(1.0, minf(available_size.x / STAGE_SIZE.x, available_size.y / STAGE_SIZE.y))
	var scaled_stage_size := STAGE_SIZE * stage_scale
	var origin := Vector2(maxf(Margin.ma_4, size.x - scaled_stage_size.x - Margin.ma_4), maxf(Margin.ma_4, (size.y - scaled_stage_size.y) * 0.5))
	draw_set_transform(origin, 0.0, Vector2.ONE * stage_scale)
	draw_stage()
	draw_cat()
	draw_effects()
	draw_set_transform(Vector2.ZERO)
	pass


func draw_stage() -> void:
	var accent := ThemeColor.accent_theme_color()
	draw_oval(Vector2(220.0, 205.0), Vector2(88.0, 16.0), Color(0.0, 0.0, 0.0, 0.16))
	draw_line(Vector2(22.0, 211.0), Vector2(318.0, 211.0), Color(ColorBase.subtle_border, 0.55), 2.0, true)
	draw_line(Vector2(46.0, 215.0), Vector2(307.0, 215.0), Color(accent, 0.08), 5.0, true)
	pass


func draw_cat() -> void:
	var bounce := 0.0
	if state in [CatState.TOOL_SUCCESS, CatState.SUCCESS]:
		bounce = -absf(sin(state_seconds * 7.0)) * 7.0
	elif state == CatState.FAILED:
		bounce = sin(state_seconds * 23.0) * 3.0
	elif state == CatState.THINKING:
		bounce = sin(elapsed * 3.2) * 1.2
	var breath := sin(elapsed * 2.1) * 1.5
	var anticipation := sin(state_seconds / 0.18 * PI) * 5.0 if state == CatState.TOOL_START and state_seconds < 0.18 else 0.0
	var failure_crouch := state_blend * 5.0 if state in [CatState.TOOL_FAILED, CatState.FAILED] else 0.0
	var center := Vector2(225.0 + body_lean + anticipation, 158.0 + bounce + failure_crouch + breath * (0.35 + sit_blend * 0.3))
	# The tip travels behind the body on every cycle, so the tail emerges on both sides of the cat.
	var tail_side_blend := tail_swing_amount(tail_swing_phase)
	var tail_x := lerpf(-74.0, 82.0, tail_side_blend)
	var tail_y := lerpf(25.0, 20.0, tail_side_blend) + tail_offset + tail_posture
	var tail_tip := center + Vector2(tail_x, tail_y)
	draw_tail(center + Vector2(-37.0, 27.0), tail_tip, tail_side_blend)
	var body_center := center + Vector2(0.0, lerpf(32.0, 24.0, sit_blend))
	var body_radii := Vector2(lerpf(67.0, 52.0, sit_blend), lerpf(30.0, 42.0, sit_blend) + breath * 0.25)
	draw_oval(body_center, body_radii + Vector2(3.0, 3.0), LINE_BROWN)
	draw_oval(body_center, body_radii, FUR_ORANGE)
	draw_oval(body_center + Vector2(8.0, 9.0), body_radii * Vector2(0.48, 0.68), FUR_LIGHT)
	draw_resting_paw(body_center, body_radii)
	# The reaching foreleg sits over the torso but behind the head, so its transition cannot cover the face.
	draw_paws(center, FUR_SHADOW)
	var thinking_tilt := Vector2(sin(elapsed * 1.35) * 3.5, cos(elapsed * 2.1) * 1.2) if state == CatState.THINKING else Vector2.ZERO
	var head_center := center + Vector2(lerpf(10.0, 0.0, sit_blend), lerpf(0.0, -25.0, sit_blend) + breath * 0.16) + gaze * 0.55 + thinking_tilt
	var fluff := 7.0 if state in [CatState.TOOL_FAILED, CatState.FAILED] else 0.0
	draw_cat_ears(head_center, FUR_ORANGE, FUR_SHADOW, fluff)
	draw_circle(head_center, 45.5, LINE_BROWN)
	draw_circle(head_center, 42.0, FUR_ORANGE)
	draw_tabby_marks(head_center)
	draw_oval(head_center + Vector2(-11.0, 12.0), Vector2(17.0, 14.0), FUR_LIGHT)
	draw_oval(head_center + Vector2(11.0, 12.0), Vector2(17.0, 14.0), FUR_LIGHT)
	draw_head_highlight(head_center)
	draw_cat_face(head_center)
	pass


func draw_tail(from: Vector2, to: Vector2, side_blend: float) -> void:
	var direction := to - from
	var curve_side := lerpf(-18.0, 14.0, side_blend)
	var control := from.lerp(to, 0.48) + direction.normalized().orthogonal() * curve_side
	var points := PackedVector2Array()
	for index in range(15):
		var amount := float(index) / 14.0
		var inverse := 1.0 - amount
		points.append(from * inverse * inverse + control * 2.0 * inverse * amount + to * amount * amount)
	draw_polyline(points, LINE_BROWN, 22.0, true)
	draw_polyline(points, FUR_ORANGE, 16.0, true)
	# Dark bands make the tail unmistakable and keep its rounded end distinct from a paw pad.
	for amount: float in [0.64, 0.82]:
		var scaled: float = amount * float(points.size() - 1)
		var point_index := mini(int(scaled), points.size() - 2)
		var point := points[point_index].lerp(points[point_index + 1], scaled - point_index)
		var tangent := (points[point_index + 1] - points[point_index]).normalized()
		var normal := tangent.orthogonal()
		draw_line(point - normal * 8.0, point + normal * 8.0, FUR_SHADOW, 4.0, true)
	draw_circle(to, 10.5, LINE_BROWN)
	draw_circle(to, 7.5, FUR_ORANGE)
	draw_arc(to, 6.0, -2.4, 0.7, 12, Color(FUR_LIGHT, 0.35), 1.5, true)
	pass


func draw_cat_ears(head: Vector2, fur: Color, _inner: Color, fluff: float) -> void:
	var left_ear_turn := (sin(elapsed * 3.7) * 3.2 + sin(elapsed * 7.1) * 1.3) * ear_blend
	var right_ear_turn := (sin(elapsed * 4.1 + 1.4) * 2.8 + sin(elapsed * 6.3 + 0.5)) * ear_blend
	var fear_blend := state_blend if state in [CatState.TOOL_FAILED, CatState.FAILED] else 0.0
	var ear_drop := fear_blend * 18.0
	var ear_spread := fear_blend * 13.0
	var left := PackedVector2Array([head + Vector2(-34.0 - fluff, -19.0), head + Vector2(-24.0 - ear_spread + left_ear_turn, -61.0 - fluff + ear_drop), head + Vector2(-3.0, -37.0)])
	var right := PackedVector2Array([head + Vector2(6.0, -37.0), head + Vector2(29.0 + ear_spread - right_ear_turn, -61.0 - fluff + ear_drop), head + Vector2(38.0 + fluff, -17.0)])
	draw_colored_polygon(PackedVector2Array([left[0] + Vector2(-3.0, 2.0), left[1] + Vector2(0.0, -4.0), left[2] + Vector2(2.0, 1.0)]), LINE_BROWN)
	draw_colored_polygon(PackedVector2Array([right[0] + Vector2(-2.0, 1.0), right[1] + Vector2(0.0, -4.0), right[2] + Vector2(3.0, 2.0)]), LINE_BROWN)
	draw_colored_polygon(left, fur)
	draw_colored_polygon(right, fur)
	draw_colored_polygon(PackedVector2Array([left[0].lerp(left[1], 0.25), left[1].lerp(left[0], 0.25), left[2].lerp(left[1], 0.42)]), EAR_PINK)
	draw_colored_polygon(PackedVector2Array([right[0].lerp(right[1], 0.42), right[1].lerp(right[2], 0.25), right[2].lerp(right[1], 0.25)]), EAR_PINK)
	pass


func draw_tabby_marks(head: Vector2) -> void:
	for offset in [-12.0, 0.0, 12.0]:
		var top := head + Vector2(offset, -38.0 + absf(offset) * 0.18)
		draw_line(top, top + Vector2(-offset * 0.12, 10.0), FUR_SHADOW, 4.0, true)
	draw_arc(head + Vector2(-35.0, -5.0), 10.0, -0.65, 0.7, 12, FUR_SHADOW, 3.5, true)
	draw_arc(head + Vector2(35.0, -5.0), 10.0, PI - 0.7, PI + 0.65, 12, FUR_SHADOW, 3.5, true)
	pass


func draw_head_highlight(head: Vector2) -> void:
	draw_arc(head + Vector2(-7.0, -6.0), 31.0, -2.45, -1.25, 18, Color(1.0, 0.87, 0.66, 0.22), 3.0, true)
	pass


func draw_cat_face(head: Vector2) -> void:
	var ink := LINE_BROWN
	var eye_y := head.y + 1.0
	var blink := blink_closed(elapsed, state == CatState.IDLE)
	if blink:
		draw_line(head + Vector2(-20.0, 4.0), head + Vector2(-8.0, 5.0), ink, 2.5, true)
		draw_line(head + Vector2(8.0, 5.0), head + Vector2(20.0, 4.0), ink, 2.5, true)
	else:
		var look := gaze.limit_length(3.0)
		for eye_x in [-14.0, 14.0]:
			draw_oval(Vector2(head.x + eye_x, eye_y), Vector2(7.0, 9.0), Color.WHITE)
			draw_oval(Vector2(head.x + eye_x, eye_y) + look, Vector2(3.5, 5.5), ink)
			draw_circle(Vector2(head.x + eye_x - 1.0, eye_y - 2.0) + look, 1.25, Color.WHITE)
	var nose_twitch := sin(elapsed * 5.4) * 0.65 + sin(elapsed * 9.7 + 0.8) * 0.25
	var nose := head + Vector2(nose_twitch * 0.35, 14.0 + nose_twitch * 0.45)
	draw_colored_polygon(PackedVector2Array([nose + Vector2(-4.5, 0.0), nose + Vector2(4.5, 0.0), nose + Vector2(0.0, 4.5)]), EAR_PINK)
	draw_polyline(mouth_points(nose + Vector2(0.0, 8.0), mouth_blend), ink, 1.7, true)
	for side in [-1.0, 1.0]:
		for offset in [-3.0, 3.0]:
			var phase: float = float(side) * 0.7 + float(offset) * 0.19
			var sway := whisker_wave(whisker_phase, phase)
			var root := head + Vector2(float(side) * 20.0 + nose_twitch * 0.2, 15.0 + float(offset) + sway * 0.35 + nose_twitch * 0.25)
			var tip := head + Vector2(float(side) * (43.0 + sway * 0.8), 13.0 + float(offset) * 1.4 + sway * 1.8)
			draw_line(root, tip, Color(ink, 0.55), 1.0, true)
	draw_circle(head + Vector2(-27.0, 13.0), 5.0, Color(EAR_PINK, 0.23))
	draw_circle(head + Vector2(27.0, 13.0), 5.0, Color(EAR_PINK, 0.23))
	pass


func draw_paws(center: Vector2, _color: Color) -> void:
	var paw := center + Vector2(-34.0, 42.0)
	var tool_reach := Vector2(-42.0, -18.0)
	if state == CatState.TOOL_WAITING:
		tool_reach = Vector2(-29.0 + sin(elapsed * 6.0) * 7.0, -13.0 + absf(sin(elapsed * 6.0)) * 5.0)
	paw += tool_reach * paw_blend
	# During thought/idle interludes the free paw rises toward the chin for grooming and pondering.
	paw += Vector2(29.0, -43.0 + sin(elapsed * 5.0) * 2.0) * gesture_blend
	var shoulder := center + Vector2(-15.0, 20.0)
	var elbow := shoulder.lerp(paw, 0.48) + Vector2(0.0, 7.0 * paw_blend)
	# Equal-width segments plus circular joints form one continuous capsule at every angle.
	draw_line(shoulder, elbow, LINE_BROWN, 20.0, true)
	draw_line(elbow, paw, LINE_BROWN, 20.0, true)
	draw_circle(shoulder, 10.0, LINE_BROWN)
	draw_circle(elbow, 10.0, LINE_BROWN)
	draw_line(shoulder, elbow, FUR_ORANGE, 14.0, true)
	draw_line(elbow, paw, FUR_ORANGE, 14.0, true)
	draw_circle(shoulder, 7.0, FUR_ORANGE)
	draw_circle(elbow, 7.0, FUR_ORANGE)
	draw_circle(paw, 10.0, LINE_BROWN)
	draw_circle(paw, 7.0, FUR_LIGHT)
	for toe_offset in [-3.0, 0.0, 3.0]:
		draw_circle(paw + Vector2(toe_offset, 1.0), 1.0, Color(FUR_SHADOW, 0.7))
	draw_reach_particles(paw, paw_blend)
	pass


func draw_reach_particles(paw: Vector2, reach_amount: float) -> void:
	var particle_amount := reach_particle_amount(reach_amount)
	if is_zero_approx(particle_amount):
		return
	var accent := ThemeColor.accent_theme_color()
	for index in range(7):
		var phase := fmod(elapsed * 1.65 + float(index) / 7.0, 1.0)
		var angle := -2.75 + float(index) * 0.72 + sin(elapsed * 2.1 + float(index)) * 0.18
		var radius := lerpf(7.0, 25.0, phase)
		var position := paw + Vector2.from_angle(angle) * radius + Vector2(-phase * 5.0, -phase * 3.0)
		var alpha := reach_particle_alpha(particle_amount, phase)
		var particle_color := Color(accent, alpha * 0.82)
		if index % 3 == 0:
			var arm := Vector2.from_angle(angle + PI * 0.25) * (2.0 + particle_amount)
			draw_line(position - arm, position + arm, particle_color, 1.4, true)
			draw_line(position - arm.orthogonal(), position + arm.orthogonal(), particle_color, 1.4, true)
		else:
			draw_circle(position, lerpf(1.2, 2.4, 1.0 - phase) * particle_amount, particle_color)
	pass


func draw_resting_paw(body_center: Vector2, body_radii: Vector2) -> void:
	# The tucked paw only peeks out from the body; no forearm is drawn across the belly.
	var paw_scale := 1.0 + resting_paw_activity * (0.045 + sin(elapsed * 5.5) * 0.075)
	# Anchor to the body ellipse so breathing and pose morphs carry the paw along its lower-right edge.
	var resting_paw := body_center + Vector2(body_radii.x * 0.56, body_radii.y * 0.48)
	resting_paw += Vector2(sin(elapsed * 2.1) * 0.6, cos(elapsed * 2.1) * 0.45) * resting_paw_activity
	draw_oval(resting_paw, Vector2(13.0, 10.0) * paw_scale, LINE_BROWN)
	draw_oval(resting_paw, Vector2(9.5, 6.5) * paw_scale, FUR_LIGHT)
	for toe_offset in [-3.0, 0.0, 3.0]:
		draw_circle(resting_paw + Vector2(toe_offset, 0.5) * paw_scale, 0.9 * paw_scale, Color(FUR_SHADOW, 0.72))
	pass


func draw_effects() -> void:
	match state:
		CatState.IDLE:
			draw_sleep_marks()
		CatState.THINKING:
			draw_reasoning_stream()
		CatState.TOOL_START:
			draw_tool_button(false)
		CatState.TOOL_WAITING:
			draw_tool_button(true)
		CatState.TOOL_SUCCESS:
			draw_status_burst(ColorBase.success, "OK")
		CatState.TOOL_FAILED:
			draw_status_burst(ColorBase.error, "!")
		CatState.SUCCESS:
			draw_result_card(ColorBase.success, "RESULT READY")
		CatState.FAILED:
			draw_result_card(ColorBase.error, "ERROR")
		CatState.CANCELLED:
			draw_cancel_sweep()
	pass


func draw_sleep_marks() -> void:
	var accent := ThemeColor.accent_theme_color()
	for index in range(3):
		var phase := fmod(elapsed * 0.32 + float(index) * 0.28, 1.0)
		var position := Vector2(258.0 + phase * 35.0, 106.0 - phase * 54.0)
		draw_paw_print(position, 0.18 + float(index) * 0.025, Color(accent, 0.65 * (1.0 - phase)), Color.TRANSPARENT, -0.2)
	pass


func draw_reasoning_stream() -> void:
	var accent := ThemeColor.accent_theme_color()
	for index in range(5):
		var phase := fmod(elapsed * 0.55 + float(index) / 5.0, 1.0)
		var position := Vector2(74.0 + phase * 96.0, 68.0 + sin(phase * TAU + index) * 12.0)
		draw_paw_print(position, 0.16 + phase * 0.06, Color(accent, 0.22 + phase * 0.55), Color.TRANSPARENT, phase * 0.5 - 0.25)
	pass


func draw_tool_button(loading: bool) -> void:
	var accent := ThemeColor.accent_theme_color()
	var center := Vector2(88.0, 173.0)
	draw_paw_print(center + Vector2(2.0, 4.0), 1.05, Color(0.0, 0.0, 0.0, 0.2), Color.TRANSPARENT)
	draw_paw_print(center, 1.0, Color(ColorBase.control_surface, 0.96), Color(accent, 0.86))
	draw_centered_text(center + Vector2(0.0, 12.0), VisualToolFormatter.glyph(active_tool_name), Fonts.semibold(), Typography.title_medium_size, ColorBase.primary_text)
	if loading:
		draw_yarn_loader(center, accent)
	draw_centered_text(center + Vector2(0.0, 56.0), compact_label(VisualToolFormatter.title_name(active_tool_name), 15), Fonts.medium(), Typography.label_small_size, ColorBase.secondary_text)
	pass


func draw_yarn_loader(center: Vector2, color: Color) -> void:
	var orbit_angle := elapsed * 3.2
	for index in range(3):
		var trail_angle := orbit_angle - float(index) * 0.42
		var paw_center := center + Vector2.from_angle(trail_angle) * 44.0
		var alpha := 0.85 - float(index) * 0.22
		draw_paw_print(paw_center, 0.28 - float(index) * 0.035, Color(color, alpha), Color.TRANSPARENT, trail_angle + PI * 0.5)
	pass


func draw_status_burst(color: Color, label: String) -> void:
	if label == "!":
		draw_paw_alert(color)
		return
	var center := Vector2(104.0, 154.0)
	var appear := ease(state_blend, -1.6) * (1.0 + impact_pulse * 0.08)
	draw_paw_print(center, appear, Color(color, 0.92 * appear), LINE_BROWN)
	draw_centered_text(center + Vector2(0.0, 12.0), label, Fonts.bold(), Typography.title_medium_size, Color.WHITE)
	pass


func draw_paw_alert(color: Color) -> void:
	var appear := ease(state_blend, -1.6)
	var wobble := sin(state_seconds * 24.0) * 0.09 * (1.0 - clampf(state_seconds / 0.42, 0.0, 1.0))
	var center := Vector2(104.0, 154.0) + Vector2(sin(state_seconds * 31.0), 0.0) * impact_pulse * 2.5
	var paw_color := Color(color).lerp(Color(1.0, 0.34, 0.3), 0.28)
	draw_paw_print(center, appear, paw_color, LINE_BROWN, wobble)
	draw_centered_text(center + Vector2(0.0, 12.0).rotated(wobble) * appear, "!", Fonts.bold(), Typography.title_large_size, Color.WHITE)
	pass


func draw_result_card(color: Color, title: String) -> void:
	var progress := minf(1.0, state_seconds / 0.48)
	var center := Vector2(108.0, 151.0).lerp(Vector2(77.0, 123.0), 1.0 - progress)
	draw_paw_print(center, 1.18 * progress, Color(ColorBase.control_surface, 0.98), Color(color, 0.9))
	draw_centered_text(center + Vector2(0.0, 10.0), "✓" if title == "RESULT READY" else "!", Fonts.bold(), Typography.title_medium_size, color)
	draw_centered_text(center + Vector2(0.0, 57.0), title, Fonts.semibold(), Typography.label_medium_size, ColorBase.primary_text)
	draw_centered_text(center + Vector2(0.0, 76.0), compact_label(card_text, 17), Fonts.regular(), Typography.label_small_size, ColorBase.secondary_text)
	pass


func draw_cancel_sweep() -> void:
	var progress := clampf(state_seconds / 0.8, 0.0, 1.0)
	for index in range(5):
		var start := Vector2(50.0 + index * 27.0, 178.0 - float(index % 2) * 16.0)
		var position := start + Vector2(-190.0 * progress, -45.0 * progress * progress + sin(float(index)) * 12.0)
		draw_paw_print(position, 0.28, Color(ColorBase.control_surface, 0.88), Color(ColorBase.subtle_border, 0.7), -0.5 - progress)
	draw_text(Vector2(42.0, 68.0), "CLEAN SLATE", Fonts.semibold(), Typography.label_medium_size, Color(ColorBase.secondary_text, 1.0 - progress * 0.7))
	pass


func draw_paw_print(center: Vector2, scale: float, fill: Color, outline: Color, rotation: float = 0.0) -> void:
	var main_center := center + Vector2(0.0, 7.0).rotated(rotation) * scale
	if outline.a > 0.0:
		draw_rotated_oval(main_center, Vector2(22.5, 18.5) * scale, outline, rotation)
	draw_rotated_oval(main_center, Vector2(19.0, 15.0) * scale, fill, rotation)
	var toe_offsets := [Vector2(-18.0, -13.0), Vector2(-6.5, -22.0), Vector2(6.5, -22.0), Vector2(18.0, -13.0)]
	var toe_rotations := [-0.38, -0.12, 0.12, 0.38]
	for index in range(4):
		var toe_center: Vector2 = center + toe_offsets[index].rotated(rotation) * scale
		var toe_rotation: float = rotation + toe_rotations[index]
		if outline.a > 0.0:
			draw_rotated_oval(toe_center, Vector2(7.0, 9.0) * scale, outline, toe_rotation)
		draw_rotated_oval(toe_center, Vector2(4.5, 6.5) * scale, fill, toe_rotation)
	pass


func draw_rotated_oval(center: Vector2, radii: Vector2, color: Color, rotation: float) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := float(index) * TAU / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y).rotated(rotation))
	draw_colored_polygon(points, color)
	pass


func draw_oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(36):
		var angle := float(index) * TAU / 36.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
	pass


func draw_text(position: Vector2, text: String, font: Font, font_size: int, color: Color) -> void:
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	pass


func first_active_tool_name() -> String:
	for tool: Dictionary in active_tools.values():
		return String(tool.get("name", ""))
	return ""


func advance_tail(delta: float) -> void:
	var speed := 1.2 if state == CatState.IDLE else 2.5
	var amplitude := 10.0 if state == CatState.IDLE else 16.0
	if state in [CatState.TOOL_FAILED, CatState.FAILED]:
		speed = 8.0
		amplitude = 9.0
	tail_bob_phase = fmod(tail_bob_phase + delta * speed, TAU)
	var target := sin(tail_bob_phase) * amplitude
	var stiffness := 42.0
	var damping := 10.0
	tail_velocity += (target - tail_offset) * stiffness * delta
	tail_velocity *= exp(-damping * delta)
	tail_offset += tail_velocity * delta
	pass


func gaze_target() -> Vector2:
	match state:
		CatState.THINKING:
			return Vector2(sin(elapsed * 1.8) * 2.8, -1.4 + cos(elapsed * 1.15))
		CatState.TOOL_START, CatState.TOOL_WAITING:
			return Vector2(-3.0, 2.0)
		CatState.TOOL_SUCCESS, CatState.TOOL_FAILED:
			return Vector2(-2.6, 0.5)
		CatState.SUCCESS, CatState.FAILED:
			return Vector2(-3.0, -0.5)
	return Vector2(sin(elapsed * 0.55) * 0.8, 0.0)


func should_raise_paw() -> bool:
	if state == CatState.THINKING:
		var thinking_phase := fmod(state_seconds, 6.0)
		return thinking_phase >= 2.1 and thinking_phase <= 3.55
	if state == CatState.IDLE:
		var idle_phase := fmod(state_seconds, 7.5)
		return idle_phase >= 4.6 and idle_phase <= 5.8
	return false


static func smooth_value(current: float, target: float, speed: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-speed * delta))


static func tail_swing_amount(phase: float) -> float:
	return (sin(phase - PI * 0.5) + 1.0) * 0.5


static func whisker_wave(seconds: float, phase: float) -> float:
	return sin(seconds * 2.4 + phase) * 0.72 + sin(seconds * 5.1 + phase * 1.7) * 0.28


static func blink_closed(seconds: float, idle: bool) -> bool:
	var cycle_seconds := 4.8
	var cycle_index := floori(seconds / cycle_seconds)
	var phase := fmod(seconds, cycle_seconds)
	var primary_duration := 0.24 if idle else 0.16
	var double_blink := idle and cycle_index % 3 == 2 and phase >= 0.36 and phase < 0.52
	return phase < primary_duration or double_blink


static func mouth_points(center: Vector2, happy_blend: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(13):
		var normalized_x := float(index) / 6.0 - 1.0
		var unhappy_y := -4.5 + absf(normalized_x) * 4.5
		var happy_y := (1.0 - normalized_x * normalized_x) * 6.5
		points.append(center + Vector2(normalized_x * 9.0, lerpf(unhappy_y, happy_y, happy_blend)))
	return points


static func reach_particle_alpha(reach_amount: float, phase: float) -> float:
	return clampf(reach_amount, 0.0, 1.0) * sin(clampf(phase, 0.0, 1.0) * PI)


static func reach_particle_amount(reach_amount: float) -> float:
	return clampf(inverse_lerp(REACH_PARTICLE_DELAY_PROGRESS, 1.0, reach_amount), 0.0, 1.0)


static func compact_label(text: String, max_length: int) -> String:
	var single_line := text.replace("\n", " ").strip_edges()
	return single_line if single_line.length() <= max_length else single_line.left(max_length - 1) + "…"
