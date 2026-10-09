class_name TaiChiDivinationFlow
extends RefCounted

## Final one-spin divination stage. The Fuxi circle remains still while a fine
## compass needle rotates from the center and selects one hexagram.

const PROMPT_SECONDS := 4.5
const SPIN_SECONDS := 8.0
const FLY_SECONDS := 2.3
const RESULT_REVEAL_SECONDS := 0.8
const RESULT_HOLD_SECONDS := 3.0
const TOTAL_SECONDS := PROMPT_SECONDS + SPIN_SECONDS + FLY_SECONDS + RESULT_REVEAL_SECONDS + RESULT_HOLD_SECONDS
const HEXAGRAM_COUNT := 64
const RING_RADIUS_RATIO := 0.438

var elapsed: float = 0.0
var active: bool = false
var selected_value: int = 63
var target_rotation: float = 0.0


func reset() -> void:
	elapsed = 0.0
	active = false
	selected_value = 63
	target_rotation = 0.0
	pass


func begin(forced_value: int = -1) -> void:
	elapsed = 0.0
	active = true
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	selected_value = clampi(forced_value, 0, 63) if forced_value >= 0 else rng.randi_range(0, 63)
	var selected_position := fuxi_circle_position(selected_value)
	var landing_offset := float(selected_position) / float(HEXAGRAM_COUNT) * TAU
	target_rotation = TAU * float(rng.randi_range(5, 7)) + landing_offset
	pass


func advance(delta: float) -> bool:
	if not active or elapsed >= TOTAL_SECONDS:
		return false
	elapsed = minf(TOTAL_SECONDS, elapsed + delta)
	return true


func prompt_progress() -> float:
	return smoothstep(0.0, 1.0, clampf(elapsed / 0.8, 0.0, 1.0)) \
		* (1.0 - smoothstep(PROMPT_SECONDS - 0.7, PROMPT_SECONDS, elapsed))


func spin_progress() -> float:
	return clampf((elapsed - PROMPT_SECONDS) / SPIN_SECONDS, 0.0, 1.0)


func flight_progress() -> float:
	return smoothstep(0.0, 1.0, clampf((elapsed - PROMPT_SECONDS - SPIN_SECONDS) / FLY_SECONDS, 0.0, 1.0))


func result_progress() -> float:
	return smoothstep(0.0, 1.0, clampf(
		(elapsed - PROMPT_SECONDS - SPIN_SECONDS - FLY_SECONDS) / RESULT_REVEAL_SECONDS, 0.0, 1.0))


func animation_finished() -> bool:
	return elapsed >= TOTAL_SECONDS


func pointer_rotation() -> float:
	var t := spin_progress()
	# Cubic ease-out is strictly monotonic: the needle only moves forward and
	# continuously loses speed until it reaches the selected hexagram.
	var deceleration := 1.0 - pow(1.0 - t, 3.0)
	return target_rotation * deceleration


func highlighted_position() -> int:
	var step := TAU / float(HEXAGRAM_COUNT)
	return posmod(int(round(pointer_rotation() / step)), HEXAGRAM_COUNT)


func highlighted_value() -> int:
	return value_from_fuxi_position(highlighted_position())


func fuxi_circle_position(value: int) -> int:
	return 63 - value if value >= 32 else 32 + value


func value_from_fuxi_position(position: int) -> int:
	return 63 - position if position < 32 else position - 32


func draw(canvas: Control) -> void:
	if not active:
		return
	var center := canvas.size * 0.5
	var short_side := minf(canvas.size.x, canvas.size.y)
	draw_wheel(canvas, center, short_side)
	draw_needle(canvas, center, short_side)
	if elapsed < PROMPT_SECONDS:
		draw_prompt(canvas, center)
	elif elapsed < PROMPT_SECONDS + SPIN_SECONDS:
		draw_spinning_label(canvas, center)
	else:
		draw_selected_hexagram(canvas, center, short_side)
	if result_progress() > 0.0:
		draw_result(canvas, center)
	pass


func draw_wheel(canvas: Control, center: Vector2, short_side: float) -> void:
	var radius := short_side * RING_RADIUS_RATIO
	var width := clampf(short_side * 0.027, 18.0, 32.0)
	var line_gap := clampf(short_side * 0.0048, 3.5, 5.5)
	var flight := flight_progress()
	var current_highlight := highlighted_position()
	var selected_position := fuxi_circle_position(selected_value)
	canvas.draw_arc(center, radius * 0.985, 0.0, TAU, 192,
		TaiChiGlowDrawing.outer_ring_color(0.14), 1.2, true)
	canvas.draw_arc(center, radius * 1.04, 0.0, TAU, 192,
		TaiChiGlowDrawing.outer_ring_color(0.08), 1.0, true)
	for position in HEXAGRAM_COUNT:
		if flight > 0.0 and position == selected_position:
			continue
		var angle := -PI * 0.5 + TAU * float(position) / float(HEXAGRAM_COUNT)
		var point := center + Vector2.from_angle(angle) * radius
		var highlighted := elapsed >= PROMPT_SECONDS and elapsed < PROMPT_SECONDS + SPIN_SECONDS \
			and position == current_highlight
		var alpha := (TaiChiTrigramDrawing.HIGHLIGHT_ALPHA if highlighted \
			else TaiChiTrigramDrawing.BASE_ALPHA) * lerpf(1.0, 0.2, flight)
		var scale := 1.18 if highlighted else 1.0
		var value := value_from_fuxi_position(position)
		TaiChiTrigramDrawing.draw_symbol(canvas, point, value, 6, width * scale, line_gap * scale,
			2.2 if highlighted else 2.0, alpha, angle + PI * 0.5)
	pass


func draw_needle(canvas: Control, center: Vector2, short_side: float) -> void:
	var appear := smoothstep(PROMPT_SECONDS - 0.2, PROMPT_SECONDS + 0.3, elapsed)
	var disappear := 1.0 - smoothstep(PROMPT_SECONDS + SPIN_SECONDS,
		PROMPT_SECONDS + SPIN_SECONDS + FLY_SECONDS * 0.45, elapsed)
	var alpha := appear * disappear * 0.82
	if alpha <= 0.0:
		return
	var radius := short_side * RING_RADIUS_RATIO
	var angle := -PI * 0.5 + pointer_rotation()
	var direction := Vector2.from_angle(angle)
	var normal := direction.rotated(PI * 0.5)
	var hub_radius := clampf(short_side * 0.005, 4.0, 6.0)
	var tip := center + direction * radius * 0.8
	var needle_start := center + direction * hub_radius
	var arrow_length := clampf(short_side * 0.009, 7.0, 11.0)
	var arrow_half_width := clampf(short_side * 0.004, 3.0, 5.0)
	var needle_end := tip - direction * arrow_length * 0.72
	TaiChiGlowDrawing.draw_tapered_line(canvas, needle_start, needle_end, 2.0, 1.0, alpha)
	TaiChiGlowDrawing.draw_line(canvas, tip, tip - direction * arrow_length + normal * arrow_half_width,
		1.1, alpha)
	TaiChiGlowDrawing.draw_line(canvas, tip, tip - direction * arrow_length - normal * arrow_half_width,
		1.1, alpha)
	TaiChiGlowDrawing.draw_circle(canvas, center, hub_radius, 1.3, alpha * 0.88)
	pass


func draw_prompt(canvas: Control, center: Vector2) -> void:
	var alpha := prompt_progress()
	draw_centered_text(canvas, "八卦定运势，运势生大业。", center - Vector2(0.0, canvas.size.y * 0.025),
		clampi(int(canvas.size.y * 0.05), 34, 56), alpha * 0.88)
	draw_centered_text(canvas,
		"The eight trigrams determine good fortune and misfortune. Good fortune and misfortune create the great field of action.",
		center + Vector2(0.0, canvas.size.y * 0.055), clampi(int(canvas.size.y * 0.016), 11, 17), alpha * 0.52)
	pass


func draw_spinning_label(canvas: Control, center: Vector2) -> void:
	var entry: Dictionary = TaiChiHexagramCatalog.entry_from_value(highlighted_value())
	var alpha := 0.35 + 0.4 * (1.0 - spin_progress())
	draw_centered_text(canvas, "问卦", center - Vector2(0.0, canvas.size.y * 0.025),
		clampi(int(canvas.size.y * 0.064), 42, 70), alpha)
	draw_centered_text(canvas, "第 %d 卦 · %s" % [entry.number, entry.full_name],
		center + Vector2(0.0, canvas.size.y * 0.06), clampi(int(canvas.size.y * 0.02), 14, 22), alpha * 0.7)
	pass


func draw_selected_hexagram(canvas: Control, center: Vector2, short_side: float) -> void:
	var flight := flight_progress()
	var radius := short_side * RING_RADIUS_RATIO
	var selected_angle := -PI * 0.5 + TAU * float(fuxi_circle_position(selected_value)) / float(HEXAGRAM_COUNT)
	var source := center + Vector2.from_angle(selected_angle) * radius
	var target := center - Vector2(0.0, canvas.size.y * 0.17)
	var arc := Vector2(sin(flight * PI) * minf(110.0, canvas.size.x * 0.06), 0.0)
	var position := source.lerp(target, ease(flight, -1.5)) + arc
	var width := lerpf(clampf(short_side * 0.027, 18.0, 32.0), minf(150.0, canvas.size.y * 0.16), flight)
	var line_gap := lerpf(clampf(short_side * 0.0048, 3.5, 5.5), minf(19.0, canvas.size.y * 0.021), flight)
	var line_width := lerpf(2.1, 5.0, flight)
	TaiChiTrigramDrawing.draw_symbol(canvas, position, selected_value, 6, width, line_gap, line_width,
		lerpf(0.9, 0.74, flight))
	pass


func draw_result(canvas: Control, center: Vector2) -> void:
	var alpha := result_progress()
	var entry: Dictionary = TaiChiHexagramCatalog.entry_from_value(selected_value)
	var title_y := center.y - canvas.size.y * 0.035
	draw_centered_text(canvas, "%s  第 %d 卦 · %s" % [entry.symbol, entry.number, entry.full_name],
		Vector2(center.x, title_y), clampi(int(canvas.size.y * 0.038), 25, 42), alpha * 0.9)
	draw_centered_text(canvas, str(entry.theme), Vector2(center.x, title_y + canvas.size.y * 0.06),
		clampi(int(canvas.size.y * 0.025), 18, 28), alpha * 0.82)
	draw_wrapped_text(canvas, str(entry.interpretation), Vector2(center.x, title_y + canvas.size.y * 0.115),
		clampi(int(canvas.size.y * 0.018), 13, 19), alpha * 0.68, canvas.size.x * 0.56)
	draw_centered_text(canvas, "宜：%s    忌：%s" % [entry.advice, entry.avoid],
		Vector2(center.x, title_y + canvas.size.y * 0.19), clampi(int(canvas.size.y * 0.017), 12, 18), alpha * 0.62)
	draw_centered_text(canvas, "原典 · 上%s%s，下%s%s" % [entry.upper_name, entry.upper_element,
		entry.lower_name, entry.lower_element], Vector2(center.x, title_y + canvas.size.y * 0.255),
		clampi(int(canvas.size.y * 0.016), 12, 17), alpha * 0.48)
	draw_wrapped_text(canvas, "卦辞：" + str(entry.judgment), Vector2(center.x, title_y + canvas.size.y * 0.3),
		clampi(int(canvas.size.y * 0.015), 11, 16), alpha * 0.45, canvas.size.x * 0.52)
	draw_wrapped_text(canvas, "象曰：" + str(entry.image), Vector2(center.x, title_y + canvas.size.y * 0.35),
		clampi(int(canvas.size.y * 0.015), 11, 16), alpha * 0.42, canvas.size.x * 0.52)
	pass


func draw_wrapped_text(canvas: Control, text: String, position: Vector2, font_size: int,
		alpha: float, max_width: float) -> void:
	var font := Fonts.light()
	var lines: Array[String] = []
	var current := ""
	for index in text.length():
		var candidate := current + text.substr(index, 1)
		if not current.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
			lines.append(current)
			current = text.substr(index, 1)
		else:
			current = candidate
	if not current.is_empty():
		lines.append(current)
	var line_height := float(font_size) * 1.55
	for index in lines.size():
		draw_centered_text(canvas, lines[index], position + Vector2(0.0, float(index) * line_height), font_size, alpha)
	pass


func draw_centered_text(canvas: Control, text: String, position: Vector2, font_size: int, alpha: float) -> void:
	if alpha <= 0.0:
		return
	TaiChiGlowDrawing.draw_centered_text(canvas, Fonts.light(), text, position, font_size, alpha)
	pass
