class_name ControlSize
extends Object

## Shared UI size tokens for controls, icons, corner radii, borders and image previews, in px.
##
## The control tiers follow Vuetify and Material button sizing: xs 20, sm 28, md 36, lg 44 and
## xl 52 are separated by 8px ([code]Margin.ma_2[/code]) and align to the shared 4px layout grid.
## xxl 60 extends that scale for prominent desktop controls. Icon artwork has its own smaller scale
## so a control's visible glyph remains smaller than its clickable area.
##
## The tiers are deliberately sparse: a control picks a tier, it does not pick a number. Sizes between
## two tiers are not a missing constant — they are a sign the control should be sitting on one of them.
##
## Public values are live display pixels. [method apply_scale] always recalculates them from the
## immutable 100% design constants, avoiding cumulative rounding when the user changes scale.
##
## Typical use:
## [codeblock]
## button.custom_minimum_size = ControlSize.square(ControlSize.sm)   # 28×28 icon button
## field.custom_minimum_size = Vector2(0, ControlSize.md)            # input that stretches horizontally
## [/codeblock]

## Smallest tier: inline chips, tags and the tiny icon buttons inside a row of text.
const XS := 20
const SM := 28
const MD := 36
const LG := 44
const XL := 52
const XXL := 60
const ICON_XS := 12
const ICON_SM := 16
const ICON_MD := 20
const ICON_LG := 24
const ICON_XL := 28
const ICON_XXL := 32
const RADIUS_XS := 2
const RADIUS_SM := 4
const RADIUS_MD := 6
const RADIUS_LG := 8
const RADIUS_XL := 12
const RADIUS_XXL := 16
const BORDER_XS := 1
const BORDER_SM := 2
const BORDER_MD := 3
const BORDER_LG := 4
const BORDER_XL := 5
const BORDER_XXL := 6
const IMAGE_XS := 160
const IMAGE_SM := 240
const IMAGE_MD := 320
const IMAGE_LG := 480
const IMAGE_XL := 640
const IMAGE_XXL := 800

static var xs: int = XS
## Compact tier: toolbar and row-action buttons, the 28×28 icon button most of the chrome is built on.
static var sm: int = SM
## Default tier: the button, select and input of a normal form.
static var md: int = MD
## Prominent tier: dialog fields and primary actions that should read above the form around them.
static var lg: int = LG
## Hero tier: search bar, send button, collapsed input bar.
static var xl: int = XL
## Tallest tier: showcase buttons and large controls that anchor a panel.
static var xxl: int = XXL


## Icon size scale for artwork inside controls. Keep this separate from control sizes so the
## visible glyph can be smaller than its clickable area.
static var icon_xs: int = ICON_XS
static var icon_sm: int = ICON_SM
static var icon_md: int = ICON_MD
static var icon_lg: int = ICON_LG
static var icon_xl: int = ICON_XL
static var icon_xxl: int = ICON_XXL


## Corner radius scale for controls and surfaces.
static var radius_xs: int = RADIUS_XS
static var radius_sm: int = RADIUS_SM
static var radius_md: int = RADIUS_MD
static var radius_lg: int = RADIUS_LG
static var radius_xl: int = RADIUS_XL
static var radius_xxl: int = RADIUS_XXL


## Border thickness scale for separators, outlines and accents.
static var border_xs: int = BORDER_XS
static var border_sm: int = BORDER_SM
static var border_md: int = BORDER_MD
static var border_lg: int = BORDER_LG
static var border_xl: int = BORDER_XL
static var border_xxl: int = BORDER_XXL


## Image width scale for thumbnails, previews and content artwork.
static var image_xs: int = IMAGE_XS
static var image_sm: int = IMAGE_SM
static var image_md: int = IMAGE_MD
static var image_lg: int = IMAGE_LG
static var image_xl: int = IMAGE_XL
static var image_xxl: int = IMAGE_XXL


static func apply_scale(scale: float) -> void:
	xs = DisplayScale.scale_int_min(XS, scale)
	sm = DisplayScale.scale_int_min(SM, scale)
	md = DisplayScale.scale_int_min(MD, scale)
	lg = DisplayScale.scale_int_min(LG, scale)
	xl = DisplayScale.scale_int_min(XL, scale)
	xxl = DisplayScale.scale_int_min(XXL, scale)
	icon_xs = DisplayScale.scale_int_min(ICON_XS, scale)
	icon_sm = DisplayScale.scale_int_min(ICON_SM, scale)
	icon_md = DisplayScale.scale_int_min(ICON_MD, scale)
	icon_lg = DisplayScale.scale_int_min(ICON_LG, scale)
	icon_xl = DisplayScale.scale_int_min(ICON_XL, scale)
	icon_xxl = DisplayScale.scale_int_min(ICON_XXL, scale)
	radius_xs = DisplayScale.scale_int_min(RADIUS_XS, scale)
	radius_sm = DisplayScale.scale_int_min(RADIUS_SM, scale)
	radius_md = DisplayScale.scale_int_min(RADIUS_MD, scale)
	radius_lg = DisplayScale.scale_int_min(RADIUS_LG, scale)
	radius_xl = DisplayScale.scale_int_min(RADIUS_XL, scale)
	radius_xxl = DisplayScale.scale_int_min(RADIUS_XXL, scale)
	border_xs = DisplayScale.scale_int_floor_min(BORDER_XS, scale)
	border_sm = DisplayScale.scale_int_floor_min(BORDER_SM, scale)
	border_md = DisplayScale.scale_int_floor_min(BORDER_MD, scale)
	border_lg = DisplayScale.scale_int_floor_min(BORDER_LG, scale)
	border_xl = DisplayScale.scale_int_floor_min(BORDER_XL, scale)
	border_xxl = DisplayScale.scale_int_floor_min(BORDER_XXL, scale)
	image_xs = DisplayScale.scale_int_min(IMAGE_XS, scale)
	image_sm = DisplayScale.scale_int_min(IMAGE_SM, scale)
	image_md = DisplayScale.scale_int_min(IMAGE_MD, scale)
	image_lg = DisplayScale.scale_int_min(IMAGE_LG, scale)
	image_xl = DisplayScale.scale_int_min(IMAGE_XL, scale)
	image_xxl = DisplayScale.scale_int_min(IMAGE_XXL, scale)
	pass


## Both axes at one tier, for the square icon buttons that make up most of the chrome.
static func square(size: int) -> Vector2:
	return Vector2(size, size)
