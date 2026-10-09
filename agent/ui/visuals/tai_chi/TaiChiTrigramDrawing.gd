class_name TaiChiTrigramDrawing
extends RefCounted

## Draws a line symbol in local direction/normal axes so hierarchy and orbit
## phases share exactly the same solid/broken-line geometry.

const SOURCE_ALPHA := 0.32
const BASE_ALPHA := 0.58
const HIGHLIGHT_ALPHA := 0.9
const LABEL_BASE_ALPHA := 0.62
const LABEL_HIGHLIGHT_ALPHA := 0.9


static func draw_symbol(canvas: Control, center: Vector2, value: int, line_count: int, width: float,
		line_gap: float, line_width: float, alpha: float, rotation: float = 0.0) -> void:
	var direction := Vector2.from_angle(rotation)
	var normal := direction.rotated(PI * 0.5)
	for line_index in line_count:
		var line_center := center + normal * (float(line_index) - float(line_count - 1) * 0.5) * line_gap
		var solid := ((value >> line_index) & 1) == 1
		if solid:
			draw_segment(canvas, line_center - direction * width * 0.5, line_center + direction * width * 0.5,
				alpha, line_width)
		else:
			var half_gap := maxf(2.0, width * 0.16)
			draw_segment(canvas, line_center - direction * width * 0.5, line_center - direction * half_gap,
				alpha, line_width)
			draw_segment(canvas, line_center + direction * half_gap, line_center + direction * width * 0.5,
				alpha, line_width)
	pass


static func draw_segment(canvas: Control, start: Vector2, finish: Vector2, alpha: float,
		line_width: float) -> void:
	TaiChiGlowDrawing.draw_line(canvas, start, finish, line_width, alpha)
	pass
