class_name Typography
extends Object

## Material Design text scale: font size in px and six shared letter-spacing tiers in px.
##
## Both sizes and letter spacing are ints because Godot theme font sizes and
## [member FontVariation.spacing_glyph] use integer pixels. Pick one of the shared spacing tiers
## instead of defining spacing separately for every text role.
## Typical use:
## [codeblock]
## label.add_theme_font_size_override("font_size", Typography.title_medium_size)
##
## var variation := FontVariation.new()
## variation.spacing_glyph = Typography.letter_spacing_xs
## label.add_theme_font_override("font", variation)
## [/codeblock]

## Smallest letter spacing: compact body text and labels.
const letter_spacing_xs: int = 1
## Compact letter spacing: emphasized labels and short headings.
const letter_spacing_sm: int = 2
## Default letter spacing: logos and display text that benefits from a wider rhythm.
const letter_spacing_md: int = 3
## Prominent letter spacing: short uppercase headings and compact branding.
const letter_spacing_lg: int = 4
## Wide letter spacing: display labels and decorative headings.
const letter_spacing_xl: int = 5
## Widest letter spacing: sparse branding and highly emphasized display text.
const letter_spacing_xxl: int = 6

# ----------------------------------------------------------------------------------------------------------------------
# display
const display_large_size: int = 57
const display_medium_size: int = 45
const display_small_size: int = 36

# ----------------------------------------------------------------------------------------------------------------------
# headline
const headline_large_size: int = 32
const headline_medium_size: int = 28
const headline_small_size: int = 24

# ----------------------------------------------------------------------------------------------------------------------
# title
const title_large_size: int = 22
const title_medium_size: int = 16
const title_small_size: int = 14

# ----------------------------------------------------------------------------------------------------------------------
# body
const body_large_size: int = 16
const body_medium_size: int = 14
const body_small_size: int = 12

# ----------------------------------------------------------------------------------------------------------------------
# label
const label_large_size: int = 14
const label_medium_size: int = 12
const label_small_size: int = 11
