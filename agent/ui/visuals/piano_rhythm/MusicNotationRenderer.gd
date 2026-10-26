class_name MusicNotationRenderer
extends RefCounted

## Stateless vector renderer for the score glyphs used by PianoRhythm. It deliberately
## owns notation shape and layout only; the effect owns agent-event mapping and motion.

enum Duration { WHOLE, HALF, QUARTER, EIGHTH, SIXTEENTH, THIRTY_SECOND }

const STAFF_STEP := 7.0
const HEAD_RADIUS := Vector2(9.0, 6.5)


static func draw_staff(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	for line_index in range(5):
		var y := rect.position.y + float(line_index) * STAFF_STEP
		canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(color, 0.12), 1.0)
	pass


static func draw_treble_clef(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_arc(center + Vector2(0.0, -8.0), 13.0, -0.65, TAU + 0.35, 18, Color(color, 0.70), 1.8)
	canvas.draw_arc(center + Vector2(2.0, -2.0), 5.0, 0.0, TAU, 12, Color(color, 0.86), 1.5)
	canvas.draw_line(center + Vector2(-2.0, -26.0), center + Vector2(4.0, 24.0), Color(color, 0.84), 1.6)
	pass


static func draw_bass_clef(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_arc(center + Vector2(-3.0, 0.0), 12.0, -1.2, 1.35, 12, Color(color, 0.80), 2.0)
	canvas.draw_circle(center + Vector2(11.0, -5.0), 1.9, Color(color, 0.84))
	canvas.draw_circle(center + Vector2(11.0, 6.0), 1.9, Color(color, 0.84))
	pass


static func draw_pedal(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color) -> void:
	canvas.draw_string(Fonts.medium(), start, "Ped.", HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.label_small_size, Color(color, 0.62))
	canvas.draw_line(start + Vector2(25.0, -3.0), end, Color(color, 0.48), 1.0)
	pass


static func draw_note(canvas: CanvasItem, center: Vector2, color: Color, duration: Duration, pitch_step: int, accidental: int, dotted: bool, chord_steps: PackedInt32Array, tie: bool, triplet: bool, dynamic_mark: String, staccato: bool, fermata: bool) -> void:
	var heads := chord_steps.duplicate()
	if heads.is_empty():
		heads.append(pitch_step)
	for step in heads:
		draw_note_head(canvas, center + Vector2(0.0, -float(step) * STAFF_STEP * 0.5), color, duration)
	if duration != Duration.WHOLE:
		var stem_x := center.x + HEAD_RADIUS.x * 0.72
		var top_step: int = pitch_step
		for step in heads:
			top_step = maxi(top_step, step)
		var stem_base := center.y - float(top_step) * STAFF_STEP * 0.5
		var stem_top := stem_base - 31.0
		canvas.draw_line(Vector2(stem_x, stem_base), Vector2(stem_x, stem_top), Color(color, 0.92), 1.7)
		var flags := flag_count(duration)
		for flag_index in range(flags):
			var flag_y := stem_top + float(flag_index) * 6.0
			canvas.draw_arc(Vector2(stem_x - 5.0, flag_y + 5.0), 8.0, -0.35, 1.25, 8, Color(color, 0.84), 1.6)
	if accidental != 0:
		var symbol := "♯" if accidental > 0 else "♭"
		canvas.draw_string(Fonts.semibold(), center + Vector2(-25.0, 5.0), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.label_medium_size, Color(color, 0.88))
	if dotted:
		canvas.draw_circle(center + Vector2(15.0, 1.0), 2.3, Color(color, 0.88))
	if staccato:
		canvas.draw_circle(center + Vector2(0.0, -16.0), 2.1, Color(color, 0.92))
	if tie:
		canvas.draw_arc(center + Vector2(25.0, 13.0), 20.0, PI + 0.2, TAU - 0.2, 12, Color(color, 0.62), 1.2)
	if fermata:
		canvas.draw_arc(center + Vector2(0.0, -20.0), 8.0, PI, TAU, 12, Color(color, 0.78), 1.2)
		canvas.draw_circle(center + Vector2(0.0, -20.0), 1.8, Color(color, 0.84))
	if triplet:
		canvas.draw_string(Fonts.medium(), center + Vector2(-2.0, -42.0), "3", HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.label_small_size, Color(color, 0.78))
	if not dynamic_mark.is_empty():
		canvas.draw_string(Fonts.medium(), center + Vector2(-9.0, 32.0), dynamic_mark, HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.label_small_size, Color(color, 0.72))
	pass


static func draw_rest(canvas: CanvasItem, center: Vector2, color: Color, duration: Duration) -> void:
	var draw_color := Color(color, 0.84)
	match duration:
		Duration.WHOLE:
			canvas.draw_rect(Rect2(center.x - 9.0, center.y + 2.0, 18.0, 5.0), draw_color, true)
		Duration.HALF:
			canvas.draw_rect(Rect2(center.x - 9.0, center.y - 4.0, 18.0, 5.0), draw_color, true)
		Duration.QUARTER:
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-4.0, -14.0), center + Vector2(5.0, -5.0), center + Vector2(-2.0, 4.0), center + Vector2(6.0, 13.0)]), draw_color, 2.2)
		Duration.EIGHTH, Duration.SIXTEENTH, Duration.THIRTY_SECOND:
			canvas.draw_line(center + Vector2(1.0, -14.0), center + Vector2(1.0, 12.0), draw_color, 1.8)
			var flags := flag_count(duration)
			for flag_index in range(flags):
				canvas.draw_arc(center + Vector2(-4.0, -9.0 + float(flag_index) * 6.0), 7.0, -0.2, 1.5, 8, draw_color, 1.6)
			canvas.draw_circle(center + Vector2(1.0, 13.0), 3.5, draw_color)
	pass


static func draw_note_head(canvas: CanvasItem, center: Vector2, color: Color, duration: Duration) -> void:
	var head_color := Color(color, 0.95)
	if duration == Duration.WHOLE or duration == Duration.HALF:
		canvas.draw_circle(center, HEAD_RADIUS.x, head_color)
		canvas.draw_circle(center, HEAD_RADIUS.x - 2.4, Color(Colors.app_background, 0.94))
		return
	canvas.draw_circle(center, HEAD_RADIUS.x, head_color)
	canvas.draw_circle(center + Vector2(-2.3, -1.7), HEAD_RADIUS.x * 0.28, Color.WHITE)
	pass


static func flag_count(duration: Duration) -> int:
	match duration:
		Duration.EIGHTH:
			return 1
		Duration.SIXTEENTH:
			return 2
		Duration.THIRTY_SECOND:
			return 3
	return 0
