class_name VisualColor
extends Object

## Canvas color helpers for [VisualEffect] `_draw` above chat.
##
## [ThemeColor] and [Colors] cover widgets, surfaces, and semantic UI text. Visuals instead
## paint sparse neon strokes and glows whose **authored alphas assume a dark desktop**. On a
## light chat background those hues and alphas wash out unless they are remapped.
##
## Maintainers
## - **Dark:** keep designer hex / accent hues bright ([method neon_color]); pass line and
##   fill alphas through [method stroke] unchanged (multiplier 1).
## - **Light:** clamp HSV value into the ink band ([method ink_color]); multiply every
##   stroke alpha by [member LIGHT_INK_ALPHA] via [method stroke].
## - **Semantic hues** (e.g. stream types in [ContextMemoryRiver]): [Colors] / [ThemeColor]
##   swatches matched to chat bubbles, then [method appearance_color]. **Accent palettes**
##   (e.g. [CyberCommandDeck] cyan/blue/
##   magenta): call [method neon_color] / [method ink_color] with hue offsets and per-channel
##   sat multipliers in that effect's `sync_palette`.
## - Do not use for solid panel fills that should match [Colors.surface] — only strokes,
##   particles, and tinted glow layers. Fills stay on theme tokens or effect-local `palette_fill`.
## - Reads [member ThemeColor.current_theme] each call; no cache here. Effects may cache derived
##   palettes when accent or multi-stop rebuild is expensive.

## Light-theme stroke alpha scale. Dark visuals use ~0.05–0.2 glow alphas; on white they need ~2×
## apparent opacity without changing the authored numbers in each effect file.
const LIGHT_INK_ALPHA := 2.2
## HSV value clamp for [method ink_color] so lines read as print ink, not LED on paper.
const LIGHT_INK_VALUE_MIN := 0.38
const LIGHT_INK_VALUE_MAX := 0.52
## Dark-theme minimum HSV value before [method neon_color] applies hue/sat offsets.
const NEON_VALUE_FLOOR := 0.72


## Multiplier applied inside [method stroke]. 1 on dark, [member LIGHT_INK_ALPHA] on light.
static func ink_alpha() -> float:
	return 1.0 if ThemeColor.is_dark_theme() else LIGHT_INK_ALPHA


## Wrap an already-resolved RGB with authored overlay alpha. Always route glow polylines,
## arcs, and particle halos through this on light theme; opaque labels clamp at alpha 1.
static func stroke(color: Color, alpha: float) -> Color:
	return Color(color, clampf(alpha * ink_alpha(), 0.0, 1.0))


## Rotate [param base] on the hue wheel and scale saturation/value (visual palette companions).
static func shift_hsv(base: Color, hue_offset: float = 0.0, sat_mul: float = 1.0, val_mul: float = 1.0) -> Color:
	return Color.from_hsv(fposmod(base.h + hue_offset, 1.0), clampf(base.s * sat_mul, 0.0, 1.0), clampf(base.v * val_mul, 0.0, 1.0))


## Dark-theme stroke hue: floor value, then optional hue wheel offset and sat/value scale.
## Matches accent-shifted companions (cool/warm) in command-deck style palettes.
static func neon_color(base: Color, hue_offset: float = 0.0, sat_mul: float = 1.0, val_mul: float = 1.0) -> Color:
	var neon := base
	neon.v = maxf(base.v, NEON_VALUE_FLOOR)
	return shift_hsv(neon, hue_offset, sat_mul, val_mul)


## Light-theme stroke hue: same [param hue_offset] as [method neon_color], but value is scaled
## and clamped into [[member LIGHT_INK_VALUE_MIN], [member LIGHT_INK_VALUE_MAX]]. Slightly
## raises saturation so distinct hues stay separable when value is compressed.
static func ink_color(base: Color, hue_offset: float = 0.0, sat_mul: float = 1.0, value_scale: float = 0.48) -> Color:
	var hue := fposmod(base.h + hue_offset, 1.0)
	var sat := clampf(maxf(base.s, 0.35) * sat_mul, 0.0, 1.0)
	var value := clampf(base.v * value_scale, LIGHT_INK_VALUE_MIN, LIGHT_INK_VALUE_MAX)
	return Color.from_hsv(hue, sat, value)


## Pick [method neon_color] or [method ink_color] from [ThemeColor.is_dark_theme]. Use for a
## single authored swatch per role; pass [param light_sat_mul] / [param dark_sat_mul] when
## mirroring command-deck ink saturation tweaks.
static func appearance_color(base: Color, hue_offset: float = 0.0, dark_sat_mul: float = 1.0, light_sat_mul: float = 1.08) -> Color:
	if ThemeColor.is_dark_theme():
		return neon_color(base, hue_offset, dark_sat_mul)
	return ink_color(base, hue_offset, light_sat_mul)
