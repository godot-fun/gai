class_name DesktopCat
extends VisualEffect

## An event-driven desktop companion drawn without external assets.

const TOOL_WAIT_SECONDS := 1.5
const REACTION_SECONDS := 0.9
const END_HOLD_SECONDS := 2.0
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
var active_tool_name: String = ""
var card_text: String = ""
var fade_tween: Tween
var sit_blend: float = 0.0
var paw_blend: float = 0.0
var ear_blend: float = 0.0
var state_blend: float = 1.0
var tail_offset: float = 0.0
var tail_velocity: float = 0.0
var gaze: Vector2 = Vector2.ZERO
var body_lean: float = 0.0
var impact_pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.DESKTOP_CAT


func set_visual_visible(show: bool, animated: bool) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	if show:
		visible = true
		modulate.a = 0.0 if animated else 1.0
		if animated:
			fade_tween = create_tween()
			fade_tween.tween_property(self, "modulate:a", 1.0, 0.25)
		return
	if not animated:
		visible = false
		modulate.a = 1.0
		return
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	fade_tween.tween_callback(func() -> void: visible = false)
	pass


func reset_visual() -> void:
	active_tools.clear()
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
	set_state(CatState.IDLE)
	pass


func on_agent_start(_session_id: int) -> void:
	set_state(CatState.THINKING)
	pass


func on_agent_end(error_message: String) -> float:
	active_tools.clear()
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
	if active_tools.is_empty():
		set_state(CatState.THINKING)
	pass


func on_turn_end() -> void:
	reasoning_active = false
	if active_tools.is_empty() and state not in [CatState.SUCCESS, CatState.FAILED, CatState.CANCELLED]:
		set_state(CatState.IDLE)
	pass


func on_message_update(_chunk: String, stream_kind: String) -> void:
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING and active_tools.is_empty():
		reasoning_active = true
		set_state(CatState.THINKING)
	pass


func on_tool_execution_start(tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	active_tools[tool_call_id] = {"name": tool_name, "seconds": 0.0}
	active_tool_name = tool_name
	set_state(CatState.TOOL_START)
	pass


func on_tool_execution_end(tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	active_tools.erase(tool_call_id)
	active_tool_name = tool_name
	card_text = public_tool_name(tool_name)
	set_state(CatState.TOOL_FAILED if result.is_error else CatState.TOOL_SUCCESS)
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
	sit_blend = smooth_value(sit_blend, sit_target, 7.5, delta)
	paw_blend = smooth_value(paw_blend, paw_target, 10.0, delta)
	ear_blend = smooth_value(ear_blend, ear_target, 8.0, delta)
	body_lean = smooth_value(body_lean, lean_target, 8.0, delta)
	state_blend = smooth_value(state_blend, 1.0, 8.0, delta)
	gaze = gaze.lerp(gaze_target(), 1.0 - exp(-7.0 * delta))
	impact_pulse = move_toward(impact_pulse, 0.0, delta * 4.5)
	advance_tail(delta)
	for tool_call_id: String in active_tools.keys():
		var tool: Dictionary = active_tools[tool_call_id]
		tool["seconds"] = float(tool["seconds"]) + delta
		active_tools[tool_call_id] = tool
	if not active_tools.is_empty() and longest_tool_seconds() >= TOOL_WAIT_SECONDS and state == CatState.TOOL_START:
		set_state(CatState.TOOL_WAITING)
	if state in [CatState.TOOL_SUCCESS, CatState.TOOL_FAILED] and state_seconds >= REACTION_SECONDS:
		if not active_tools.is_empty():
			set_state(CatState.TOOL_WAITING if longest_tool_seconds() >= TOOL_WAIT_SECONDS else CatState.TOOL_START)
		else:
			set_state(CatState.THINKING if reasoning_active else CatState.IDLE)
	queue_redraw()
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
	var origin := Vector2(maxf(Margin.ma_4, size.x - STAGE_SIZE.x - Margin.ma_4), maxf(Margin.ma_4, (size.y - STAGE_SIZE.y) * 0.5))
	draw_set_transform(origin)
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
	var breath := sin(elapsed * 2.1) * 1.5
	var anticipation := sin(state_seconds / 0.18 * PI) * 5.0 if state == CatState.TOOL_START and state_seconds < 0.18 else 0.0
	var center := Vector2(225.0 + body_lean + anticipation, 158.0 + bounce + breath * (0.35 + sit_blend * 0.3))
	var tail_speed := 1.15 if state == CatState.IDLE else 2.6
	# Move the tail behind the opposite side while reaching so its tip never reads as an extra paw joint.
	var tail_x := lerpf(-74.0, 55.0, paw_blend)
	var tail_y := lerpf(25.0, 8.0, paw_blend) + tail_offset + sin(elapsed * tail_speed) * 2.5
	var tail_tip := center + Vector2(tail_x, tail_y)
	draw_tail(center + Vector2(-37.0, 27.0), tail_tip)
	var body_center := center + Vector2(0.0, lerpf(32.0, 24.0, sit_blend))
	var body_radii := Vector2(lerpf(67.0, 52.0, sit_blend), lerpf(30.0, 42.0, sit_blend) + breath * 0.25)
	draw_oval(body_center, body_radii + Vector2(3.0, 3.0), LINE_BROWN)
	draw_oval(body_center, body_radii, FUR_ORANGE)
	draw_oval(body_center + Vector2(8.0, 9.0), body_radii * Vector2(0.48, 0.68), FUR_LIGHT)
	draw_resting_paw(center)
	# The reaching foreleg sits over the torso but behind the head, so its transition cannot cover the face.
	draw_paws(center, FUR_SHADOW)
	var head_center := center + Vector2(lerpf(10.0, 0.0, sit_blend), lerpf(0.0, -25.0, sit_blend)) + gaze * 0.55
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


func draw_tail(from: Vector2, to: Vector2) -> void:
	var direction := to - from
	var control := from.lerp(to, 0.48) + direction.normalized().orthogonal() * (-18.0 if paw_blend < 0.5 else 14.0)
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
	var ear_turn := sin(elapsed * 4.0) * 5.0 * ear_blend
	var fear_blend := state_blend if state in [CatState.TOOL_FAILED, CatState.FAILED] else 0.0
	var ear_drop := fear_blend * 18.0
	var ear_spread := fear_blend * 13.0
	var left := PackedVector2Array([head + Vector2(-34.0 - fluff, -19.0), head + Vector2(-24.0 - ear_spread + ear_turn, -61.0 - fluff + ear_drop), head + Vector2(-3.0, -37.0)])
	var right := PackedVector2Array([head + Vector2(6.0, -37.0), head + Vector2(29.0 + ear_spread - ear_turn, -61.0 - fluff + ear_drop), head + Vector2(38.0 + fluff, -17.0)])
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
	var blink_phase := fmod(elapsed + 0.15 * sin(elapsed * 0.37), 4.8)
	var blink := blink_phase < 0.16 or (state == CatState.IDLE and blink_phase < 0.42)
	if blink:
		draw_line(head + Vector2(-20.0, 4.0), head + Vector2(-8.0, 5.0), ink, 2.5, true)
		draw_line(head + Vector2(8.0, 5.0), head + Vector2(20.0, 4.0), ink, 2.5, true)
	else:
		var look := gaze.limit_length(3.0)
		for eye_x in [-14.0, 14.0]:
			draw_oval(Vector2(head.x + eye_x, eye_y), Vector2(7.0, 9.0), Color.WHITE)
			draw_oval(Vector2(head.x + eye_x, eye_y) + look, Vector2(3.5, 5.5), ink)
			draw_circle(Vector2(head.x + eye_x - 1.0, eye_y - 2.0) + look, 1.25, Color.WHITE)
	var nose := head + Vector2(0.0, 14.0)
	draw_colored_polygon(PackedVector2Array([nose + Vector2(-4.5, 0.0), nose + Vector2(4.5, 0.0), nose + Vector2(0.0, 4.5)]), EAR_PINK)
	draw_line(nose + Vector2(0.0, 4.0), nose + Vector2(-6.0, 9.0), ink, 1.5, true)
	draw_line(nose + Vector2(0.0, 4.0), nose + Vector2(6.0, 9.0), ink, 1.5, true)
	for side in [-1.0, 1.0]:
		for offset in [-3.0, 3.0]:
			draw_line(head + Vector2(side * 20.0, 15.0 + offset), head + Vector2(side * 43.0, 13.0 + offset * 1.4), Color(ink, 0.55), 1.0, true)
	draw_circle(head + Vector2(-27.0, 13.0), 5.0, Color(EAR_PINK, 0.23))
	draw_circle(head + Vector2(27.0, 13.0), 5.0, Color(EAR_PINK, 0.23))
	if state in [CatState.TOOL_SUCCESS, CatState.SUCCESS]:
		draw_arc(head + Vector2(0.0, 18.0), 11.0, 0.2, PI - 0.2, 14, LINE_BROWN, 1.8, true)
	pass


func draw_paws(center: Vector2, _color: Color) -> void:
	var paw := center + Vector2(-34.0, 42.0)
	var tool_reach := Vector2(-42.0, -18.0)
	if state == CatState.TOOL_WAITING:
		tool_reach = Vector2(-29.0 + sin(elapsed * 6.0) * 7.0, -13.0)
	paw += tool_reach * paw_blend
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
	pass


func draw_resting_paw(center: Vector2) -> void:
	# The tucked paw only peeks out from the body; drawing a full forearm here cuts through the belly.
	var resting_paw := center + Vector2(30.0, 45.0)
	draw_oval(resting_paw, Vector2(13.0, 10.0), LINE_BROWN)
	draw_oval(resting_paw, Vector2(9.5, 6.5), FUR_LIGHT)
	for toe_offset in [-3.0, 0.0, 3.0]:
		draw_circle(resting_paw + Vector2(toe_offset, 0.5), 0.9, Color(FUR_SHADOW, 0.72))
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
		draw_text(position, "z", Fonts.semibold(), Typography.label_large_size + index * 2, Color(accent, 0.65 * (1.0 - phase)))
	pass


func draw_reasoning_stream() -> void:
	var accent := ThemeColor.accent_theme_color()
	for index in range(6):
		var phase := fmod(elapsed * 0.55 + float(index) / 6.0, 1.0)
		var position := Vector2(74.0 + phase * 96.0, 68.0 + sin(phase * TAU + index) * 12.0)
		draw_circle(position, 2.0 + float(index % 2), Color(accent, 0.25 + phase * 0.5))
		if index % 2 == 0:
			draw_line(position + Vector2(6.0, 0.0), position + Vector2(20.0, 0.0), Color(accent, 0.32), 2.0, true)
	pass


func draw_tool_button(loading: bool) -> void:
	var accent := ThemeColor.accent_theme_color()
	var center := Vector2(88.0, 173.0)
	draw_circle(center + Vector2(2.0, 4.0), 32.0, Color(0.0, 0.0, 0.0, 0.2))
	draw_circle(center, 31.0, Color(ColorBase.control_surface, 0.96))
	draw_arc(center, 31.0, 0.0, TAU, 40, Color(accent, 0.8), 2.5, true)
	draw_centered_text(center + Vector2(0.0, 6.0), tool_glyph(active_tool_name), Fonts.semibold(), Typography.title_medium_size, ColorBase.primary_text)
	if loading:
		draw_yarn_loader(center, accent)
	draw_centered_text(center + Vector2(0.0, 51.0), compact_label(public_tool_name(active_tool_name), 15), Fonts.medium(), Typography.label_small_size, ColorBase.secondary_text)
	pass


func draw_yarn_loader(center: Vector2, color: Color) -> void:
	var orbit_angle := elapsed * 3.2
	var ball := center + Vector2.from_angle(orbit_angle) * 43.0
	draw_circle(ball + Vector2(2.0, 3.0), 11.0, Color(0.0, 0.0, 0.0, 0.18))
	draw_circle(ball, 10.0, color)
	for offset in [-4.0, 0.0, 4.0]:
		draw_arc(ball + Vector2(offset * 0.25, 0.0), 6.0 + absf(offset) * 0.4, -2.3 + offset * 0.05, 0.9 + offset * 0.04, 12, Color(Color.WHITE, 0.5), 1.2, true)
	var strand_end := ball + Vector2.from_angle(orbit_angle + PI * 0.7) * 16.0
	draw_line(ball, strand_end, Color(color, 0.75), 2.0, true)
	draw_arc(center, 43.0, orbit_angle - 1.1, orbit_angle - 0.18, 18, Color(color, 0.28), 2.0, true)
	pass


func draw_status_burst(color: Color, label: String) -> void:
	var center := Vector2(104.0, 154.0)
	var pulse := clampf(state_seconds / REACTION_SECONDS, 0.0, 1.0)
	var appear := ease(state_blend, -1.6) * (1.0 + impact_pulse * 0.08)
	for ray in range(10):
		var direction := Vector2.from_angle(float(ray) * TAU / 10.0)
		draw_line(center + direction * (24.0 + pulse * 6.0) * appear, center + direction * (35.0 + pulse * 12.0) * appear, Color(color, (1.0 - pulse * 0.55) * appear), 2.5, true)
	draw_circle(center, 22.0 * appear, Color(color, 0.92 * appear))
	draw_centered_text(center + Vector2(0.0, 7.0), label, Fonts.bold(), Typography.title_medium_size, Color.WHITE)
	pass


func draw_result_card(color: Color, title: String) -> void:
	var progress := minf(1.0, state_seconds / 0.48)
	var card_position := Vector2(32.0, 84.0).lerp(Vector2(63.0, 112.0), 1.0 - progress)
	var rect := Rect2(card_position, Vector2(125.0, 72.0))
	draw_rect(rect, Color(ColorBase.control_surface, 0.98), true)
	draw_rect(rect, Color(color, 0.88), false, 2.5)
	draw_circle(rect.position + Vector2(17.0, 18.0), 7.0, color)
	draw_text(rect.position + Vector2(31.0, 23.0), title, Fonts.semibold(), Typography.label_medium_size, ColorBase.primary_text)
	draw_text(rect.position + Vector2(13.0, 49.0), compact_label(card_text, 17), Fonts.regular(), Typography.label_small_size, ColorBase.secondary_text)
	pass


func draw_cancel_sweep() -> void:
	var progress := clampf(state_seconds / 0.8, 0.0, 1.0)
	for index in range(5):
		var start := Vector2(50.0 + index * 27.0, 178.0 - float(index % 2) * 16.0)
		var position := start + Vector2(-190.0 * progress, -45.0 * progress * progress + sin(float(index)) * 12.0)
		var paper := Rect2(position, Vector2(21.0, 14.0))
		draw_rect(paper, Color(ColorBase.control_surface, 0.88), true)
		draw_rect(paper, Color(ColorBase.subtle_border, 0.7), false, 1.0)
	draw_text(Vector2(42.0, 68.0), "CLEAN SLATE", Fonts.semibold(), Typography.label_medium_size, Color(ColorBase.secondary_text, 1.0 - progress * 0.7))
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


func draw_centered_text(position: Vector2, text: String, font: Font, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, position - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	pass


func longest_tool_seconds() -> float:
	var longest := 0.0
	for tool: Dictionary in active_tools.values():
		longest = maxf(longest, float(tool["seconds"]))
	return longest


func advance_tail(delta: float) -> void:
	var speed := 1.2 if state == CatState.IDLE else 2.5
	var amplitude := 10.0 if state == CatState.IDLE else 16.0
	if state in [CatState.TOOL_FAILED, CatState.FAILED]:
		speed = 8.0
		amplitude = 9.0
	var target := sin(elapsed * speed) * amplitude
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


static func smooth_value(current: float, target: float, speed: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-speed * delta))


static func public_tool_name(tool_name: String) -> String:
	var readable := tool_name.replace("_", " ").replace("-", " ").strip_edges()
	return readable.capitalize() if not readable.is_empty() else "Tool"


static func tool_glyph(tool_name: String) -> String:
	var normalized := tool_name.to_lower()
	if "read" in normalized:
		return "R"
	if "write" in normalized or "edit" in normalized:
		return "W"
	if "shell" in normalized or "bash" in normalized or "exec" in normalized:
		return ">_"
	if "search" in normalized or "find" in normalized or "grep" in normalized:
		return "?"
	if "web" in normalized or "fetch" in normalized:
		return "@"
	return public_tool_name(tool_name).left(2).to_upper()


static func compact_label(text: String, max_length: int) -> String:
	var single_line := text.replace("\n", " ").strip_edges()
	return single_line if single_line.length() <= max_length else single_line.left(max_length - 1) + "…"
