class_name TaiChiGlowDrawing
extends RefCounted

## Shared luminous drawing style for Tai Chi typography and symbolic strokes.
## The foreground remains neutral while the active theme color is reserved for
## a restrained two-layer halo.

const TEXT_NEAR_GLOW_ALPHA := 0.11
const TEXT_FAR_GLOW_ALPHA := 0.045
const LINE_NEAR_GLOW_ALPHA := 0.11
const LINE_FAR_GLOW_ALPHA := 0.04
const INNER_RING_FOREGROUND_MIX := 0.28


static func outer_ring_color(alpha: float) -> Color:
	return ThemeColor.alpha_theme_color(alpha)


static func inner_ring_color(alpha: float) -> Color:
	var color := ThemeColor.accent_theme_color().lerp(ColorBase.primary_text, INNER_RING_FOREGROUND_MIX)
	return Color(color, alpha)


static func draw_text(canvas: Control, font: Font, baseline: Vector2, text: String, font_size: int,
		alpha: float, foreground: Color = ColorBase.primary_text) -> void:
	var near_width := clampi(int(round(float(font_size) * 0.09)), 2, 7)
	var far_width := clampi(int(round(float(font_size) * 0.17)), 4, 13)
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
		far_width, ThemeColor.alpha_theme_color(alpha * TEXT_FAR_GLOW_ALPHA))
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
		near_width, ThemeColor.alpha_theme_color(alpha * TEXT_NEAR_GLOW_ALPHA))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
		Color(foreground, alpha))
	pass


static func draw_centered_text(canvas: Control, font: Font, text: String, position: Vector2,
		font_size: int, alpha: float, foreground: Color = ColorBase.primary_text) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := position + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_text(canvas, font, baseline, text, font_size, alpha, foreground)
	pass


static func draw_line(canvas: Control, start: Vector2, finish: Vector2, line_width: float,
		alpha: float) -> void:
	canvas.draw_line(start, finish, ThemeColor.alpha_theme_color(alpha * LINE_FAR_GLOW_ALPHA),
		line_width * 5.0, true)
	canvas.draw_line(start, finish, ThemeColor.alpha_theme_color(alpha * LINE_NEAR_GLOW_ALPHA),
		line_width * 2.8, true)
	canvas.draw_line(start, finish, Color(ColorBase.primary_text, alpha), line_width, true)
	pass


static func draw_polyline(canvas: Control, points: PackedVector2Array, line_width: float,
		alpha: float) -> void:
	canvas.draw_polyline(points, ThemeColor.alpha_theme_color(alpha * LINE_FAR_GLOW_ALPHA),
		line_width * 5.0, true)
	canvas.draw_polyline(points, ThemeColor.alpha_theme_color(alpha * LINE_NEAR_GLOW_ALPHA),
		line_width * 2.8, true)
	canvas.draw_polyline(points, Color(ColorBase.primary_text, alpha), line_width, true)
	pass


static func draw_circle(canvas: Control, center: Vector2, radius: float, line_width: float,
		alpha: float) -> void:
	canvas.draw_circle(center, radius, ThemeColor.alpha_theme_color(alpha * LINE_FAR_GLOW_ALPHA),
		false, line_width * 5.0, true)
	canvas.draw_circle(center, radius, ThemeColor.alpha_theme_color(alpha * LINE_NEAR_GLOW_ALPHA),
		false, line_width * 2.8, true)
	canvas.draw_circle(center, radius, Color(ColorBase.primary_text, alpha), false, line_width, true)
	pass
