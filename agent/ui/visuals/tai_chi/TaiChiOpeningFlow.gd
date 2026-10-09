class_name TaiChiOpeningFlow
extends RefCounted

## Opens from absolute stillness: the horizon grows first, then the four glyphs
## travel outwards from the same center point.

const REVEAL_SECONDS := 2.25
const TITLE := "一画开天"

var elapsed: float = 0.0


func reset() -> void:
	elapsed = 0.0
	pass


func advance(delta: float) -> bool:
	var previous := elapsed
	elapsed = minf(elapsed + delta, REVEAL_SECONDS)
	return previous != elapsed


func line_progress() -> float:
	return ease(clampf(elapsed / REVEAL_SECONDS, 0.0, 1.0), -1.8)


func title_progress() -> float:
	return ease(clampf(elapsed / REVEAL_SECONDS, 0.0, 1.0), -1.8)


func draw(canvas: Control, center: Vector2, available_width: float) -> void:
	var line_y := center.y + minf(132.0, canvas.size.y * 0.17)
	var half_width := minf(available_width * 0.38, 620.0) * line_progress()
	if half_width > 0.5:
		draw_horizon_line(canvas, Vector2(center.x - half_width, line_y), Vector2(center.x + half_width, line_y))
	draw_title(canvas, Vector2(center.x, line_y - minf(170.0, canvas.size.y * 0.22)))
	pass


func draw_horizon_line(canvas: Control, start: Vector2, finish: Vector2) -> void:
	TaiChiGlowDrawing.draw_line(canvas, start, finish, 2.0, 0.62)
	pass


func draw_title(canvas: Control, center: Vector2, opacity: float = 1.0) -> void:
	var progress := title_progress()
	if progress <= 0.0:
		return
	var font := Fonts.light()
	var font_size := clampi(int(canvas.size.y * 0.12), 48, 116)
	var glyph_width := font.get_string_size("天", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var final_gap := maxf(glyph_width * 1.44, 92.0)
	for index in TITLE.length():
		var outward_index := absf(float(index) - 1.5) / 1.5
		var local_progress := smoothstep(outward_index * 0.22, 0.72 + outward_index * 0.18, progress)
		if local_progress <= 0.0:
			continue
		var final_x := (float(index) - 1.5) * final_gap
		var glyph_position := center + Vector2(final_x * ease(local_progress, -1.5), 0.0)
		var glyph := TITLE.substr(index, 1)
		var glyph_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := glyph_position + Vector2(-glyph_size.x * 0.5, glyph_size.y * 0.35)
		var alpha := local_progress * (0.82 + 0.18 * progress) * opacity
		TaiChiGlowDrawing.draw_text(canvas, font, baseline, glyph, font_size, alpha * 0.72)
	pass
