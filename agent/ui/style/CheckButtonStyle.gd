class_name CheckButtonStyle
extends Object

## Theme for every [CheckButton] in the app: no chrome at rest, the app's Material switch art tinted
## from the palette, and the accent label ramp shared with the other accent-styled buttons.
##
## This lives beside the app instead of in [ButtonStyle] because the switch glyphs are app assets —
## the reusable zfoo styles stay free of asset paths.
##
## Typical use:
## [codeblock]
## CheckButtonStyle.apply(check)
## [/codeblock]

## Material switch glyphs shared with the rest of the UI icon set. Both are single-color art on a
## square 48 px canvas, so they are re-rasterized per state and tinted through [method ImageHelper.tint_svg].
const SWITCH_ON_PATH := "res://agent/asset/image/ui/toggle_on.svg"
const SWITCH_OFF_PATH := "res://agent/asset/image/ui/toggle_off.svg"
## Native canvas of the switch glyphs; the raster scale maps it onto the md control tier.
const SWITCH_ART_SIZE := 48.0


## Accent at rest, promoted on hover, demoted while pressed — the same ramp
## [method ButtonStyle.apply_font_colors] gives the other accent-styled buttons.
static func apply(check: CheckButton) -> void:
	var accent := ThemeColor.accent_theme_color()
	ButtonStyle.apply_font_colors(check, accent, ThemeColor.promote(accent, Weights.w_2), ThemeColor.demote(accent, Weights.w_2))
	# The icons are rasterized with their tint baked in, so the engine modulate must stay neutral.
	check.add_theme_color_override("button_checked_color", Color.WHITE)
	check.add_theme_color_override("button_unchecked_color", Color.WHITE)
	var scale := float(ControlSize.md) / SWITCH_ART_SIZE
	check.add_theme_icon_override("checked", ImageHelper.tint_svg(SWITCH_ON_PATH, accent, scale))
	check.add_theme_icon_override("unchecked", ImageHelper.tint_svg(SWITCH_OFF_PATH, Colors.secondary_text, scale))
	check.add_theme_icon_override("checked_disabled", ImageHelper.tint_svg(SWITCH_ON_PATH, Colors.disabled_text, scale))
	check.add_theme_icon_override("unchecked_disabled", ImageHelper.tint_svg(SWITCH_OFF_PATH, Colors.disabled_text, scale))
	check.add_theme_constant_override("h_separation", Margin.ma_2)
	# The switch alone is only as tall as its icon, which would leave the hover fill visibly shorter than
	# the md-tall fields it sits next to. Claim the shared control tier and keep it centred so every
	# check button answers the pointer with the same pill, whatever row it lands in.
	check.custom_minimum_size.y = ControlSize.md
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# A toggle reports its checked state through the same "pressed" draw mode a held-down button uses,
	# so a pressed fill would paint every switched-on check button permanently. Only the hover pair is
	# safe to fill: it is the one state pair that never doubles as "checked".
	# The switch icon also has a single color per checked state and ignores hover, so an icon-only
	# toggle needs that hover fill to show any feedback at all.
	#
	# The box is chrome-less at rest: transparent, padded just enough for the hover fill to read as a
	# pill. Padding is shared by every state so the footprint never shifts on hover. Uses the
	# top / right / bottom / left order of [method StyleBoxHelper.apply_margin].
	var box := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, ControlSize.radius_md)
	StyleBoxHelper.apply_margin(box, Margin.ma_1, Margin.ma_2, Margin.ma_1, Margin.ma_2)
	var hover := ButtonStyle.theme_hover_style_for(box)
	check.add_theme_stylebox_override("normal", box)
	check.add_theme_stylebox_override("disabled", box.duplicate())
	check.add_theme_stylebox_override("focus", box.duplicate())
	check.add_theme_stylebox_override("pressed", box.duplicate())
	check.add_theme_stylebox_override("hover", hover)
	check.add_theme_stylebox_override("hover_pressed", hover.duplicate())
	pass
