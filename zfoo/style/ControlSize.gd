class_name ControlSize
extends Object

## Control size scale: control heights, square sizes and shared corner radii, in px.
##
## Six tiers, each one 8px ([code]Margin.ma_2[/code]) above the previous, so every value lands on the
## same 4px grid as the rest of the layout and is a [Margin] step: xs 20 ([code]ma_5[/code]),
## sm 28 ([code]ma_7[/code]), md 36 ([code]ma_9[/code]), lg 44 ([code]ma_11[/code]),
## xl 52, xxl 60.
##
## The tiers are deliberately sparse: a control picks a tier, it does not pick a number. Sizes between
## two tiers are not a missing constant — they are a sign the control should be sitting on one of them.
##
## The values are ints because theme constants and minimum sizes ask for ints; int to float is a
## lossless conversion, so they also go straight into `custom_minimum_size`. There is no scale factor
## on purpose: the viewport already scales the whole UI (project stretch mode [code]canvas_items[/code]).
##
## Typical use:
## [codeblock]
## button.custom_minimum_size = ControlSize.square(ControlSize.sm)   # 28×28 icon button
## field.custom_minimum_size = Vector2(0, ControlSize.md)            # input that stretches horizontally
## [/codeblock]

## Smallest tier: inline chips, tags and the tiny icon buttons inside a row of text.
const xs: int = 20
## Compact tier: toolbar and row-action buttons, the 28×28 icon button most of the chrome is built on.
const sm: int = 28
## Default tier: the button, select and input of a normal form.
const md: int = 36
## Prominent tier: dialog fields and primary actions that should read above the form around them.
const lg: int = 44
## Hero tier: search bar, send button, collapsed input bar.
const xl: int = 52
## Tallest tier: showcase buttons and large controls that anchor a panel.
const xxl: int = 60


## Icon size scale for artwork inside controls. Keep this separate from control sizes so the
## visible glyph can be smaller than its clickable area.
const icon_xs: int = 12
const icon_sm: int = 16
const icon_md: int = 20
const icon_lg: int = 24
const icon_xl: int = 28
const icon_xxl: int = 32


## Corner radius scale for controls and surfaces.
const radius_xs: int = 2
const radius_sm: int = 4
const radius_md: int = 6
const radius_lg: int = 8
const radius_xl: int = 12
const radius_xxl: int = 16


## Border thickness scale for separators, outlines and accents.
const border_xs: int = 1
const border_sm: int = 2
const border_md: int = 3
const border_lg: int = 4
const border_xl: int = 5
const border_xxl: int = 6


## Image width scale for thumbnails, previews and content artwork.
const image_xs: int = 160
const image_sm: int = 240
const image_md: int = 320
const image_lg: int = 480
const image_xl: int = 640
const image_xxl: int = 800


## Both axes at one tier, for the square icon buttons that make up most of the chrome.
static func square(size: int) -> Vector2:
	return Vector2(size, size)
