class_name TaiChiEvolutionFlow
extends RefCounted

## Expands the completed taiji into four generations. Rows rise from the taiji,
## while every row reveals its symbols in reading order from left to right.

## The deliberately long duration gives every generation enough time to travel
## from outside the viewport and settle before the next generation takes focus.
const TRANSITION_SECONDS := 14.4
const ROW_COUNT := 4
const ROW_TOP_RATIO := 0.16
const CONTENT_LEFT_RATIO := 0.25
const CONTENT_WIDTH_RATIO := 0.5
const SYMBOL_WIDTH := 54.0
# Values are stored top line first because [draw_line_symbol] lays lines out from
# top to bottom. This produces 乾 ☰ through 坤 ☷ in the displayed name order.
const DUALITY_NAMES := ["阳", "阴"]
const DUALITY_VALUES := [1, 0]
const FOUR_IMAGE_NAMES := ["太阳", "少阴", "少阳", "太阴"]
const FOUR_IMAGE_VALUES := [3, 2, 1, 0]
const TRIGRAM_NAMES := ["乾", "兑", "离", "震", "巽", "坎", "艮", "坤"]
const TRIGRAM_VALUES := [7, 6, 5, 4, 3, 2, 1, 0]
const DEPARTING_TITLE := "易有太极，是生两仪"
const DEPARTING_SUBTITLE := "There is in the Changes the Great Primal Beginning. This generates the two primary forces."

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
	# Rows overlap slightly, but their starts remain bottom-to-top: 太极、两仪、四象、八卦.
	var start := 0.26 + float(row_from_bottom) * 0.15
	return smoothstep(start, minf(start + 0.18, 1.0), progress())


func shrink_progress() -> float:
	# Shrinking finishes before movement begins so the large completed taiji does
	# not sweep across the whole screen at full size.
	return smoothstep(0.0, 0.18, progress())


func final_caption_progress() -> float:
	return smoothstep(0.34, 0.42, progress())


func symbol_radius(canvas_size: Vector2) -> float:
	var source_radius := minf(canvas_size.x, canvas_size.y) * 0.285
	var target_radius := clampf(minf(canvas_size.x, canvas_size.y) * 0.058, 28.0, 54.0)
	return lerpf(source_radius, target_radius, ease(shrink_progress(), -1.5))


func symbol_center(canvas_size: Vector2) -> Vector2:
	# Shrinking never changes the established formation position. All hierarchy
	# geometry is anchored to this center instead of moving the taiji to a row.
	return canvas_size * 0.5 - Vector2(0.0, minf(42.0, canvas_size.y * 0.055))


func row_y(canvas_size: Vector2, row_from_bottom: int) -> float:
	var bottom := symbol_center(canvas_size).y
	var top := canvas_size.y * ROW_TOP_RATIO
	return lerpf(bottom, top, float(row_from_bottom) / float(ROW_COUNT - 1))


func draw(canvas: Control, opacity: float = 1.0, draw_trigrams: bool = true) -> void:
	if not active:
		return
	draw_departing_caption(canvas)
	draw_taiji_row(canvas, row_progress(0) * opacity)
	draw_symbol_row(canvas, "两仪", DUALITY_NAMES, DUALITY_VALUES, 1,
		row_y(canvas.size, 1), row_progress(1) * opacity)
	draw_symbol_row(canvas, "四象", FOUR_IMAGE_NAMES, FOUR_IMAGE_VALUES, 2,
		row_y(canvas.size, 2), row_progress(2) * opacity)
	if draw_trigrams:
		# The bagua phase passes false and takes ownership of these same trigrams,
		# allowing them to move continuously into the circle without a cross-fade.
		draw_trigram_row(canvas, row_y(canvas.size, 3), row_progress(3) * opacity)
	pass


func draw_departing_caption(canvas: Control) -> void:
	# Continue the exact title layout from TaiChiFormationFlow and fade it away
	# without changing font sizes, which would rasterize new glyph sizes mid-animation.
	var shrink := shrink_progress()
	var opacity := 1.0 - smoothstep(0.0, 1.0, shrink)
	if opacity <= 0.0:
		return
	var source_radius := minf(canvas.size.x, canvas.size.y) * 0.285
	var symbol_origin := canvas.size * 0.5 - Vector2(0.0, minf(42.0, canvas.size.y * 0.055))
	var position := symbol_origin + Vector2(0.0, source_radius + minf(82.0, canvas.size.y * 0.11))
	var font_size := clampi(int(canvas.size.y * 0.046), 26, 46)
	var font := Fonts.light()
	var glyph_width := font.get_string_size("极", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var gap := maxf(30.0, glyph_width * 1.06)
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
	var subtitle_size := clampi(int(canvas.size.y * 0.014), 10, 15)
	var subtitle_width := subtitle_font.get_string_size(DEPARTING_SUBTITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size).x
	canvas.draw_string(subtitle_font, position + Vector2(-subtitle_width * 0.5, float(font_size) * 1.25), DEPARTING_SUBTITLE,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, subtitle_size, Color(ColorBase.secondary_text, opacity * 0.58))
	pass


func draw_taiji_row(canvas: Control, reveal: float) -> void:
	if reveal <= 0.0:
		return
	draw_row_label(canvas, "太极", row_y(canvas.size, 0), reveal)
	draw_final_caption(canvas, reveal * final_caption_progress())
	pass


func draw_final_caption(canvas: Control, reveal: float) -> void:
	if reveal <= 0.0:
		return
	var center := symbol_center(canvas.size)
	var radius := symbol_radius(canvas.size)
	var chinese_position := center + Vector2(0.0, radius + minf(38.0, canvas.size.y * 0.04))
	draw_centered_text(canvas, "两仪生四象，四象生八卦", chinese_position,
		clampi(int(canvas.size.y * 0.024), 17, 26), reveal * 0.82)
	draw_centered_text(canvas,
		"The two primary forces generate the four images. The four images generate the eight trigrams.",
		chinese_position + Vector2(0.0, minf(34.0, canvas.size.y * 0.035)),
		clampi(int(canvas.size.y * 0.014), 11, 15), reveal * 0.58)
	pass


func draw_symbol_row(canvas: Control, title: String, names: Array, values: Array, line_count: int,
		y: float, reveal: float) -> void:
	if reveal <= 0.0:
		return
	draw_row_label(canvas, title, y, reveal)
	var area := content_area(canvas.size)
	var item_count := values.size()
	var cell_width := area.size.x / float(item_count)
	for index in item_count:
		var local := item_progress(reveal, index, item_count)
		if local <= 0.0:
			continue
		var target_center := Vector2(area.position.x + (float(index) + 0.5) * cell_width, y)
		var center := flying_position(canvas.size, target_center, local, index, item_count)
		var scale := lerpf(0.38, 1.0, ease(local, -1.8))
		draw_flight_trail(canvas, center, local, index)
		draw_line_symbol(canvas, center, values[index], line_count, SYMBOL_WIDTH * scale, local)
		draw_centered_text(canvas, names[index], center + Vector2(0.0, -34.0 * scale),
			maxi(10, int(round(18.0 * scale))), local * 0.76)
	pass


func draw_trigram_row(canvas: Control, y: float, reveal: float) -> void:
	if reveal <= 0.0:
		return
	draw_row_label(canvas, "八卦", y, reveal)
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
		draw_line_symbol(canvas, center, TRIGRAM_VALUES[index], 3, SYMBOL_WIDTH * scale, local)
		draw_centered_text(canvas, TRIGRAM_NAMES[index], center + Vector2(0.0, -34.0 * scale),
			maxi(10, int(round(18.0 * scale))), local * 0.76)
	pass


func content_area(canvas_size: Vector2) -> Rect2:
	return Rect2(canvas_size.x * CONTENT_LEFT_RATIO, 0.0,
		canvas_size.x * CONTENT_WIDTH_RATIO, canvas_size.y)


func item_progress(reveal: float, index: int, count: int) -> float:
	# Stagger each item across 70% of its row window. The remaining 30% is the
	# individual flight duration, preserving a clear left-to-right launch order.
	var start := float(index) / float(count) * 0.7
	return smoothstep(start, minf(start + 0.3, 1.0), reveal)


func flying_position(canvas_size: Vector2, target: Vector2, local: float, index: int, count: int) -> Vector2:
	# All symbols begin above the viewport. Their start x positions occupy a narrow
	# fan around the center, then alternating sine offsets create curved approaches
	# without changing the exact final target when local reaches 1.
	var spread := (float(index) - float(count - 1) * 0.5) / maxf(float(count - 1), 1.0)
	var start := Vector2(canvas_size.x * (0.5 + spread * 0.18), -70.0 - float(index % 3) * 28.0)
	var settle := ease(local, -1.65)
	var curve_direction := -1.0 if index % 2 == 0 else 1.0
	var curve := Vector2(curve_direction * sin(settle * PI) * minf(86.0, canvas_size.x * 0.045), 0.0)
	return start.lerp(target, settle) + curve


func draw_flight_trail(canvas: Control, position: Vector2, local: float, index: int) -> void:
	# sin(0..PI) makes the trail invisible at launch and landing and strongest at
	# mid-flight. Alternating slants keep adjacent symbols visually distinguishable.
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


func draw_line_symbol(canvas: Control, center: Vector2, value: int, line_count: int, width: float, reveal: float) -> void:
	var line_gap := 7.0 if line_count == 3 else 5.0
	TaiChiTrigramDrawing.draw_symbol(canvas, center, value, line_count, width, line_gap, 3.0,
		reveal * TaiChiTrigramDrawing.SOURCE_ALPHA)
	pass


func draw_centered_text(canvas: Control, text: String, position: Vector2, font_size: int, alpha: float) -> void:
	var font := Fonts.light()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := position + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 4, ThemeColor.alpha_theme_color(alpha * 0.04))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(ColorBase.primary_text, alpha))
	pass
