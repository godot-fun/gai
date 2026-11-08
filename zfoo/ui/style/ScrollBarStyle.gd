class_name ScrollBarStyle
extends Object

## Scrollbar thickness presets in pixels.
enum Thickness {
	## Hairline scrollbar: low-priority inset areas and compact previews.
	XS = 1,
	## Slim scrollbar: dense lists where the thumb should stay quiet.
	SM = 2,
	## Compact scrollbar: secondary panels such as search results.
	MD = 3,
	## Standard scrollbar: ordinary scrollable controls.
	LG = 4,
	## Prominent scrollbar: large content surfaces needing easier targeting.
	XL = 5,
	## Widest scrollbar: the shared default and accessibility-oriented surfaces.
	XXL = 6,
}

## Shared default used by popup, transcript and sidebar surfaces.
static func apply(bar: ScrollBar, thickness: Thickness = Thickness.XXL) -> void:
	apply_custom(bar, thickness, grabber_color(), grabber_hover_color(), grabber_pressed_color(), false)
	pass


## Resting grabber color: the shared neutral used by every scrollbar in the app.
static func grabber_color() -> Color:
	return ThemeColor.body_color


## Grabber color while the pointer is over the bar.
static func grabber_hover_color() -> Color:
	return ThemeColor.promote(ThemeColor.theme_color, Weights.w_7)


## Grabber color while the bar is dragged.
static func grabber_pressed_color() -> Color:
	return ThemeColor.promote(ThemeColor.theme_color, Weights.w_4)


## Configurable variant for controls whose scrollbar intentionally differs from the shared default.
static func apply_custom(bar: ScrollBar, thickness: Thickness, normal: Color, hover: Color, pressed: Color, rounded: bool = false) -> void:
	var scroll := bar.get_theme_stylebox("scroll").duplicate() as StyleBoxFlat
	scroll.bg_color = Color(0, 0, 0, 0)
	bar.add_theme_stylebox_override("scroll", scroll)
	var scroll_focus := bar.get_theme_stylebox("scroll_focus").duplicate() as StyleBoxFlat
	scroll_focus.bg_color = Color(0, 0, 0, 0)
	bar.add_theme_stylebox_override("scroll_focus", scroll_focus)
	var grabber := bar.get_theme_stylebox("grabber").duplicate() as StyleBoxFlat
	grabber.bg_color = normal
	bar.add_theme_stylebox_override("grabber", grabber)
	var grabber_highlight := bar.get_theme_stylebox("grabber_highlight").duplicate() as StyleBoxFlat
	grabber_highlight.bg_color = hover
	bar.add_theme_stylebox_override("grabber_highlight", grabber_highlight)
	var grabber_pressed := bar.get_theme_stylebox("grabber_pressed").duplicate() as StyleBoxFlat
	grabber_pressed.bg_color = pressed
	bar.add_theme_stylebox_override("grabber_pressed", grabber_pressed)
	var half_thickness := DisplayScale.scale_int_floor_min(thickness, DisplayScale.get_ui_scale()) * 0.5
	if rounded:
		var radius := ceili(half_thickness)
		for style: StyleBoxFlat in [grabber, grabber_highlight, grabber_pressed]:
			style.set_corner_radius_all(radius)
	if bar is VScrollBar:
		scroll.content_margin_left = half_thickness
		scroll.content_margin_right = half_thickness
		scroll_focus.content_margin_left = half_thickness
		scroll_focus.content_margin_right = half_thickness
		grabber.content_margin_left = half_thickness
		grabber.content_margin_right = half_thickness
		grabber_highlight.content_margin_left = half_thickness
		grabber_highlight.content_margin_right = half_thickness
		grabber_pressed.content_margin_left = half_thickness
		grabber_pressed.content_margin_right = half_thickness
	else:
		scroll.content_margin_top = half_thickness
		scroll.content_margin_bottom = half_thickness
		scroll_focus.content_margin_top = half_thickness
		scroll_focus.content_margin_bottom = half_thickness
		grabber.content_margin_top = half_thickness
		grabber.content_margin_bottom = half_thickness
		grabber_highlight.content_margin_top = half_thickness
		grabber_highlight.content_margin_bottom = half_thickness
		grabber_pressed.content_margin_top = half_thickness
		grabber_pressed.content_margin_bottom = half_thickness
	pass
