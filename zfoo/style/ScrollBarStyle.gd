class_name ScrollBarStyle
extends Object

## Hairline scrollbar: low-priority inset areas and compact previews.
const thickness_xs: int = 1
## Slim scrollbar: dense lists where the thumb should stay quiet.
const thickness_sm: int = 2
## Compact scrollbar: secondary panels such as search results.
const thickness_md: int = 3
## Standard scrollbar: ordinary scrollable controls.
const thickness_lg: int = 4
## Prominent scrollbar: large content surfaces needing easier targeting.
const thickness_xl: int = 5
## Widest scrollbar: the shared default and accessibility-oriented surfaces.
const thickness_xxl: int = 6

## Shared default used by popup, transcript and sidebar surfaces.
static func apply(bar: ScrollBar) -> void:
	apply_custom(bar, thickness_xxl, ThemeColor.body_color, ThemeColor.promote(ThemeColor.theme_color, Weights.w_7), ThemeColor.promote(ThemeColor.theme_color, Weights.w_4), false)
	pass


## Configurable variant for controls whose scrollbar intentionally differs from the shared default.
static func apply_custom(bar: ScrollBar, thickness: int, grabber_color: Color, grabber_highlight_color: Color, grabber_pressed_color: Color, rounded: bool = false) -> void:
	var scroll := bar.get_theme_stylebox("scroll").duplicate() as StyleBoxFlat
	scroll.bg_color = Color(0, 0, 0, 0)
	bar.add_theme_stylebox_override("scroll", scroll)
	var scroll_focus := bar.get_theme_stylebox("scroll_focus").duplicate() as StyleBoxFlat
	scroll_focus.bg_color = Color(0, 0, 0, 0)
	bar.add_theme_stylebox_override("scroll_focus", scroll_focus)
	var grabber := bar.get_theme_stylebox("grabber").duplicate() as StyleBoxFlat
	grabber.bg_color = grabber_color
	bar.add_theme_stylebox_override("grabber", grabber)
	var grabber_highlight := bar.get_theme_stylebox("grabber_highlight").duplicate() as StyleBoxFlat
	grabber_highlight.bg_color = grabber_highlight_color
	bar.add_theme_stylebox_override("grabber_highlight", grabber_highlight)
	var grabber_pressed := bar.get_theme_stylebox("grabber_pressed").duplicate() as StyleBoxFlat
	grabber_pressed.bg_color = grabber_pressed_color
	bar.add_theme_stylebox_override("grabber_pressed", grabber_pressed)
	var half_thickness := maxi(thickness, 1) * 0.5
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
