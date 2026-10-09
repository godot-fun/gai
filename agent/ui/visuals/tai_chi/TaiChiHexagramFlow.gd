class_name TaiChiHexagramFlow
extends RefCounted

## Resolves the eight-trigram carousel into sixty-four hexagrams. The existing
## ticks become destinations: eight upper-trigram sectors, each paired with all
## eight lower trigrams, bloom clockwise into a quiet final panorama.

const TRANSITION_SECONDS := 10.8
const SETTLE_END := 0.12
const SPLIT_START := 0.08
const SPLIT_END := 0.3
const GENERATION_START := 0.24
const GENERATION_END := 0.82
const FINAL_TITLE_START := 0.78
const HEXAGRAM_COUNT := 64

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
	return smoothstep(0.0, 1.0, clampf(elapsed / TRANSITION_SECONDS, 0.0, 1.0))


func split_progress() -> float:
	return smoothstep(SPLIT_START, SPLIT_END, progress())


func panorama_progress() -> float:
	return smoothstep(FINAL_TITLE_START, 1.0, progress())


func ring_rotation() -> float:
	var settle := smoothstep(0.0, SETTLE_END, progress())
	return lerpf(source_rotation, 0.0, ease(settle, -1.4))


func hexagram_value(upper_index: int, lower_index: int) -> int:
	var upper: int = TaiChiEvolutionFlow.TRIGRAM_VALUES[upper_index]
	var lower: int = TaiChiEvolutionFlow.TRIGRAM_VALUES[lower_index]
	# TaiChiTrigramDrawing renders bit zero as the top line.
	return upper | (lower << 3)


func hexagram_progress(index: int) -> float:
	var sequence := float(index) / float(HEXAGRAM_COUNT - 1)
	var start := lerpf(GENERATION_START, GENERATION_END - 0.1, sequence)
	return smoothstep(start, minf(start + 0.1, GENERATION_END), progress())


func draw(canvas: Control, bagua: TaiChiBaguaFlow) -> void:
	if not active:
		return
	var center := canvas.size * 0.5
	var short_side := minf(canvas.size.x, canvas.size.y)
	var orbit_radius := short_side * 0.34
	draw_frame(canvas, center, orbit_radius)
	draw_trigram_layers(canvas, bagua, center, short_side)
	draw_hexagrams(canvas, center, short_side)
	draw_caption(canvas, center)
	pass


func draw_frame(canvas: Control, center: Vector2, orbit_radius: float) -> void:
	var fade := 1.0 - smoothstep(GENERATION_START, GENERATION_END, progress()) * 0.45
	var rotation := ring_rotation()
	canvas.draw_arc(center, orbit_radius * 1.27, rotation, rotation + TAU, 160,
		ThemeColor.alpha_theme_color(0.16 * fade), 1.4, true)
	canvas.draw_arc(center, orbit_radius * 1.31, -rotation, -rotation + TAU, 160,
		ThemeColor.alpha_theme_color(0.09 * fade), 1.0, true)
	canvas.draw_arc(center, orbit_radius * 0.63, -rotation, -rotation + TAU, 120,
		ThemeColor.alpha_theme_color(0.12 * fade), 1.2, true)
	for tick in HEXAGRAM_COUNT:
		var angle := rotation + TAU * float(tick) / float(HEXAGRAM_COUNT)
		var length := 11.0 if tick % 8 == 0 else 5.0
		var outer := center + Vector2.from_angle(angle) * orbit_radius * 1.29
		var inner := center + Vector2.from_angle(angle) * (orbit_radius * 1.29 - length)
		canvas.draw_line(inner, outer, ThemeColor.alpha_theme_color(0.2 * fade), 1.2, true)
	pass


func draw_trigram_layers(canvas: Control, bagua: TaiChiBaguaFlow, center: Vector2, short_side: float) -> void:
	var split := split_progress()
	var generated := smoothstep(GENERATION_START, GENERATION_END, progress())
	var source_radius := short_side * 0.34
	var upper_radius := lerpf(source_radius, short_side * 0.29, split)
	var lower_radius := lerpf(source_radius, short_side * 0.215, split)
	var copy_alpha := split * (1.0 - generated)
	for index in 8:
		var angle: float = TaiChiBaguaFlow.TARGET_ANGLES[index]
		var rotation := angle + PI * 0.5
		var upper_position := center + Vector2.from_angle(angle) * upper_radius
		bagua.draw_trigram(canvas, upper_position, rotation, TaiChiEvolutionFlow.TRIGRAM_VALUES[index],
			minf(70.0, canvas.size.y * 0.078), 11.0, 4.0, lerpf(0.58, 0.4, generated))
		if copy_alpha > 0.0:
			var lower_position := center + Vector2.from_angle(angle) * lower_radius
			bagua.draw_trigram(canvas, lower_position, rotation, TaiChiEvolutionFlow.TRIGRAM_VALUES[index],
				minf(56.0, canvas.size.y * 0.062), 9.0, 3.5, copy_alpha * 0.42)
		var label_position := center + Vector2.from_angle(angle) * (upper_radius + minf(58.0, canvas.size.y * 0.065))
		draw_centered_text(canvas, TaiChiEvolutionFlow.TRIGRAM_NAMES[index], label_position,
			clampi(int(canvas.size.y * 0.026), 17, 27), lerpf(0.62, 0.44, generated))
	pass


func draw_hexagrams(canvas: Control, center: Vector2, short_side: float) -> void:
	var radius := short_side * 0.438
	var width := clampf(short_side * 0.027, 18.0, 32.0)
	var line_gap := clampf(short_side * 0.0048, 3.5, 5.5)
	for index in HEXAGRAM_COUNT:
		var reveal := hexagram_progress(index)
		if reveal <= 0.0:
			continue
		var upper_index := index / 8
		var lower_index := index % 8
		var angle := -PI * 0.5 + TAU * float(index) / float(HEXAGRAM_COUNT)
		var current_radius := lerpf(short_side * 0.29, radius, ease(reveal, -1.5))
		var position := center + Vector2.from_angle(angle) * current_radius
		var pulse := sin(reveal * PI)
		TaiChiTrigramDrawing.draw_symbol(canvas, position, hexagram_value(upper_index, lower_index), 6,
			width * lerpf(0.68, 1.0, reveal), line_gap, 2.1, reveal * 0.52,
			angle + PI * 0.5, pulse * 0.08)
	pass


func draw_caption(canvas: Control, center: Vector2) -> void:
	var split := split_progress()
	var panorama := panorama_progress()
	var explanation_alpha := split * (1.0 - smoothstep(0.4, 0.68, progress()))
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
