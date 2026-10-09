class_name TaiChiFormationFlow
extends RefCounted

## Bends the three duality strokes into the outer ring and two eye circles,
## then resolves those construction paths into the complete taiji symbol.

const TRANSITION_SECONDS := 3.2
const TITLE := "易有太极，是生两仪"
const SUBTITLE := "IN CHANGE THERE IS THE GREAT ULTIMATE"
const CURVE_STEPS := 72
const DOT_RADIUS_RATIO := 0.105

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


func outer_progress() -> float:
	return smoothstep(0.0, 0.38, progress())


func upper_inner_progress() -> float:
	return smoothstep(0.34, 0.56, progress())


func lower_inner_progress() -> float:
	return smoothstep(0.48, 0.68, progress())


func divider_progress() -> float:
	return smoothstep(0.68, 0.86, progress())


func fill_progress() -> float:
	return smoothstep(0.86, 1.0, progress())


func previous_state_opacity() -> float:
	return 1.0 - smoothstep(0.0, 0.28, progress())


func draw(canvas: Control, center: Vector2, available_width: float) -> void:
	if not active:
		return
	var reveal := progress()
	var radius := minf(canvas.size.x, canvas.size.y) * 0.285
	var symbol_center := center - Vector2(0.0, minf(42.0, canvas.size.y * 0.055))
	var source_half_width := minf(available_width * 0.38, 620.0)
	var source_gap := source_half_width * 0.13
	var row_gap := minf(105.0, canvas.size.y * 0.14)
	var source_yang_y := center.y - row_gap * 0.5
	var source_yin_y := center.y + row_gap * 0.5
	var fill_alpha := fill_progress()
	var construction_alpha := 1.0 - fill_alpha * 0.45
	draw_outer_morph(canvas, symbol_center, radius, source_half_width, source_yang_y, outer_progress(), construction_alpha)
	draw_inner_morph(canvas, symbol_center, radius, source_half_width, source_gap, source_yin_y, upper_inner_progress(), lower_inner_progress(), construction_alpha)
	draw_divider(canvas, symbol_center, radius, divider_progress(), construction_alpha)
	draw_caption(canvas, symbol_center + Vector2(0.0, radius + minf(82.0, canvas.size.y * 0.11)), reveal)
	pass


func draw_outer_morph(canvas: Control, center: Vector2, radius: float, half_width: float, source_y: float, reveal: float, alpha: float) -> void:
	var points := PackedVector2Array()
	for index in range(CURVE_STEPS + 1):
		var ratio := float(index) / float(CURVE_STEPS)
		var source := Vector2(center.x + lerpf(-half_width, half_width, ratio), source_y)
		# Join the two ends at the bottom of the ring so the stroke's midpoint is
		# lifted upward first, forming an arch before it closes into a circle.
		var angle := PI * 0.5 + TAU * ratio
		var target := center + Vector2.from_angle(angle) * radius
		points.append(source.lerp(target, ease(reveal, -1.4)))
	canvas.draw_polyline(points, Color(ColorBase.primary_text, alpha * 0.62), 2.0, true)
	pass


func draw_inner_morph(canvas: Control, center: Vector2, radius: float, half_width: float, gap: float, source_y: float, upper_reveal: float, lower_reveal: float, alpha: float) -> void:
	for side in 2:
		var points := PackedVector2Array()
		var reveal := upper_reveal if side == 0 else lower_reveal
		var dot_center := center + Vector2(0.0, (-0.5 if side == 0 else 0.5) * radius)
		for index in range(CURVE_STEPS + 1):
			var ratio := float(index) / float(CURVE_STEPS)
			var source_start := -half_width if side == 0 else gap
			var source_end := -gap if side == 0 else half_width
			var source := Vector2(center.x + lerpf(source_start, source_end, ratio), source_y)
			# Each broken stroke becomes one of the two taiji eyes. Close from the point
			# nearest the source row so neither stroke travels through the other eye.
			var angle := (PI * 0.5 if side == 0 else -PI * 0.5) + TAU * ratio
			var target := dot_center + Vector2.from_angle(angle) * radius * DOT_RADIUS_RATIO
			points.append(source.lerp(target, ease(reveal, -1.4)))
		canvas.draw_polyline(points, Color(ColorBase.primary_text, alpha * 0.62), 1.6, true)
	pass


func draw_divider(canvas: Control, center: Vector2, radius: float, reveal: float, alpha: float) -> void:
	if reveal <= 0.0:
		return
	var upper_points := PackedVector2Array()
	var lower_points := PackedVector2Array()
	var upper_center := center - Vector2(0.0, radius * 0.5)
	var lower_center := center + Vector2(0.0, radius * 0.5)
	var upper_reveal := minf(reveal * 2.0, 1.0)
	var lower_reveal := clampf(reveal * 2.0 - 1.0, 0.0, 1.0)
	var upper_steps := maxi(2, int(ceil(float(CURVE_STEPS / 2) * upper_reveal)))
	for index in range(upper_steps + 1):
		var ratio := minf(float(index) / float(CURVE_STEPS / 2), upper_reveal)
		var upper_angle := -PI * 0.5 + PI * ratio
		upper_points.append(upper_center + Vector2.from_angle(upper_angle) * radius * 0.5)
	var color := Color(ColorBase.primary_text, alpha * 0.62)
	canvas.draw_polyline(upper_points, color, 2.0, true)
	if lower_reveal > 0.0:
		var lower_steps := maxi(2, int(ceil(float(CURVE_STEPS / 2) * lower_reveal)))
		for index in range(lower_steps + 1):
			var ratio := minf(float(index) / float(CURVE_STEPS / 2), lower_reveal)
			var lower_angle := -PI * 0.5 - PI * ratio
			lower_points.append(lower_center + Vector2.from_angle(lower_angle) * radius * 0.5)
		canvas.draw_polyline(lower_points, color, 2.0, true)
	pass


func draw_caption(canvas: Control, position: Vector2, reveal: float) -> void:
	var title_reveal := smoothstep(0.62, 1.0, reveal)
	if title_reveal <= 0.0:
		return
	var font := Fonts.light()
	var font_size := clampi(int(canvas.size.y * 0.046), 26, 46)
	var glyph_width := font.get_string_size("极", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var gap := maxf(30.0, glyph_width * 1.06)
	var middle := (float(TITLE.length()) - 1.0) * 0.5
	for index in TITLE.length():
		var outward := absf(float(index) - middle) / middle
		var local := smoothstep(outward * 0.18, 0.76 + outward * 0.18, title_reveal)
		if local <= 0.0:
			continue
		var glyph := TITLE.substr(index, 1)
		var glyph_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var target_x := (float(index) - middle) * gap
		var baseline := position + Vector2(target_x * ease(local, -1.5) - glyph_size.x * 0.5, glyph_size.y * 0.34)
		canvas.draw_string(font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(ColorBase.primary_text, local * 0.72))
	var subtitle_font := Fonts.medium()
	var subtitle_size := clampi(int(canvas.size.y * 0.014), 10, 15)
	var subtitle_width := subtitle_font.get_string_size(SUBTITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size).x
	canvas.draw_string(subtitle_font, position + Vector2(-subtitle_width * 0.5, font_size * 1.25), SUBTITLE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, subtitle_size, Color(ColorBase.secondary_text, title_reveal * 0.58))
	pass
