class_name ButtonStyle
extends Object

## Button and panel state styling: install the state set a [Button] needs. The boxes themselves
## are built by [StyleBoxHelper]; hover and pressed fills use [method ThemeColor.promote] and
## [method ThemeColor.demote] so contrast stays correct when the theme flips.
##
## Solid fills (accent buttons, shadows) are the exception — those read as plain shading, so they
## keep [method Color.darkened] on every theme.
##
## Typical use:
## [codeblock]
## var normal := StyleBoxHelper.create_style_box_flat(ThemeColor.card_surface, 6, Margin.ma_2, Margin.ma_1, ThemeColor.accent_theme_color(), ControlSize.border_xs)
## ButtonStyle.apply(button, normal,
## 	ButtonStyle.filled(normal, ThemeColor.promote(ThemeColor.card_surface, 0.08)),
## 	ButtonStyle.filled(normal, ThemeColor.inset_surface, ThemeColor.accent_theme_color()))
## [/codeblock]

## A copy of [param base] with a new fill — how the hover / pressed / disabled box of a button is
## derived from its normal box, so the border, padding and corners are written only once.
##
## A transparent [param border_color] keeps the outline of [param base]; pass one only for a state
## whose outline changes. Pass a state box as [param base] when the next state builds on it instead
## of on the normal box.
static func filled(base: StyleBoxFlat, fill: Color, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	style.bg_color = fill
	if border_color != Color.TRANSPARENT:
		style.border_color = border_color
	return style


## Install the button states. [param disabled] falls back to a copy of [param normal] and
## [param hover_pressed] to a copy of [param pressed]; [code]focus[/code] always mirrors
## [param hover].
##
## [param hover_pressed] must not be left out: Godot resolves a missing item from the default
## theme, so a button that only overrides normal / hover / pressed paints the engine's own box
## while it is pressed *and* hovered.
static func apply(
	button: Button,
	normal: StyleBoxFlat,
	hover: StyleBoxFlat,
	pressed: StyleBoxFlat,
	disabled: StyleBoxFlat = null,
	hover_pressed: StyleBoxFlat = null
) -> void:
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover.duplicate() as StyleBoxFlat)
	button.add_theme_stylebox_override("disabled", disabled if disabled != null else normal.duplicate() as StyleBoxFlat)
	button.add_theme_stylebox_override("hover_pressed", hover_pressed if hover_pressed != null else pressed.duplicate() as StyleBoxFlat)
	pass


## Text colors for the same states, one per `font_*_color` theme item: focus mirrors
## [param hover_color] and hover-pressed mirrors [param pressed_color], the same pairing
## [method apply] uses for the boxes.
##
## Those two are not optional — an item left out is resolved from the default theme, whose focus
## and hover-pressed text are near white and would vanish on a light surface.
##
## [param disabled_color] defaults to [param base_color] at half alpha.
static func apply_font_colors(
	button: BaseButton,
	base_color: Color,
	hover_color: Color,
	pressed_color: Color,
	disabled_color: Color = Color.TRANSPARENT
) -> void:
	button.add_theme_color_override("font_color", base_color)
	button.add_theme_color_override("font_hover_color", hover_color)
	button.add_theme_color_override("font_pressed_color", pressed_color)
	button.add_theme_color_override("font_focus_color", hover_color)
	button.add_theme_color_override("font_hover_pressed_color", pressed_color)
	button.add_theme_color_override("font_disabled_color", disabled_color if disabled_color != Color.TRANSPARENT else Color(base_color, 0.5))
	pass
