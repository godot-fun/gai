class_name TaiChiHexagramFlow
extends RefCounted

## Combines two trigram rings over eight rounds. The outer ring remains fixed;
## the inner ring rotates one position after each round. Eight sector frames show
## the current pairings, then the eight resulting hexagrams fly to their slots.

const SETTLE_SECONDS := 1.0
const SPLIT_SECONDS := 1.0
const ROUND_SECONDS := 1.0
const ROUND_COUNT := 8
const FINAL_SECONDS := 0.8
const TRANSITION_SECONDS := SETTLE_SECONDS + SPLIT_SECONDS + ROUND_SECONDS * ROUND_COUNT + FINAL_SECONDS
const ROUND_START_SECONDS := SETTLE_SECONDS + SPLIT_SECONDS
const FINAL_START_SECONDS := ROUND_START_SECONDS + ROUND_SECONDS * ROUND_COUNT
const PAIR_END := 0.24
const FLIGHT_START := 0.18
const FLIGHT_END := 0.68
const ROTATION_START := 0.72
const HEXAGRAM_COUNT := 64
const ORBIT_RADIUS_RATIO := 0.34
const INNER_FRAME_RADIUS_RATIO := ORBIT_RADIUS_RATIO * 0.63
const COMPASS_ORDER := [0, 4, 5, 6, 7, 3, 2, 1]

var elapsed: float = 0.0
var active: bool = false
var source_rotation: float = 0.0


func reset() -> void:
	elapsed = 0.0
	active = false
	source_rotation = 0.0
	pass


func begin(rotation: float = 0.0) -> void:
	elapsed = 0.0
	active = true
	source_rotation = rotation
	pass


func advance(delta: float) -> bool:
	if not active or elapsed >= TRANSITION_SECONDS:
		return false
	elapsed = minf(TRANSITION_SECONDS, elapsed + delta)
	return true


func progress() -> float:
	return clampf(elapsed / TRANSITION_SECONDS, 0.0, 1.0)


func split_progress() -> float:
	return smoothstep(0.0, 1.0, clampf((elapsed - SETTLE_SECONDS) / SPLIT_SECONDS, 0.0, 1.0))


func panorama_progress() -> float:
	return smoothstep(0.0, 1.0, clampf((elapsed - FINAL_START_SECONDS) / FINAL_SECONDS, 0.0, 1.0))


func ring_rotation() -> float:
	var settle := smoothstep(0.0, 1.0, clampf(elapsed / SETTLE_SECONDS, 0.0, 1.0))
	return lerpf(source_rotation, 0.0, ease(settle, -1.4))


func active_round() -> int:
	return clampi(int(floor(maxf(0.0, elapsed - ROUND_START_SECONDS) / ROUND_SECONDS)), 0, ROUND_COUNT - 1)


func round_phase() -> float:
	if elapsed < ROUND_START_SECONDS:
		return 0.0
	if elapsed >= FINAL_START_SECONDS:
		return 1.0
	return fmod(elapsed - ROUND_START_SECONDS, ROUND_SECONDS) / ROUND_SECONDS


func completed_rounds() -> int:
	return clampi(int(floor(maxf(0.0, elapsed - ROUND_START_SECONDS) / ROUND_SECONDS)), 0, ROUND_COUNT)


func inner_rotation_steps() -> float:
	var completed := float(completed_rounds())
	if completed >= float(ROUND_COUNT) or elapsed < ROUND_START_SECONDS:
		return completed
	var turn := smoothstep(ROTATION_START, 1.0, round_phase())
	return completed + turn


func lower_index_for_slot(slot: int, round_index: int) -> int:
	return COMPASS_ORDER[posmod(slot - round_index, ROUND_COUNT)]


func hexagram_value(upper_index: int, lower_index: int) -> int:
	var upper: int = TaiChiEvolutionFlow.TRIGRAM_VALUES[upper_index]
	var lower: int = TaiChiEvolutionFlow.TRIGRAM_VALUES[lower_index]
	# TaiChiTrigramDrawing renders bit zero as the top line.
	return upper | (lower << 3)


func hexagram_progress(index: int) -> float:
	var round_index := index % ROUND_COUNT
	if round_index < completed_rounds():
		return 1.0
	if round_index > active_round() or elapsed < ROUND_START_SECONDS:
		return 0.0
	return smoothstep(FLIGHT_START, FLIGHT_END, round_phase())


func draw(canvas: Control, bagua: TaiChiBaguaFlow) -> void:
	if not active:
		return
	var center := canvas.size * 0.5
	var short_side := minf(canvas.size.x, canvas.size.y)
	draw_frame(canvas, center, short_side * ORBIT_RADIUS_RATIO)
	draw_sector_frames(canvas, center, short_side)
	draw_trigram_layers(canvas, bagua, center, short_side)
	draw_hexagrams(canvas, center, short_side)
	draw_caption(canvas, center)
	pass


func draw_frame(canvas: Control, center: Vector2, orbit_radius: float) -> void:
	var final_fade := 1.0 - panorama_progress() * 0.45
	var rotation := ring_rotation()
	canvas.draw_arc(center, orbit_radius * 1.27, rotation, rotation + TAU, 160,
		ThemeColor.alpha_theme_color(0.16 * final_fade), 1.4, true)
	canvas.draw_arc(center, orbit_radius * 1.31, -rotation, -rotation + TAU, 160,
		ThemeColor.alpha_theme_color(0.09 * final_fade), 1.0, true)
	canvas.draw_arc(center, orbit_radius * 0.63, -rotation, -rotation + TAU, 120,
		ThemeColor.alpha_theme_color(0.12 * final_fade), 1.2, true)
	pass


func draw_sector_frames(canvas: Control, center: Vector2, short_side: float) -> void:
	if elapsed < ROUND_START_SECONDS or elapsed >= FINAL_START_SECONDS:
		return
	var phase := round_phase()
	var appear := smoothstep(0.0, PAIR_END, phase)
	var disappear := 1.0 - smoothstep(FLIGHT_END, ROTATION_START, phase)
	var alpha := appear * disappear * 0.2
	var inner_radius := short_side * INNER_FRAME_RADIUS_RATIO
	var outer_radius := short_side * 0.305
	var half_angle := TAU / 19.0
	for slot in ROUND_COUNT:
		var angle := slot_angle(slot)
		var left_angle := angle - half_angle
		var right_angle := angle + half_angle
		canvas.draw_line(center + Vector2.from_angle(left_angle) * inner_radius,
			center + Vector2.from_angle(left_angle) * outer_radius, ThemeColor.alpha_theme_color(alpha), 1.2, true)
		canvas.draw_line(center + Vector2.from_angle(right_angle) * inner_radius,
			center + Vector2.from_angle(right_angle) * outer_radius, ThemeColor.alpha_theme_color(alpha), 1.2, true)
		canvas.draw_arc(center, inner_radius, left_angle, right_angle, 12,
			ThemeColor.alpha_theme_color(alpha * 0.7), 1.0, true)
		canvas.draw_arc(center, outer_radius, left_angle, right_angle, 12,
			ThemeColor.alpha_theme_color(alpha), 1.2, true)
	pass


func draw_trigram_layers(canvas: Control, bagua: TaiChiBaguaFlow, center: Vector2, short_side: float) -> void:
	var split := split_progress()
	var final_fade := 1.0 - panorama_progress()
	var source_radius := short_side * 0.34
	var outer_radius := lerpf(source_radius, short_side * 0.275, split)
	var inner_radius := lerpf(source_radius, short_side * 0.225, split)
	for slot in ROUND_COUNT:
		var angle := slot_angle(slot)
		var upper_index: int = COMPASS_ORDER[slot]
		var outer_position := center + Vector2.from_angle(angle) * outer_radius
		bagua.draw_trigram(canvas, outer_position, angle + PI * 0.5,
			TaiChiEvolutionFlow.TRIGRAM_VALUES[upper_index], minf(70.0, canvas.size.y * 0.078),
			11.0, 4.0, final_fade * 0.52)
		var label_position := center + Vector2.from_angle(angle) * (outer_radius + minf(58.0, canvas.size.y * 0.065))
		draw_centered_text(canvas, TaiChiEvolutionFlow.TRIGRAM_NAMES[upper_index], label_position,
			clampi(int(canvas.size.y * 0.026), 17, 27), final_fade * 0.54)
	if split <= 0.0:
		return
	var steps := inner_rotation_steps()
	for source_slot in ROUND_COUNT:
		var angle := slot_angle_float(float(source_slot) + steps)
		var lower_index: int = COMPASS_ORDER[source_slot]
		var inner_position := center + Vector2.from_angle(angle) * inner_radius
		bagua.draw_trigram(canvas, inner_position, angle + PI * 0.5,
			TaiChiEvolutionFlow.TRIGRAM_VALUES[lower_index], minf(56.0, canvas.size.y * 0.062),
			9.0, 3.5, split * final_fade * 0.46)
	pass


func draw_hexagrams(canvas: Control, center: Vector2, short_side: float) -> void:
	for slot in ROUND_COUNT:
		for round_index in ROUND_COUNT:
			var index := slot * ROUND_COUNT + round_index
			var reveal := hexagram_progress(index)
			if reveal <= 0.0:
				continue
			draw_hexagram(canvas, center, short_side, slot, round_index, reveal)
	pass


func draw_hexagram(canvas: Control, center: Vector2, short_side: float, slot: int,
		round_index: int, reveal: float) -> void:
	var target_radius := short_side * 0.438
	var width := clampf(short_side * 0.027, 18.0, 32.0)
	var line_gap := clampf(short_side * 0.0048, 3.5, 5.5)
	var source_angle := slot_angle(slot)
	var target_angle := source_angle + (float(round_index) - 3.5) * TAU / float(HEXAGRAM_COUNT)
	var flight := ease(reveal, -1.5)
	var angle := lerp_angle(source_angle, target_angle, flight)
	var radius := lerpf(short_side * 0.25, target_radius, flight)
	var position := center + Vector2.from_angle(angle) * radius
	var upper_index: int = COMPASS_ORDER[slot]
	var lower_index := lower_index_for_slot(slot, round_index)
	var pulse := sin(reveal * PI)
	TaiChiTrigramDrawing.draw_symbol(canvas, position, hexagram_value(upper_index, lower_index), 6,
		width * lerpf(0.72, 1.0, reveal), line_gap, 2.1, reveal * 0.52,
		target_angle + PI * 0.5, pulse * 0.08)
	pass


func slot_angle(slot: int) -> float:
	return slot_angle_float(float(slot))


func slot_angle_float(slot: float) -> float:
	return -PI * 0.5 + TAU * slot / float(ROUND_COUNT)


func draw_caption(canvas: Control, center: Vector2) -> void:
	var split := split_progress()
	var panorama := panorama_progress()
	var explanation_alpha := split * (1.0 - panorama)
	if explanation_alpha > 0.0:
		draw_centered_text(canvas, "八卦相荡", center - Vector2(0.0, canvas.size.y * 0.025),
			clampi(int(canvas.size.y * 0.06), 38, 64), explanation_alpha * 0.82)
		draw_centered_text(canvas, "八上卦 × 八下卦", center + Vector2(0.0, canvas.size.y * 0.055),
			clampi(int(canvas.size.y * 0.022), 15, 23), explanation_alpha * 0.55)
	if panorama > 0.0:
		draw_centered_text(canvas, "六十四卦", center - Vector2(0.0, canvas.size.y * 0.025),
			clampi(int(canvas.size.y * 0.064), 42, 70), panorama * 0.88)
		draw_centered_text(canvas, "变动不居，周流六虚", center + Vector2(0.0, canvas.size.y * 0.058),
			clampi(int(canvas.size.y * 0.023), 16, 25), panorama * 0.58)
		draw_centered_text(canvas, "（变化之象，周流不息）", center + Vector2(0.0, canvas.size.y * 0.092),
			clampi(int(canvas.size.y * 0.016), 12, 17), panorama * 0.4)
	pass


func draw_centered_text(canvas: Control, text: String, position: Vector2, font_size: int, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var font := Fonts.light()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := position + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 6,
		ThemeColor.alpha_theme_color(alpha * 0.07))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
		Color(ColorBase.primary_text, alpha))
	pass
