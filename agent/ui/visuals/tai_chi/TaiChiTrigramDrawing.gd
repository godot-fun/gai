class_name TaiChiTrigramDrawing
extends RefCounted

## Draws a line symbol in local direction/normal axes so hierarchy and orbit
## phases share exactly the same solid/broken-line geometry.


static func draw_symbol(canvas: Control, center: Vector2, value: int, line_count: int, width: float,
		line_gap: float, line_width: float, alpha: float, rotation: float = 0.0, glow_alpha: float = 0.0) -> void:
	var direction := Vector2.from_angle(rotation)
	var normal := direction.rotated(PI * 0.5)
	var color := ThemeColor.alpha_theme_color(alpha)
	var glow := ThemeColor.alpha_theme_color(glow_alpha)
	for line_index in line_count:
		var line_center := center + normal * (float(line_index) - float(line_count - 1) * 0.5) * line_gap
		var solid := ((value >> line_index) & 1) == 1
		if solid:
			draw_segment(canvas, line_center - direction * width * 0.5, line_center + direction * width * 0.5,
				color, glow, line_width)
		else:
			var half_gap := maxf(2.0, width * 0.16)
			draw_segment(canvas, line_center - direction * width * 0.5, line_center - direction * half_gap,
				color, glow, line_width)
			draw_segment(canvas, line_center + direction * half_gap, line_center + direction * width * 0.5,
				color, glow, line_width)
	pass


static func draw_segment(canvas: Control, start: Vector2, finish: Vector2, color: Color, glow: Color, line_width: float) -> void:
	if glow.a > 0.0:
		canvas.draw_line(start, finish, glow, line_width * 2.8, true)
	canvas.draw_line(start, finish, color, line_width, true)
	pass
