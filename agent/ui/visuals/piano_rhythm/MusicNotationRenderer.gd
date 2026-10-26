class_name MusicNotationRenderer
extends RefCounted

## Stateless vector engraver for the score glyphs used by PianoRhythm. It owns notation
## shape and layout only; the effect owns agent-event mapping and motion.
##
## Geometry follows printed engraving ratios expressed in staff spaces ([constant SPACE]):
## a notehead is one space tall and 1.18 spaces wide, tilted about -20 degrees, a stem is
## 3.5 spaces long and 0.12 spaces wide, and rests keep their printed silhouettes
## (ball-and-hook tails, tapered quarter-rest strokes). A glyph is engraved in local space
## with the base notehead at [code]center[/code]; every diatonic step moves a head by half
## a space and its stem flips according to the head farthest from the middle line.

enum Duration { WHOLE, HALF, QUARTER, EIGHTH, SIXTEENTH, THIRTY_SECOND }

const SPACE := 14.0
const STEP := SPACE * 0.5
const HEAD_WIDTH := SPACE * 1.18
const HEAD_WIDTH_HOLLOW := SPACE * 1.30
const HEAD_TILT := -0.32
const HEAD_STROKE := SPACE * 0.19
const STEM_LENGTH := SPACE * 3.5
const STEM_WIDTH := SPACE * 0.12
const DOT_RADIUS := SPACE * 0.16
const ACCIDENTAL_HEIGHT := SPACE * 2.2
const HEAD_SEGMENTS := 28
const DYNAMIC_FONT_SIZE := 17


## One engraved event. PianoRhythm fills it; the renderer only reads it.
class Note:
	var duration: int = Duration.QUARTER
	var step: int = 0
	var chord_steps := PackedInt32Array()
	var accidental: int = 0
	var dotted: bool = false
	var staccato: bool = false
	var fermata: bool = false
	var triplet: bool = false
	var tie: bool = false
	var dynamic_mark: String = ""


static func is_hollow(duration: int) -> bool:
	return duration == Duration.WHOLE or duration == Duration.HALF


static func flag_count(duration: int) -> int:
	match duration:
		Duration.EIGHTH:
			return 1
		Duration.SIXTEENTH:
			return 2
		Duration.THIRTY_SECOND:
			return 3
	return 0


## Estimated distance from the base notehead to the lowest ink of the glyph, so callers can
## stack labels and energy wakes under the stem, flags and dynamic mark instead of over them.
static func glyph_bottom(note: Note) -> float:
	var steps := chord_steps_for(note)
	var stem_up := stem_points_up(steps)
	var bottom := -float(steps[0]) * STEP + SPACE * 0.5
	if note.duration != Duration.WHOLE and not stem_up:
		bottom = -float(steps[steps.size() - 1]) * STEP + STEM_LENGTH + SPACE * 2.0
	if note.staccato and stem_up:
		bottom += SPACE * 0.7
	if not note.dynamic_mark.is_empty():
		bottom += SPACE * 1.15
	return bottom


static func draw_note(canvas: CanvasItem, center: Vector2, color: Color, note: Note) -> void:
	var steps := chord_steps_for(note)
	var head_width := HEAD_WIDTH_HOLLOW if is_hollow(note.duration) else HEAD_WIDTH
	var heads := layout_heads(steps, center, head_width)
	var bounds := head_bounds(heads, head_width)
	# Bounds cover the head ink; recover the outer head centers so the stem spans the chord.
	var head_top := bounds.position.y + SPACE * 0.5
	var head_bottom := bounds.end.y - SPACE * 0.5
	var stem_up := stem_points_up(steps)
	if note.duration != Duration.WHOLE:
		var stem_x := bounds.end.x if stem_up else bounds.position.x
		var stem_tip := head_top - STEM_LENGTH if stem_up else head_bottom + STEM_LENGTH
		var stem_other := head_bottom if stem_up else head_top
		canvas.draw_line(Vector2(stem_x, stem_tip), Vector2(stem_x, stem_other), Color(color, 0.92), STEM_WIDTH, true)
		draw_flags(canvas, Vector2(stem_x, stem_tip), stem_up, flag_count(note.duration), color)
	for head in heads:
		draw_note_head(canvas, head, head_width, is_hollow(note.duration), color)
	draw_note_marks(canvas, center, color, note, heads[steps.find(note.step)], bounds, stem_up)
	pass


## Heads in engraving order, lowest first. A second is split horizontally so the two
## noteheads never sit on top of each other.
static func layout_heads(steps: PackedInt32Array, center: Vector2, head_width: float) -> Array[Vector2]:
	var heads: Array[Vector2] = []
	for step in steps:
		heads.append(center + Vector2(0.0, -float(step) * STEP))
	for index in range(steps.size() - 1):
		if steps[index + 1] - steps[index] == 1:
			heads[index + 1] += Vector2(head_width * 0.62, 0.0)
	return heads


static func head_bounds(heads: Array[Vector2], head_width: float) -> Rect2:
	var bounds := Rect2(heads[0] - Vector2(head_width, SPACE) * 0.5, Vector2(head_width, SPACE))
	for head in heads:
		bounds = bounds.expand(head - Vector2(head_width, SPACE) * 0.5)
		bounds = bounds.expand(head + Vector2(head_width, SPACE) * 0.5)
	return bounds


## The stem points up unless the head farthest from the middle line sits above it.
static func stem_points_up(steps: PackedInt32Array) -> bool:
	var extreme := 0
	for step in steps:
		if absi(step) > absi(extreme):
			extreme = step
	return extreme < 0


static func chord_steps_for(note: Note) -> PackedInt32Array:
	var steps := PackedInt32Array([note.step])
	for step in note.chord_steps:
		if not steps.has(step):
			steps.append(step)
	steps.sort()
	return steps


static func draw_note_head(canvas: CanvasItem, center: Vector2, head_width: float, hollow: bool, color: Color) -> void:
	var radius := Vector2(head_width * 0.5, SPACE * 0.5)
	var head_color := Color(color, 0.95)
	if hollow:
		draw_hollow_ellipse(canvas, center, radius, HEAD_TILT, HEAD_STROKE, head_color)
		return
	draw_filled_ellipse(canvas, center, radius, HEAD_TILT, head_color)
	pass


static func draw_flags(canvas: CanvasItem, origin: Vector2, stem_up: bool, flags: int, color: Color) -> void:
	if flags <= 0:
		return
	var direction := -1.0 if stem_up else 1.0
	for index in range(flags):
		var attach := origin + Vector2(0.0, direction * float(index) * SPACE * 0.86)
		var tip := attach + Vector2(SPACE * 1.02, direction * SPACE * 1.50)
		var outer := quadratic_points(attach, attach + Vector2(SPACE * 1.44, direction * SPACE * 0.70), tip, 9)
		var inner := quadratic_points(tip, attach + Vector2(SPACE * 0.26, direction * SPACE * 0.80), attach + Vector2(SPACE * 0.05, direction * SPACE * 0.60), 9)
		var polygon := outer.duplicate()
		for point in inner:
			polygon.append(point)
		canvas.draw_colored_polygon(polygon, Color(color, 0.92))
	pass


static func draw_note_marks(canvas: CanvasItem, center: Vector2, color: Color, note: Note, base_head: Vector2, bounds: Rect2, stem_up: bool) -> void:
	if note.accidental != 0:
		draw_accidental(canvas, Vector2(bounds.position.x - SPACE * 0.72, base_head.y), color, note.accidental)
	if note.dotted:
		var dot_side := -1.0 if stem_up else 1.0
		canvas.draw_circle(Vector2(bounds.end.x + SPACE * 0.40, base_head.y + dot_side * STEP * 0.9), DOT_RADIUS, Color(color, 0.9))
	if note.staccato:
		var staccato_y := bounds.end.y + STEP * 1.15 if stem_up else bounds.position.y - STEP * 1.15
		canvas.draw_circle(Vector2(base_head.x, staccato_y), DOT_RADIUS * 1.1, Color(color, 0.92))
	if note.tie:
		var tie_y := bounds.end.y + STEP * 1.1
		draw_slur(canvas, Vector2(bounds.end.x + SPACE * 0.30, tie_y), Vector2(bounds.end.x + SPACE * 2.0, tie_y), STEP * 1.2, Color(color, 0.62))
	if note.fermata:
		var fermata_y := bounds.position.y - STEM_LENGTH - SPACE * 0.45
		canvas.draw_arc(Vector2(center.x, fermata_y), SPACE * 0.52, PI, TAU, 16, Color(color, 0.8), 1.4, true)
		canvas.draw_circle(Vector2(center.x, fermata_y - SPACE * 0.20), DOT_RADIUS * 0.9, Color(color, 0.85))
	if note.triplet:
		draw_centered_text(canvas, Vector2(center.x, bounds.position.y - STEM_LENGTH - SPACE * 0.55), "3", Fonts.semibold(), DYNAMIC_FONT_SIZE, Color(color, 0.8))
	if not note.dynamic_mark.is_empty():
		draw_centered_text(canvas, Vector2(center.x, bounds.end.y + SPACE * 1.30), note.dynamic_mark, Fonts.medium(), DYNAMIC_FONT_SIZE, Color(color, 0.74))
	pass


static func draw_rest(canvas: CanvasItem, center: Vector2, color: Color, duration: int) -> void:
	var rest_color := Color(color, 0.88)
	match duration:
		Duration.WHOLE:
			canvas.draw_rect(Rect2(center.x - SPACE * 0.58, center.y, SPACE * 1.16, SPACE * 0.5), rest_color, true, -1.0, true)
		Duration.HALF:
			canvas.draw_rect(Rect2(center.x - SPACE * 0.58, center.y - SPACE * 0.5, SPACE * 1.16, SPACE * 0.5), rest_color, true, -1.0, true)
		Duration.QUARTER:
			draw_quarter_rest(canvas, center, rest_color)
		_:
			draw_hooked_rest(canvas, center, rest_color, flag_count(duration))
	pass


## The crotchet rest is a single tapered squiggle: a thick entry stroke, a waist hooked to
## the left, then a second thick stroke that ends in an upward-curling tail.
static func draw_quarter_rest(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	var entry := PackedVector2Array([center + Vector2(-0.10, -1.42) * SPACE, center + Vector2(0.14, -1.06) * SPACE, center + Vector2(0.33, -0.76) * SPACE])
	draw_stroke(canvas, entry, SPACE * 0.22, SPACE * 0.40, color)
	var waist := PackedVector2Array([center + Vector2(0.33, -0.76) * SPACE, center + Vector2(0.02, -0.40) * SPACE, center + Vector2(-0.38, -0.10) * SPACE])
	draw_stroke(canvas, waist, SPACE * 0.40, SPACE * 0.26, color)
	var descent := PackedVector2Array([center + Vector2(-0.38, -0.10) * SPACE, center + Vector2(0.04, 0.36) * SPACE, center + Vector2(0.16, 0.62) * SPACE])
	draw_stroke(canvas, descent, SPACE * 0.20, SPACE * 0.42, color)
	var tail := PackedVector2Array([center + Vector2(0.16, 0.62) * SPACE, center + Vector2(0.10, 0.98) * SPACE, center + Vector2(-0.34, 1.24) * SPACE, center + Vector2(-0.42, 1.30) * SPACE])
	draw_stroke(canvas, tail, SPACE * 0.42, SPACE * 0.06, color)
	pass


## Quaver-family rests: one ball-and-hook per flag, joined by a single slanted stem whose
## foot sits to the left of the hooks.
static func draw_hooked_rest(canvas: CanvasItem, center: Vector2, color: Color, flags: int) -> void:
	var head := center + Vector2(0.46, -(0.80 + 0.47 * float(flags - 1))) * SPACE
	var foot := center + Vector2(-0.22, 0.90 + 0.45 * float(flags - 1)) * SPACE
	draw_stroke(canvas, PackedVector2Array([head, (head + foot) * 0.5, foot]), SPACE * 0.26, SPACE * 0.14, color)
	for index in range(flags):
		var attach := head + Vector2(0.0, 0.42 * float(index)) * SPACE
		var ball := Vector2(center.x - SPACE * 0.30, attach.y + SPACE * 0.24)
		var hook := PackedVector2Array([ball + Vector2(SPACE * 0.16, -SPACE * 0.10), ball + Vector2(SPACE * 0.42, -SPACE * 0.10), attach])
		draw_stroke(canvas, hook, SPACE * 0.09, SPACE * 0.11, color)
		canvas.draw_circle(ball, SPACE * 0.20, color)
	pass


static func draw_accidental(canvas: CanvasItem, center: Vector2, color: Color, accidental: int) -> void:
	var mark_color := Color(color, 0.9)
	var half := ACCIDENTAL_HEIGHT * 0.5
	if accidental > 0:
		for side in [-1.0, 1.0]:
			canvas.draw_line(center + Vector2(side * SPACE * 0.20 + SPACE * 0.07, -half), center + Vector2(side * SPACE * 0.20 - SPACE * 0.07, half), mark_color, SPACE * 0.15, true)
		for side in [-1.0, 1.0]:
			canvas.draw_line(center + Vector2(-SPACE * 0.52, side * SPACE * 0.34), center + Vector2(SPACE * 0.52, side * SPACE * 0.34), mark_color, SPACE * 0.13, true)
		return
	canvas.draw_line(center + Vector2(-SPACE * 0.16, -half), center + Vector2(-SPACE * 0.16, SPACE * 0.62), mark_color, SPACE * 0.13, true)
	var bowl := PackedVector2Array([
		center + Vector2(-SPACE * 0.16, SPACE * 0.58),
		center + Vector2(SPACE * 0.34, SPACE * 0.44),
		center + Vector2(SPACE * 0.44, SPACE * 0.10),
		center + Vector2(SPACE * 0.02, -SPACE * 0.02),
	])
	draw_stroke(canvas, bowl, SPACE * 0.14, SPACE * 0.08, mark_color)
	pass


## A crescent (tie or slur) bulging away from the noteheads.
static func draw_slur(canvas: CanvasItem, start: Vector2, end: Vector2, bow: float, color: Color) -> void:
	var outer := quadratic_points(start, (start + end) * 0.5 + Vector2(0.0, bow), end, 8)
	var inner := quadratic_points(end, (start + end) * 0.5 + Vector2(0.0, bow * 0.34), start, 8)
	var polygon := outer.duplicate()
	for point in inner:
		polygon.append(point)
	canvas.draw_colored_polygon(polygon, color)
	pass


static func quadratic_points(from: Vector2, control: Vector2, to: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments + 1):
		var ratio := float(index) / float(segments)
		var inverse := 1.0 - ratio
		points.append(from * inverse * inverse + control * 2.0 * inverse * ratio + to * ratio * ratio)
	return points


## Flat ribbon along [param points] with a linear width taper and rounded joints. Small
## engraved details (flags, rest strokes, flat bowls) are built from these ribbons.
static func draw_stroke(canvas: CanvasItem, points: PackedVector2Array, start_width: float, end_width: float, color: Color) -> void:
	if points.size() < 2:
		return
	var lengths := PackedFloat32Array()
	var total := 0.0
	for index in range(points.size() - 1):
		var length := points[index].distance_to(points[index + 1])
		lengths.append(length)
		total += length
	if total <= 0.0:
		return
	var travelled := 0.0
	for index in range(points.size() - 1):
		var from := points[index]
		var to := points[index + 1]
		var from_width := lerpf(start_width, end_width, travelled / total)
		travelled += lengths[index]
		var to_width := lerpf(start_width, end_width, travelled / total)
		var normal := Vector2(-(to - from).normalized().y, (to - from).normalized().x)
		canvas.draw_colored_polygon(PackedVector2Array([
			from + normal * from_width * 0.5,
			to + normal * to_width * 0.5,
			to - normal * to_width * 0.5,
			from - normal * from_width * 0.5,
		]), color)
		canvas.draw_circle(from, from_width * 0.5, color)
	canvas.draw_circle(points[points.size() - 1], end_width * 0.5, color)
	pass


static func ellipse_points(center: Vector2, radius: Vector2, rotation: float, segments: int = HEAD_SEGMENTS) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y).rotated(rotation))
	return points


static func draw_filled_ellipse(canvas: CanvasItem, center: Vector2, radius: Vector2, rotation: float, color: Color) -> void:
	var points := ellipse_points(center, radius, rotation)
	canvas.draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, color, 1.2, true)
	pass


static func draw_hollow_ellipse(canvas: CanvasItem, center: Vector2, radius: Vector2, rotation: float, stroke: float, color: Color) -> void:
	var points := ellipse_points(center, radius, rotation)
	points.append(points[0])
	canvas.draw_polyline(points, color, stroke, true)
	pass


static func draw_centered_text(canvas: CanvasItem, position: Vector2, text: String, font: Font, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, position - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	pass
