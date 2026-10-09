class_name TaiChiDualityFlow
extends RefCounted

## Splits the opening stroke into the unbroken yang line and broken yin line.

const TRANSITION_SECONDS := 2.2
const BOTTOM_TITLE := "一阴一阳之谓道"

var elapsed: float = 0.0
var active: bool = false


func reset() -> void:
	elapsed = 0.0
	active = false
	pass


func begin() -> void:
	active = true
	elapsed = 0.0
	pass


func advance(delta: float) -> bool:
	if not active or elapsed >= TRANSITION_SECONDS:
		return false
	elapsed = minf(TRANSITION_SECONDS, elapsed + delta)
	return true


func progress() -> float:
	return smoothstep(0.0, 1.0, clampf(elapsed / TRANSITION_SECONDS, 0.0, 1.0))


func title_opacity() -> float:
	return 1.0 - smoothstep(0.0, 0.42, progress())


func draw(canvas: Control, center: Vector2, available_width: float, opacity: float = 1.0) -> void:
	if not active:
		return
	var reveal := progress()
	var half_width := minf(available_width * 0.38, 620.0)
	var origin_y := center.y + minf(132.0, canvas.size.y * 0.17)
	var row_gap := minf(105.0, canvas.size.y * 0.14)
	var yang_y := lerpf(origin_y, center.y - row_gap * 0.5, reveal)
	var yin_y := lerpf(origin_y, center.y + row_gap * 0.5, reveal)
	var line_color := Color(ColorBase.primary_text, 0.62 * opacity)
	canvas.draw_line(Vector2(center.x - half_width, yang_y), Vector2(center.x + half_width, yang_y), line_color, 2.0, true)
	var gap_half := half_width * 0.13 * ease(reveal, -1.5)
	canvas.draw_line(Vector2(center.x - half_width, yin_y), Vector2(center.x - gap_half, yin_y), line_color, 2.0, true)
	canvas.draw_line(Vector2(center.x + gap_half, yin_y), Vector2(center.x + half_width, yin_y), line_color, 2.0, true)
	draw_labels(canvas, center, half_width, yang_y, yin_y, reveal, opacity)
	draw_bottom_title(canvas, center, row_gap, reveal, opacity)
	pass


func draw_labels(canvas: Control, center: Vector2, half_width: float, yang_y: float, yin_y: float, reveal: float, opacity: float = 1.0) -> void:
	var label_alpha := smoothstep(0.48, 0.9, reveal) * opacity
	if label_alpha <= 0.0:
		return
	var chinese_font := Fonts.light()
	var latin_font := Fonts.medium()
	var chinese_size := clampi(int(canvas.size.y * 0.065), 32, 62)
	var latin_size := clampi(int(canvas.size.y * 0.025), 14, 24)
	var left_x := center.x - half_width - minf(105.0, canvas.size.x * 0.07)
	var right_x := center.x + half_width + minf(92.0, canvas.size.x * 0.06)
	draw_centered_label(canvas, chinese_font, "阳", Vector2(left_x, yang_y), chinese_size, label_alpha)
	draw_centered_label(canvas, chinese_font, "阴", Vector2(left_x, yin_y), chinese_size, label_alpha)
	draw_centered_label(canvas, latin_font, "Y A N G", Vector2(right_x, yang_y), latin_size, label_alpha * 0.72)
	draw_centered_label(canvas, latin_font, "Y I N", Vector2(right_x, yin_y), latin_size, label_alpha * 0.72)
	pass


func draw_centered_label(canvas: Control, font: Font, text: String, position: Vector2, font_size: int, alpha: float) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := position + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 4, ThemeColor.alpha_theme_color(alpha * 0.1))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(ColorBase.secondary_text, alpha * 0.72))
	pass


func draw_bottom_title(canvas: Control, center: Vector2, row_gap: float, reveal: float, opacity: float = 1.0) -> void:
	var font := Fonts.light()
	var font_size := clampi(int(canvas.size.y * 0.058), 30, 56)
	var glyph_width := font.get_string_size("道", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var final_gap := maxf(glyph_width * 1.08, 38.0)
	var title_y := center.y + row_gap * 1.72
	var middle := (float(BOTTOM_TITLE.length()) - 1.0) * 0.5
	for index in BOTTOM_TITLE.length():
		var outward_index := absf(float(index) - middle) / middle
		var local_progress := smoothstep(outward_index * 0.2, 0.72 + outward_index * 0.2, reveal)
		if local_progress <= 0.0:
			continue
		var final_x := (float(index) - middle) * final_gap
		var glyph_position := Vector2(center.x + final_x * ease(local_progress, -1.5), title_y)
		var glyph := BOTTOM_TITLE.substr(index, 1)
		var glyph_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := glyph_position + Vector2(-glyph_size.x * 0.5, glyph_size.y * 0.34)
		canvas.draw_string_outline(font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 5, ThemeColor.alpha_theme_color(local_progress * opacity * 0.1))
		canvas.draw_string(font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(ColorBase.primary_text, local_progress * opacity * 0.72))
	pass
