class_name TaiChiBaguaFlow
extends RefCounted

## Pulls the eight trigrams out of the completed hierarchy and settles them into
## a circular compass. Each trigram leaves the row from left to right.

const TRANSITION_SECONDS := 5.8
const NAMES := ["乾", "兑", "离", "震", "巽", "坎", "艮", "坤"]
# Angles match the reference compass: 乾 at top, 坤 at bottom, 离/坎 at left/right,
# and the remaining four trigrams on the diagonals.
const TARGET_ANGLES := [-PI * 0.5, -PI * 0.75, PI, PI * 0.75, -PI * 0.25, 0.0, PI * 0.25, PI * 0.5]

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


func hierarchy_opacity() -> float:
	# Only the supporting hierarchy fades. The trigrams and taiji are redrawn by
	# this flow at their current positions, so their motion remains continuous.
	return 1.0 - smoothstep(0.0, 0.28, progress())


func trigram_progress(index: int) -> float:
	# Small start offsets preserve the original row's left-to-right reading order.
	var start := 0.04 + float(index) * 0.035
	return smoothstep(start, start + 0.48, progress())


func frame_progress() -> float:
	return smoothstep(0.58, 0.92, progress())


func taiji_progress() -> float:
	return smoothstep(0.12, 0.62, progress())


func taiji_center(canvas_size: Vector2, evolution: TaiChiEvolutionFlow) -> Vector2:
	# Begin at the exact final position of the hierarchy phase, then move the same
	# shader-backed taiji into the compass center—no replacement image is created.
	return evolution.symbol_center(canvas_size).lerp(canvas_size * 0.5, ease(taiji_progress(), -1.35))


func taiji_radius(canvas_size: Vector2, evolution: TaiChiEvolutionFlow) -> float:
	var source_radius := evolution.symbol_radius(canvas_size)
	var target_radius := minf(canvas_size.x, canvas_size.y) * 0.155
	return lerpf(source_radius, target_radius, ease(taiji_progress(), -1.35))


func draw(canvas: Control, evolution: TaiChiEvolutionFlow) -> void:
	if not active:
		return
	var center := canvas.size * 0.5
	var orbit_radius := minf(canvas.size.x, canvas.size.y) * 0.34
	for index in 8:
		draw_moving_trigram(canvas, evolution, center, orbit_radius, index)
	draw_frame(canvas, center, orbit_radius)
	pass


func draw_moving_trigram(canvas: Control, evolution: TaiChiEvolutionFlow, center: Vector2, orbit_radius: float, index: int) -> void:
	var local := trigram_progress(index)
	var area := evolution.content_area(canvas.size)
	# Source geometry intentionally matches TaiChiEvolutionFlow.draw_trigram_row.
	# At local == 0 the handoff is pixel-aligned; at local == 1 it is radial.
	var source := Vector2(area.position.x + (float(index) + 0.5) * area.size.x / 8.0, evolution.row_y(canvas.size, 3))
	var angle: float = TARGET_ANGLES[index]
	var target := center + Vector2.from_angle(angle) * orbit_radius
	# Lift the midpoint of the interpolation into a shallow arc while retaining
	# identical endpoints, producing a deliberate rather than mechanical move.
	var arc_offset := Vector2(0.0, -sin(local * PI) * minf(90.0, canvas.size.y * 0.11))
	var position := source.lerp(target, ease(local, -1.3)) + arc_offset
	var rotation := lerpf(0.0, angle + PI * 0.5, ease(local, -1.2))
	var source_width := TaiChiEvolutionFlow.SYMBOL_WIDTH
	var target_width := minf(76.0, canvas.size.y * 0.085)
	var width := lerpf(source_width, target_width, local)
	var line_gap := lerpf(7.0, 13.0, local)
	var line_width := lerpf(3.0, 5.0, local)
	var alpha := lerpf(TaiChiTrigramDrawing.SOURCE_ALPHA, TaiChiTrigramDrawing.BASE_ALPHA, local)
	draw_trigram(canvas, position, rotation, TaiChiEvolutionFlow.TRIGRAM_VALUES[index], width, line_gap, line_width, alpha, local)
	var name_position := center + Vector2.from_angle(angle) * (orbit_radius + minf(72.0, canvas.size.y * 0.085))
	var source_name_position := source - Vector2(0.0, 34.0)
	var moving_name_position := source_name_position.lerp(name_position, ease(local, -1.3)) + arc_offset
	var target_font_size := clampi(int(canvas.size.y * 0.035), 20, 36)
	var font_size := int(round(lerpf(18.0, float(target_font_size), local)))
	draw_centered_text(canvas, NAMES[index], moving_name_position, font_size,
		lerpf(0.76, TaiChiTrigramDrawing.LABEL_BASE_ALPHA, local))
	pass


func draw_trigram(canvas: Control, center: Vector2, rotation: float, value: int, width: float, line_gap: float,
		line_width: float, alpha: float, local: float = 1.0) -> void:
	TaiChiTrigramDrawing.draw_symbol(canvas, center, value, 3, width, line_gap, line_width,
		alpha * smoothstep(0.0, 0.32, local), rotation)
	pass


func draw_frame(canvas: Control, center: Vector2, orbit_radius: float) -> void:
	var reveal := frame_progress()
	if reveal <= 0.0:
		return
	canvas.draw_arc(center, orbit_radius * 1.27, -PI * 0.5, -PI * 0.5 + TAU * reveal, 160,
		TaiChiGlowDrawing.outer_ring_color(reveal * 0.16), 1.4, true)
	canvas.draw_arc(center, orbit_radius * 1.31, -PI * 0.5, -PI * 0.5 + TAU * reveal, 160,
		TaiChiGlowDrawing.outer_ring_color(reveal * 0.09), 1.0, true)
	canvas.draw_arc(center, orbit_radius * 0.63, -PI * 0.5, -PI * 0.5 + TAU * reveal, 120,
		TaiChiGlowDrawing.inner_ring_color(reveal * 0.16), 1.2, true)
	for tick in 64:
		# Eight major ticks mark trigram directions; the remaining ticks echo the
		# sixty-four hexagrams without adding another dense row of symbols.
		var tick_progress := float(tick + 1) / 64.0
		if tick_progress > reveal:
			break
		var angle := -PI * 0.5 + TAU * float(tick) / 64.0
		var length := 11.0 if tick % 8 == 0 else 5.0
		var outer := center + Vector2.from_angle(angle) * orbit_radius * 1.29
		var inner := center + Vector2.from_angle(angle) * (orbit_radius * 1.29 - length)
		canvas.draw_line(inner, outer, ThemeColor.alpha_theme_color(0.2 * reveal), 1.2, true)
	pass


func draw_centered_text(canvas: Control, text: String, position: Vector2, font_size: int, alpha: float) -> void:
	if alpha <= 0.0:
		return
	TaiChiGlowDrawing.draw_centered_text(canvas, Fonts.light(), text, position, font_size, alpha)
	pass
