extends RefCounted


static func shift_hsv_test() -> void:
	var base := Color.from_hsv(0.10, 0.50, 0.80)
	var shifted := VisualColor.shift_hsv(base, 0.25, 0.50, 0.50)
	assert(is_equal_approx(shifted.h, 0.35))
	assert(is_equal_approx(shifted.s, 0.25))
	assert(is_equal_approx(shifted.v, 0.40))
	var wrapped := VisualColor.shift_hsv(Color.from_hsv(0.90, 1.0, 1.0), 0.20)
	assert(is_equal_approx(wrapped.h, 0.10))
	pass


static func appearance_color_respects_theme_test() -> void:
	var base := Color("59c8ff")
	var original := ThemeColor.current_theme
	ThemeColor.current_theme = ThemeColor.ThemeEnum.DARK
	assert(VisualColor.ink_alpha() == 1.0)
	var dark := VisualColor.appearance_color(base)
	ThemeColor.current_theme = ThemeColor.ThemeEnum.LIGHT
	assert(is_equal_approx(VisualColor.ink_alpha(), VisualColor.LIGHT_INK_ALPHA))
	var light := VisualColor.appearance_color(base)
	var stroked := VisualColor.stroke(base, 0.5)
	ThemeColor.current_theme = original
	assert(dark.v >= VisualColor.NEON_VALUE_FLOOR)
	assert(light.v >= VisualColor.LIGHT_INK_VALUE_MIN)
	assert(light.v <= VisualColor.LIGHT_INK_VALUE_MAX)
	assert(stroked.a == 1.0)
	pass
