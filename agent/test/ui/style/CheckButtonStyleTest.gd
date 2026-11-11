extends Node


## The whole control follows the accent color: the label ramp and the Material switch glyph, which is
## tinted per state instead of left on the engine's grey track.
##
## Hover is the only state pair that may be filled: a checked toggle reports itself as *pressed*, so a
## pressed fill would paint every switched-on check button permanently.
func CheckButtonStyle_apply_test() -> void:
	var check := CheckButton.new()
	CheckButtonStyle.apply(check)
	var accent := ThemeColor.accent_theme_color()
	assert(check.get_theme_color("font_color") == accent)
	assert(check.get_theme_color("font_hover_color") == ThemeColor.promote(accent, Weights.w_2))
	assert(check.get_theme_color("font_pressed_color") == ThemeColor.demote(accent, Weights.w_2))
	# The icons are rasterized with the tint baked in, so the engine modulate stays neutral.
	assert(check.get_theme_color("button_checked_color") == Color.WHITE)
	assert(check.get_theme_color("button_unchecked_color") == Color.WHITE)
	assert(check.get_theme_constant("h_separation") == Margin.ma_2)

	# Both states use the app's Material switch art, rasterized one control tier tall and tinted:
	# secondary text while off, the accent while on.
	var off_image := (check.get_theme_icon("unchecked") as ImageTexture).get_image()
	var on_image := (check.get_theme_icon("checked") as ImageTexture).get_image()
	assert(off_image.get_size() == Vector2i(ControlSize.md, ControlSize.md))
	assert(on_image.get_size() == off_image.get_size())
	var stroke_pixel := Vector2i(off_image.get_used_rect().position.x, off_image.get_height() / 2)
	assert(colors_match(off_image.get_pixelv(stroke_pixel), Colors.secondary_text))
	assert(colors_match(on_image.get_pixelv(stroke_pixel), accent))
	# Outlined switch, not a filled track: the inside of the pill stays transparent.
	assert(off_image.get_pixelv(off_image.get_size() / 2).a == 0.0)
	# The switch alone is icon-tall; the control claims the md tier so its hover fill lines up with the
	# fields beside it, and stays centred instead of stretching inside a taller row.
	assert(check.custom_minimum_size.y == ControlSize.md)
	assert(check.size_flags_vertical == Control.SIZE_SHRINK_CENTER)

	var normal := check.get_theme_stylebox("normal") as StyleBoxFlat
	assert(normal.bg_color.a == 0.0)
	assert(normal.content_margin_top == Margin.ma_1)
	assert(normal.content_margin_right == Margin.ma_2)
	assert(normal.content_margin_bottom == Margin.ma_1)
	assert(normal.content_margin_left == Margin.ma_2)
	for quiet: String in ["pressed", "focus", "disabled"]:
		assert((check.get_theme_stylebox(quiet) as StyleBoxFlat).bg_color.a == 0.0)
	var hover := check.get_theme_stylebox("hover") as StyleBoxFlat
	assert(hover.bg_color == ThemeColor.selected_surface)
	assert(hover.get_margin(SIDE_LEFT) == normal.get_margin(SIDE_LEFT))
	assert((check.get_theme_stylebox("hover_pressed") as StyleBoxFlat).bg_color == hover.bg_color)
	check.free()
	pass


## Rasterized icon pixels pass through an 8-bit image, so palette comparisons allow one quantization step.
func colors_match(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) <= 0.01 and absf(actual.g - expected.g) <= 0.01 and absf(actual.b - expected.b) <= 0.01
