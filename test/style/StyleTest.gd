## Unit tests for [StyleBoxHelper], [ButtonStyle], [Margin], [DisplayScale] and the builders that go through them.

const GRAY := Color(0.5, 0.5, 0.5)


## [method DisplayScale.compute_ui_scale] maps main-window pixels to viewport units, clamped to 0.5–4.0.
func DisplayScale_compute_ui_scale_test() -> void:
	var scale := DisplayScale.compute_ui_scale()
	assert(scale >= 0.5 and scale <= 4.0)
	pass


## [method DisplayScale.compute_screen_scale] is usable width / 2K reference under the anchor.
func DisplayScale_compute_screen_scale_test() -> void:
	var anchor := Vector2i(200, 300)
	var screen := DisplayServer.get_screen_from_rect(Rect2(Vector2(anchor), Vector2.ONE))
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var expected := float(usable.size.x) / float(DisplayScale.REF_SCREEN_WIDTH) if usable.size.x > 0 else 1.0
	assert(is_equal_approx(DisplayScale.compute_screen_scale(anchor), expected))
	pass


func ColorBase_follow_theme_test() -> void:
	var original := ThemeColor.current_theme
	ThemeColor.current_theme = ThemeColor.ThemeEnum.DARK
	ThemeColor.refresh_derived_colors()
	assert(ColorBase.app_background == ColorBase.DARK_BACKGROUND)
	assert(ColorBase.deep_surface == ColorBase.DARK_DEEP_SURFACE)
	assert(ColorBase.chrome_surface == ColorBase.DARK_CHROME_SURFACE)
	assert(ColorBase.control_surface == ColorBase.DARK_CONTROL_SURFACE)
	assert(ColorBase.surface == ColorBase.DARK_SURFACE)
	assert(ColorBase.hover_surface == ColorBase.DARK_HOVER_SURFACE)
	assert(ColorBase.elevated_surface == ColorBase.DARK_ELEVATED_SURFACE)
	assert(ColorBase.border == ColorBase.DARK_BORDER)
	assert(ColorBase.muted_border == ColorBase.DARK_MUTED_BORDER)
	assert(ColorBase.subtle_border == ColorBase.DARK_SUBTLE_BORDER)
	assert(ColorBase.primary_text == ColorBase.DARK_TEXT)
	assert(ColorBase.secondary_text == ColorBase.DARK_MUTED)
	assert(ColorBase.error == ColorBase.DARK_ERROR)
	assert(ColorBase.info == ColorBase.DARK_INFO)
	assert(ColorBase.warning == ColorBase.DARK_WARNING)
	assert(ColorBase.success == ColorBase.DARK_SUCCESS)
	assert(ColorBase.teal == ColorBase.DARK_TEAL)
	assert(ColorBase.purple == ColorBase.DARK_PURPLE)
	assert(ColorBase.strong_info_surface == ColorBase.DARK_STRONG_INFO_SURFACE)
	assert(ColorBase.info_surface == ColorBase.DARK_INFO_SURFACE)
	assert(ColorBase.purple_surface == ColorBase.DARK_PURPLE_SURFACE)
	assert(ColorBase.success_surface == ColorBase.DARK_SUCCESS_SURFACE)
	assert(ColorBase.warning_surface == ColorBase.DARK_WARNING_SURFACE)
	assert(ColorBase.neutral_surface == ColorBase.DARK_NEUTRAL_SURFACE)
	assert(ThemeColor.selected_surface == ThemeColor.DARK_SELECTED_SURFACE_BASE.lerp(ThemeColor.accent_theme_color(), ThemeColor.DARK_SELECTED_SURFACE_MIX))

	ThemeColor.current_theme = ThemeColor.ThemeEnum.LIGHT
	ThemeColor.refresh_derived_colors()
	assert(ColorBase.app_background == ColorBase.LIGHT_BACKGROUND)
	assert(ColorBase.deep_surface == ColorBase.LIGHT_DEEP_SURFACE)
	assert(ColorBase.chrome_surface == ColorBase.LIGHT_CHROME_SURFACE)
	assert(ColorBase.control_surface == ColorBase.LIGHT_CONTROL_SURFACE)
	assert(ColorBase.surface == ColorBase.LIGHT_SURFACE)
	assert(ColorBase.hover_surface == ColorBase.LIGHT_HOVER_SURFACE)
	assert(ColorBase.elevated_surface == ColorBase.LIGHT_ELEVATED_SURFACE)
	assert(ColorBase.border == ColorBase.LIGHT_BORDER)
	assert(ColorBase.muted_border == ColorBase.LIGHT_MUTED_BORDER)
	assert(ColorBase.subtle_border == ColorBase.LIGHT_SUBTLE_BORDER)
	assert(ColorBase.primary_text == ColorBase.LIGHT_TEXT)
	assert(ColorBase.secondary_text == ColorBase.LIGHT_MUTED)
	assert(ColorBase.error == ColorBase.LIGHT_ERROR)
	assert(ColorBase.info == ColorBase.LIGHT_INFO)
	assert(ColorBase.warning == ColorBase.LIGHT_WARNING)
	assert(ColorBase.success == ColorBase.LIGHT_SUCCESS)
	assert(ColorBase.teal == ColorBase.LIGHT_TEAL)
	assert(ColorBase.purple == ColorBase.LIGHT_PURPLE)
	assert(ColorBase.strong_info_surface == ColorBase.LIGHT_STRONG_INFO_SURFACE)
	assert(ColorBase.info_surface == ColorBase.LIGHT_INFO_SURFACE)
	assert(ColorBase.purple_surface == ColorBase.LIGHT_PURPLE_SURFACE)
	assert(ColorBase.success_surface == ColorBase.LIGHT_SUCCESS_SURFACE)
	assert(ColorBase.warning_surface == ColorBase.LIGHT_WARNING_SURFACE)
	assert(ColorBase.neutral_surface == ColorBase.LIGHT_NEUTRAL_SURFACE)
	assert(ThemeColor.selected_surface == ThemeColor.LIGHT_SELECTED_SURFACE_BASE.lerp(ThemeColor.accent_theme_color(), ThemeColor.LIGHT_SELECTED_SURFACE_MIX))

	ThemeColor.current_theme = original
	ThemeColor.refresh_derived_colors()
	pass


## The whole point of the helper: the same call keeps contrast on both themes.
func ButtonStyle_color_direction_test() -> void:
	var original: ThemeColor.ThemeEnum = ThemeColor.current_theme

	ThemeColor.current_theme = ThemeColor.ThemeEnum.DARK
	assert(ButtonStyle.hover_color(GRAY, 0.10) == GRAY.lightened(0.10))
	assert(ButtonStyle.press_color(GRAY, 0.06) == GRAY.darkened(0.06))

	ThemeColor.current_theme = ThemeColor.ThemeEnum.LIGHT
	assert(ButtonStyle.hover_color(GRAY, 0.10) == GRAY.darkened(0.10))
	assert(ButtonStyle.press_color(GRAY, 0.06) == GRAY.lightened(0.06))

	ThemeColor.current_theme = original
	pass


func ButtonStyle_with_alpha_test() -> void:
	var tinted := Color(ColorBase.info, 0.45)
	# `Color` stores 32-bit floats, so compare approximately.
	assert(is_equal_approx(tinted.a, 0.45))
	assert(tinted.r == ColorBase.info.r and tinted.b == ColorBase.info.b)
	pass


func StyleBoxHelper_create_style_box_flat_test() -> void:
	var style := StyleBoxHelper.create_style_box_flat(Color(0.1, 0.2, 0.3), 8, Margin.ma_2, Margin.ma_1, ColorBase.info, 1)
	assert(style.bg_color == Color(0.1, 0.2, 0.3))
	assert(style.corner_radius_top_left == 8 and style.corner_radius_bottom_right == 8)
	assert(style.get_margin(SIDE_LEFT) == Margin.ma_2 and style.get_margin(SIDE_RIGHT) == Margin.ma_2)
	assert(style.get_margin(SIDE_TOP) == Margin.ma_1 and style.get_margin(SIDE_BOTTOM) == Margin.ma_1)
	assert(style.border_width_left == 1 and style.border_color == ColorBase.info)

	# No border width means no border at all, so a caller that does not want one keeps the default.
	var plain := StyleBoxHelper.create_style_box_flat(Color.WHITE, 4)
	assert(plain.border_width_left == 0 and plain.get_margin(SIDE_LEFT) == 0.0)
	pass


func StyleBoxHelper_apply_style_box_margin_test() -> void:
	var style := StyleBoxHelper.create_style_box_flat(Color.WHITE, 4)
	StyleBoxHelper.apply_style_box_margin(style, Margin.ma_3, Margin.ma_2, Margin.ma_1, Margin.ma_0)
	assert(style.get_margin(SIDE_LEFT) == Margin.ma_3 and style.get_margin(SIDE_RIGHT) == Margin.ma_1)
	assert(style.get_margin(SIDE_TOP) == Margin.ma_2 and style.get_margin(SIDE_BOTTOM) == Margin.ma_0)

	# Base class on purpose: an empty box takes the same padding as a filled one.
	var empty := StyleBoxEmpty.new()
	StyleBoxHelper.apply_style_box_margin(empty, Margin.ma_1, Margin.ma_1, Margin.ma_1, Margin.ma_1)
	assert(empty.get_margin(SIDE_LEFT) == Margin.ma_1)
	pass


## The snackbar shadow is the one card value that cannot be a plain token: the same alpha over a dark
## surface and over a light one reads as either nothing or a smudge.
func Alert_card_shadow_test() -> void:
	var original: ThemeColor.ThemeEnum = ThemeColor.current_theme

	ThemeColor.current_theme = ThemeColor.ThemeEnum.DARK
	var dark := Alert.make_card_style(ColorBase.info)
	ThemeColor.current_theme = ThemeColor.ThemeEnum.LIGHT
	var light := Alert.make_card_style(ColorBase.info)
	assert(is_equal_approx(dark.shadow_color.a, Alert.shadow_alpha_dark))
	assert(is_equal_approx(light.shadow_color.a, Alert.shadow_alpha_light))
	assert(dark.shadow_color.a > light.shadow_color.a)
	assert(light.shadow_size == Alert.shadow_size)
	assert(light.shadow_offset == Alert.shadow_offset)

	ThemeColor.current_theme = original
	pass


## Both feedback cards use the accent surface; the snackbar frames both edges while the desktop toast
## only marks the leading one.
func card_components_test() -> void:
	var snackbar := Alert.make_card_style(ColorBase.success)
	assert(snackbar.corner_radius_top_left == ControlSize.radius_md)
	assert(snackbar.border_width_left == ControlSize.border_md)
	assert(snackbar.shadow_size == Alert.shadow_size)

	var scale := DisplayScale.compute_ui_scale()
	var toast: DesktopToast = DesktopToast.new()
	toast.accent = ColorBase.success
	toast.build_card()
	var toast_card: StyleBoxFlat = toast.card.get_theme_stylebox("panel") as StyleBoxFlat
	assert(toast_card.bg_color == snackbar.bg_color)
	assert(toast_card.border_color == snackbar.border_color)
	assert(toast_card.border_width_left == roundi(ControlSize.border_md * scale))
	assert(toast_card.border_width_right == 0)
	assert(toast_card.get_margin(SIDE_RIGHT) == Margin.ma_5 * scale)
	toast.free()
	pass


## Every state box is a copy of the normal one with a new fill, so the border, padding and corners
## only have to be written once — this is the copy that keeps them.
func ButtonStyle_filled_test() -> void:
	var normal := StyleBoxHelper.create_style_box_flat(Color(0.2, 0.2, 0.2), 6, Margin.ma_2, Margin.ma_1, Color.WHITE, 1)
	var hover := ButtonStyle.filled(normal, Color(0.3, 0.3, 0.3))
	assert(hover.bg_color == Color(0.3, 0.3, 0.3))
	assert(hover.border_color == normal.border_color and hover.get_margin(SIDE_LEFT) == Margin.ma_2)
	assert(hover.corner_radius_top_left == 6)
	assert(normal.bg_color == Color(0.2, 0.2, 0.2))

	# A border color is only written when one is given, so a state keeps the normal outline by default.
	var outlined := ButtonStyle.filled(normal, Color(0.3, 0.3, 0.3), Color.RED)
	assert(outlined.border_color == Color.RED and normal.border_color == Color.WHITE)
	pass


## A missed `hover_pressed` override resolves to the *default theme* box, not to `pressed`,
## so the helper has to set it. This is what that regression looked like.
func ButtonStyle_apply_test() -> void:
	var normal := StyleBoxHelper.create_style_box_flat(Color(0.2, 0.2, 0.2), 6, Margin.ma_2, Margin.ma_1, Color.WHITE, 1)
	var hover := ButtonStyle.filled(normal, Color(0.3, 0.3, 0.3))
	var pressed := ButtonStyle.filled(normal, Color(0.1, 0.1, 0.1))

	var button := Button.new()
	ButtonStyle.apply(button, normal, hover, pressed)
	assert(button.get_theme_stylebox("normal") == normal)
	assert(button.get_theme_stylebox("hover") == hover)
	assert(button.get_theme_stylebox("pressed") == pressed)
	assert((button.get_theme_stylebox("focus") as StyleBoxFlat).bg_color == hover.bg_color)
	assert((button.get_theme_stylebox("disabled") as StyleBoxFlat).bg_color == normal.bg_color)
	assert((button.get_theme_stylebox("hover_pressed") as StyleBoxFlat).bg_color == pressed.bg_color)

	var bare := Button.new()
	bare.add_theme_stylebox_override("pressed", pressed)
	assert(bare.get_theme_stylebox("hover_pressed") != pressed)

	button.free()
	bare.free()
	pass


## Same hole on the text side: the default theme paints focus and hover-pressed text near white,
## so a button that only overrides normal / hover / pressed goes blank on a light surface.
func ButtonStyle_apply_font_colors_test() -> void:
	var button := Button.new()
	ButtonStyle.apply_font_colors(button, Color.BLACK, Color.RED, Color.GREEN)
	assert(button.get_theme_color("font_color") == Color.BLACK)
	assert(button.get_theme_color("font_hover_color") == Color.RED)
	assert(button.get_theme_color("font_pressed_color") == Color.GREEN)
	assert(button.get_theme_color("font_focus_color") == Color.RED)
	assert(button.get_theme_color("font_hover_pressed_color") == Color.GREEN)
	assert(button.get_theme_color("font_disabled_color") == Color(Color.BLACK, 0.5))
	button.free()
	pass
