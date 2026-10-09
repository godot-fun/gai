class_name TaiChiEvolutionFlow
extends RefCounted

## Expands the completed taiji into five generations. Rows rise from the taiji,
## while every row reveals its symbols in reading order from left to right.

const TRANSITION_SECONDS := 14.4
const ROW_COUNT := 5
const YANG := 1
const YIN := 0
const TRIGRAM_VALUES := [7, 6, 5, 4, 3, 2, 1, 0]
const DEPARTING_TITLE := "易有太极，是生两仪"
const DEPARTING_SUBTITLE := "IN CHANGE THERE IS THE GREAT ULTIMATE"

var elapsed: float = 0.0
var active: bool = false


func reset() -> void:
	elapsed = 0.0
	active = false
	pass


func begin() -> void:
	elapsed = 0.0
	active = true
	pass


func advance(delta: float) -> bool:
	if not active or elapsed >= TRANSITION_SECONDS:
		return false
	elapsed = minf(TRANSITION_SECONDS, elapsed + delta)
	return true


func progress() -> float:
	return smoothstep(0.0, 1.0, clampf(elapsed / TRANSITION_SECONDS, 0.0, 1.0))


func row_progress(row_from_bottom: int) -> float:
	var start := 0.26 + float(row_from_bottom) * 0.15
	return smoothstep(start, minf(start + 0.18, 1.0), progress())


func shrink_progress() -> float:
	return smoothstep(0.0, 0.18, progress())


func move_progress() -> float:
	return smoothstep(0.18, 0.34, progress())


func symbol_radius(canvas_size: Vector2) -> float:
	var source_radius := minf(canvas_size.x, canvas_size.y) * 0.285
	var target_radius := clampf(minf(canvas_size.x, canvas_size.y) * 0.058, 28.0, 54.0)
	return lerpf(source_radius, target_radius, ease(shrink_progress(), -1.5))


func symbol_center(canvas_size: Vector2) -> Vector2:
	var source_y := canvas_size.y * 0.5 - minf(42.0, canvas_size.y * 0.055)
	var final_y := row_y(canvas_size, 0)
	var duality_center_x := content_area(canvas_size).get_center().x
	var source_x := canvas_size.x * 0.5
	return Vector2(
		lerpf(source_x, duality_center_x, ease(move_progress(), -1.5)),
		lerpf(source_y, final_y, ease(move_progress(), -1.5))
	)


func row_y(canvas_size: Vector2, row_from_bottom: int) -> float:
	var bottom := canvas_size.y * 0.84
	var top := canvas_size.y * 0.14
	return lerpf(bottom, top, float(row_from_bottom) / float(ROW_COUNT - 1))


func draw(canvas: Control, opacity: float = 1.0, draw_trigrams: bool = true) -> void:
	if not active:
		return
	draw_departing_caption(canvas)
	draw_taiji_row(canvas, row_progress(0) * opacity)
	draw_binary_row(canvas, "两仪", 2, row_y(canvas.size, 1), row_progress(1) * opacity)
	draw_binary_row(canvas, "四象", 4, row_y(canvas.size, 2), row_progress(2) * opacity)
	if draw_trigrams:
		draw_trigram_row(canvas, row_y(canvas.size, 3), row_progress(3) * opacity)
	draw_hexagram_row(canvas, row_y(canvas.size, 4), row_progress(4) * opacity)
	pass


func draw_departing_caption(canvas: Control) -> void:
	var shrink := shrink_progress()
	var opacity := 1.0 - smoothstep(0.58, 1.0, shrink)
	if opacity <= 0.0:
		return
	var source_radius := minf(canvas.size.x, canvas.size.y) * 0.285
	var symbol_origin := canvas.size * 0.5 - Vector2(0.0, minf(42.0, canvas.size.y * 0.055))
	var position := symbol_origin + Vector2(0.0, source_radius + minf(82.0, canvas.size.y * 0.11))
	var source_size := clampi(int(canvas.size.y * 0.046), 26, 46)
	var font_size := maxi(12, int(round(lerpf(float(source_size), 12.0, shrink))))
	var font := Fonts.light()
	var glyph_width := font.get_string_size("极", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var gap := maxf(8.0, glyph_width * 1.06)
	var middle := (float(DEPARTING_TITLE.length()) - 1.0) * 0.5
	for index in DEPARTING_TITLE.length():
		var glyph := DEPARTING_TITLE.substr(index, 1)
		var glyph_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := position + Vector2((float(index) - middle) * gap - glyph_size.x * 0.5, glyph_size.y * 0.34)
		canvas.draw_string_outline(font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 5,
			ThemeColor.alpha_theme_color(opacity * 0.1))
		canvas.draw_string(font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
			Color(ColorBase.primary_text, opacity * 0.72))
	var subtitle_font := Fonts.medium()
	var subtitle_size := maxi(8, int(round(lerpf(float(clampi(int(canvas.size.y * 0.014), 10, 15)), 8.0, shrink))))
	var subtitle_width := subtitle_font.get_string_size(DEPARTING_SUBTITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size).x
	canvas.draw_string(subtitle_font, position + Vector2(-subtitle_width * 0.5, float(font_size) * 1.25), DEPARTING_SUBTITLE,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, subtitle_size, Color(ColorBase.secondary_text, opacity * 0.58))
	pass


func draw_taiji_row(canvas: Control, reveal: float) -> void:
	if reveal <= 0.0:
		return
	draw_row_label(canvas, "太极", row_y(canvas.size, 0), reveal)
	pass


func draw_binary_row(canvas: Control, title: String, item_count: int, y: float, reveal: float) -> void:
	if reveal <= 0.0:
		return
	draw_row_label(canvas, title, y, reveal)
	var area := content_area(canvas.size)
	var gap := minf(18.0, area.size.x * 0.012)
	var cell_width := (area.size.x - gap * float(item_count - 1)) / float(item_count)
	var labels := PackedStringArray(["阳", "阴"]) if item_count == 2 else PackedStringArray(["太阳", "少阴", "少阳", "太阴"])
	for index in item_count:
		var local := item_progress(reveal, index, item_count)
		if local <= 0.0:
			continue
		var target_center := Vector2(area.position.x + float(index) * (cell_width + gap) + cell_width * 0.5, y)
		var center := flying_position(canvas.size, target_center, local, index, item_count)
		var scale := lerpf(0.42, 1.0, ease(local, -1.8))
		var rect_size := Vector2(cell_width, 44.0) * scale
		var rect := Rect2(center - rect_size * 0.5, rect_size)
		draw_flight_trail(canvas, center, local, index)
		draw_glowing_cell(canvas, rect, labels[index], index % 2 == 0, local)
	pass


func draw_trigram_row(canvas: Control, y: float, reveal: float) -> void:
	if reveal <= 0.0:
		return
	draw_row_label(canvas, "八卦", y, reveal)
	var names := PackedStringArray(["乾", "兑", "离", "震", "巽", "坎", "艮", "坤"])
	var area := content_area(canvas.size)
	var cell_width := area.size.x / 8.0
	for index in 8:
		var local := item_progress(reveal, index, 8)
		if local <= 0.0:
			continue
		var target_center := Vector2(area.position.x + (float(index) + 0.5) * cell_width, y)
		var center := flying_position(canvas.size, target_center, local, index, 8)
		var scale := lerpf(0.38, 1.0, ease(local, -1.8))
		draw_flight_trail(canvas, center, local, index)
		draw_line_symbol(canvas, center, TRIGRAM_VALUES[index], 3, minf(cell_width * 0.58, 54.0) * scale, local)
		draw_centered_text(canvas, names[index], center + Vector2(0.0, -34.0 * scale), maxi(10, int(round(18.0 * scale))), local * 0.76)
	pass


func draw_hexagram_row(canvas: Control, y: float, reveal: float) -> void:
	if reveal <= 0.0:
		return
	draw_row_label(canvas, "六十四卦", y, reveal)
	var area := content_area(canvas.size)
	var cell_width := area.size.x / 64.0
	for index in 64:
		var local := item_progress(reveal, index, 64)
		if local <= 0.0:
			continue
		var target_center := Vector2(area.position.x + (float(index) + 0.5) * cell_width, y)
		var center := flying_position(canvas.size, target_center, local, index, 64)
		var scale := lerpf(0.3, 1.0, ease(local, -1.8))
		draw_flight_trail(canvas, center, local, index)
		draw_line_symbol(canvas, center, index, 6, maxf(4.0, cell_width * 0.62) * scale, local)
	pass


func content_area(canvas_size: Vector2) -> Rect2:
	return Rect2(canvas_size.x * 0.2, 0.0, canvas_size.x * 0.72, canvas_size.y)


func item_progress(reveal: float, index: int, count: int) -> float:
	var start := float(index) / float(count) * 0.7
	return smoothstep(start, minf(start + 0.3, 1.0), reveal)


func flying_position(canvas_size: Vector2, target: Vector2, local: float, index: int, count: int) -> Vector2:
	var spread := (float(index) - float(count - 1) * 0.5) / maxf(float(count - 1), 1.0)
	var start := Vector2(canvas_size.x * (0.5 + spread * 0.18), -70.0 - float(index % 3) * 28.0)
	var settle := ease(local, -1.65)
	var curve_direction := -1.0 if index % 2 == 0 else 1.0
	var curve := Vector2(curve_direction * sin(settle * PI) * minf(86.0, canvas_size.x * 0.045), 0.0)
	return start.lerp(target, settle) + curve


func draw_flight_trail(canvas: Control, position: Vector2, local: float, index: int) -> void:
	var strength := sin(clampf(local, 0.0, 1.0) * PI)
	if strength <= 0.01:
		return
	var slant := -1.0 if index % 2 == 0 else 1.0
	var tail := Vector2(slant * 18.0, -54.0) * strength
	canvas.draw_line(position, position + tail, ThemeColor.alpha_theme_color(strength * 0.055), 2.0, true)
	pass


func draw_row_label(canvas: Control, text: String, y: float, reveal: float) -> void:
	var font_size := clampi(int(canvas.size.y * 0.034), 20, 34)
	var x := canvas.size.x * 0.085
	draw_centered_text(canvas, text, Vector2(x, y), font_size, reveal * 0.72)
	pass


func draw_glowing_cell(canvas: Control, rect: Rect2, text: String, bright: bool, reveal: float) -> void:
	var fill_alpha := 0.07 if bright else 0.018
	var fill := ThemeColor.alpha_theme_color(fill_alpha * reveal)
	canvas.draw_rect(rect, fill, true)
	canvas.draw_rect(rect, ThemeColor.alpha_theme_color(0.24 * reveal), false, 1.2, true)
	if bright:
		var glow_rect := rect.grow(5.0)
		canvas.draw_rect(glow_rect, ThemeColor.alpha_theme_color(0.025 * reveal), false, 7.0, true)
	var font_size := clampi(int(rect.size.y * 0.65), 10, 30)
	draw_centered_text(canvas, text, rect.get_center(), font_size, reveal * 0.82)
	pass


func draw_line_symbol(canvas: Control, center: Vector2, value: int, line_count: int, width: float, reveal: float) -> void:
	var line_gap := 7.0 if line_count == 3 else 5.0
	var color := ThemeColor.alpha_theme_color(reveal * 0.32)
	for line_index in line_count:
		var y := center.y + (float(line_index) - float(line_count - 1) * 0.5) * line_gap
		var solid := ((value >> line_index) & YANG) == YANG
		if solid:
			canvas.draw_line(Vector2(center.x - width * 0.5, y), Vector2(center.x + width * 0.5, y), color, 3.0, true)
		else:
			var gap := maxf(2.0, width * 0.16)
			canvas.draw_line(Vector2(center.x - width * 0.5, y), Vector2(center.x - gap, y), color, 3.0, true)
			canvas.draw_line(Vector2(center.x + gap, y), Vector2(center.x + width * 0.5, y), color, 3.0, true)
	pass


func draw_centered_text(canvas: Control, text: String, position: Vector2, font_size: int, alpha: float) -> void:
	var font := Fonts.light()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := position + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 4, ThemeColor.alpha_theme_color(alpha * 0.04))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(ColorBase.primary_text, alpha))
	pass
