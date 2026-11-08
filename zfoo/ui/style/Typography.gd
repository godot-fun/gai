class_name Typography
extends Object

## Material Design text scale. Lowercase public values are the live, display-scaled pixel sizes;
## uppercase constants remain the immutable 100% design values used by [method apply_scale].

const LETTER_SPACING_XS := 1
const LETTER_SPACING_SM := 2
const LETTER_SPACING_MD := 3
const LETTER_SPACING_LG := 4
const LETTER_SPACING_XL := 5
const LETTER_SPACING_XXL := 6

const DISPLAY_LARGE := 57
const DISPLAY_MEDIUM := 45
const DISPLAY_SMALL := 36
const HEADLINE_LARGE := 32
const HEADLINE_MEDIUM := 28
const HEADLINE_SMALL := 24
const TITLE_LARGE := 22
const TITLE_MEDIUM := 16
const TITLE_SMALL := 14
const BODY_LARGE := 16
const BODY_MEDIUM := 14
const BODY_SMALL := 12
const LABEL_LARGE := 14
const LABEL_MEDIUM := 12
const LABEL_SMALL := 11

static var letter_spacing_xs: int = LETTER_SPACING_XS
static var letter_spacing_sm: int = LETTER_SPACING_SM
static var letter_spacing_md: int = LETTER_SPACING_MD
static var letter_spacing_lg: int = LETTER_SPACING_LG
static var letter_spacing_xl: int = LETTER_SPACING_XL
static var letter_spacing_xxl: int = LETTER_SPACING_XXL

static var display_large: int = DISPLAY_LARGE
static var display_medium: int = DISPLAY_MEDIUM
static var display_small: int = DISPLAY_SMALL
static var headline_large: int = HEADLINE_LARGE
static var headline_medium: int = HEADLINE_MEDIUM
static var headline_small: int = HEADLINE_SMALL
static var title_large: int = TITLE_LARGE
static var title_medium: int = TITLE_MEDIUM
static var title_small: int = TITLE_SMALL
static var body_large: int = BODY_LARGE
static var body_medium: int = BODY_MEDIUM
static var body_small: int = BODY_SMALL
static var label_large: int = LABEL_LARGE
static var label_medium: int = LABEL_MEDIUM
static var label_small: int = LABEL_SMALL


static func apply_scale(scale: float) -> void:
	letter_spacing_xs = DisplayScale.scale_int_min(LETTER_SPACING_XS, scale)
	letter_spacing_sm = DisplayScale.scale_int_min(LETTER_SPACING_SM, scale)
	letter_spacing_md = DisplayScale.scale_int_min(LETTER_SPACING_MD, scale)
	letter_spacing_lg = DisplayScale.scale_int_min(LETTER_SPACING_LG, scale)
	letter_spacing_xl = DisplayScale.scale_int_min(LETTER_SPACING_XL, scale)
	letter_spacing_xxl = DisplayScale.scale_int_min(LETTER_SPACING_XXL, scale)
	display_large = DisplayScale.scale_int_min(DISPLAY_LARGE, scale)
	display_medium = DisplayScale.scale_int_min(DISPLAY_MEDIUM, scale)
	display_small = DisplayScale.scale_int_min(DISPLAY_SMALL, scale)
	headline_large = DisplayScale.scale_int_min(HEADLINE_LARGE, scale)
	headline_medium = DisplayScale.scale_int_min(HEADLINE_MEDIUM, scale)
	headline_small = DisplayScale.scale_int_min(HEADLINE_SMALL, scale)
	title_large = DisplayScale.scale_int_min(TITLE_LARGE, scale)
	title_medium = DisplayScale.scale_int_min(TITLE_MEDIUM, scale)
	title_small = DisplayScale.scale_int_min(TITLE_SMALL, scale)
	body_large = DisplayScale.scale_int_min(BODY_LARGE, scale)
	body_medium = DisplayScale.scale_int_min(BODY_MEDIUM, scale)
	body_small = DisplayScale.scale_int_min(BODY_SMALL, scale)
	label_large = DisplayScale.scale_int_min(LABEL_LARGE, scale)
	label_medium = DisplayScale.scale_int_min(LABEL_MEDIUM, scale)
	label_small = DisplayScale.scale_int_min(LABEL_SMALL, scale)
	pass
