class_name Colors
extends Object


# =============================================================================
# Color adjustment ratios
# =============================================================================

## Shared adjustment ratios for [method Color.lightened] and [method Color.darkened].
const am_0: float = 0.00
const am_1: float = 0.05
const am_2: float = 0.10
const am_3: float = 0.15
const am_4: float = 0.20
const am_5: float = 0.25
const am_6: float = 0.30
const am_7: float = 0.35
const am_8: float = 0.40
const am_9: float = 0.45
const am_10: float = 0.50
const am_11: float = 0.55
const am_12: float = 0.60


# =============================================================================
# Neutral application colors
# =============================================================================

## Shared foundation for neutral colors used by framework palettes and application themes.
## Component and business-specific colors belong in their own palette.
const DARK_BACKGROUND := Color(0.07, 0.08, 0.10)
const DARK_DEEP_SURFACE := Color(0.06, 0.07, 0.09)
const DARK_CHROME_SURFACE := Color(0.10, 0.11, 0.13)
const DARK_CONTROL_SURFACE := Color(0.11, 0.12, 0.15)
const DARK_SURFACE := Color(0.12, 0.13, 0.16)
const DARK_HOVER_SURFACE := DARK_SURFACE
const DARK_ELEVATED_SURFACE := Color(0.14, 0.15, 0.18)
const DARK_BORDER := Color(0.22, 0.24, 0.28)
const DARK_MUTED_BORDER := Color(0.18, 0.20, 0.24)
const DARK_SUBTLE_BORDER := Color(0.16, 0.18, 0.22)
const DARK_TEXT := Color(0.90, 0.91, 0.93)
const DARK_MUTED := Color(0.55, 0.57, 0.62)

const LIGHT_BACKGROUND := Color(0.98, 0.98, 0.98)
const LIGHT_DEEP_SURFACE := Color(0.91, 0.92, 0.94)
const LIGHT_CHROME_SURFACE := Color(0.95, 0.95, 0.96)
const LIGHT_CONTROL_SURFACE := Color(0.96, 0.96, 0.96)
const LIGHT_SURFACE := Color(1.00, 1.00, 1.00)
const LIGHT_HOVER_SURFACE := Color(0.91, 0.92, 0.93)
const LIGHT_ELEVATED_SURFACE := LIGHT_SURFACE
const LIGHT_BORDER := Color(0.84, 0.85, 0.87)
const LIGHT_MUTED_BORDER := Color(0.86, 0.87, 0.89)
const LIGHT_SUBTLE_BORDER := Color(0.87, 0.88, 0.90)
const LIGHT_TEXT := Color(0.09, 0.09, 0.11)
const LIGHT_MUTED := Color(0.42, 0.42, 0.46)

## Main application canvas behind panels and content.
static var app_background: Color = DARK_BACKGROUND
## Deepest application layer, used by chrome that should sit behind adjacent regions, such as a toolbar.
static var deep_surface: Color = DARK_DEEP_SURFACE
## Application chrome surface: persistent navigation and framing regions such as a sidebar.
## Here, "chrome" means application frame/navigation UI, not the Chrome browser.
static var chrome_surface: Color = DARK_CHROME_SURFACE
## Resting fill for interactive controls such as toolbar buttons and fields.
static var control_surface: Color = DARK_CONTROL_SURFACE
## Default panel, dialog and content-card surface.
static var surface: Color = DARK_SURFACE
## Shared hover fill for controls and selectable rows.
static var hover_surface: Color = DARK_HOVER_SURFACE
## Surface visually raised above [member surface]; also the base for selected rows.
static var elevated_surface: Color = DARK_ELEVATED_SURFACE
## Strong outline for panels and chat bubbles.
static var border: Color = DARK_BORDER
## Quieter outline for application chrome such as sidebars.
static var muted_border: Color = DARK_MUTED_BORDER
## Lightest outline for compact controls and toolbar elements.
static var subtle_border: Color = DARK_SUBTLE_BORDER
## Primary and secondary foreground text colors.
static var primary_text: Color = DARK_TEXT
static var secondary_text: Color = DARK_MUTED


# =============================================================================
# Semantic foreground colors
# =============================================================================

## Semantic colors are brighter on dark surfaces and darker on pale surfaces.
const DARK_ERROR := Color(0.85, 0.30, 0.30)
const DARK_INFO := Color(0.35, 0.65, 0.95)
const DARK_WARNING := Color(1.00, 0.65, 0.30)
const DARK_SUCCESS := Color(0.30, 0.78, 0.45)
const DARK_PURPLE := Color(0.72, 0.58, 0.88)
const DARK_LIGHT_BLUE := Color(0.05, 0.48, 0.75)

const LIGHT_ERROR := Color(0.86, 0.15, 0.15)
const LIGHT_INFO := Color(0.15, 0.39, 0.92)
const LIGHT_WARNING := Color(0.72, 0.28, 0.02)
const LIGHT_SUCCESS := Color(0.05, 0.50, 0.20)
const LIGHT_PURPLE := Color(0.49, 0.23, 0.93)
const LIGHT_LIGHT_BLUE := Color(0.35, 0.75, 0.95)

## Active semantic foreground colors. Use these for text, icons and status marks.
static var error: Color = DARK_ERROR
static var info: Color = DARK_INFO
static var warning: Color = DARK_WARNING
static var success: Color = DARK_SUCCESS
static var purple: Color = DARK_PURPLE
static var light_blue: Color = DARK_LIGHT_BLUE


# =============================================================================
# Semantic surface colors
# =============================================================================

## Semantic surfaces keep status/category fills readable without using strong text colors as fills.
const DARK_INFO_SURFACE := Color(0.10, 0.13, 0.19)
const DARK_PURPLE_SURFACE := Color(0.19, 0.18, 0.30)
const DARK_SUCCESS_SURFACE := Color(0.14, 0.20, 0.16)
const DARK_WARNING_SURFACE := Color(0.22, 0.16, 0.10)
const DARK_NEUTRAL_SURFACE := Color(0.13, 0.16, 0.20)

const LIGHT_INFO_SURFACE := Color(0.95, 0.97, 0.99)
const LIGHT_PURPLE_SURFACE := Color(0.96, 0.95, 1.00)
const LIGHT_SUCCESS_SURFACE := Color(0.94, 0.99, 0.96)
const LIGHT_WARNING_SURFACE := Color(1.00, 0.97, 0.93)
const LIGHT_NEUTRAL_SURFACE := Color(0.94, 0.95, 0.97)

## Low-emphasis semantic fills paired with their matching foreground colors above.
static var info_surface: Color = DARK_INFO_SURFACE
static var purple_surface: Color = DARK_PURPLE_SURFACE
static var success_surface: Color = DARK_SUCCESS_SURFACE
static var warning_surface: Color = DARK_WARNING_SURFACE
## Status-neutral fill for output and result content.
static var neutral_surface: Color = DARK_NEUTRAL_SURFACE


# =============================================================================
# Theme refresh
# =============================================================================

## Select neutral and semantic colors with suitable contrast for the current theme.
static func refresh() -> void:
	var dark := ThemeColor.is_dark_theme()
	app_background = DARK_BACKGROUND if dark else LIGHT_BACKGROUND
	deep_surface = DARK_DEEP_SURFACE if dark else LIGHT_DEEP_SURFACE
	chrome_surface = DARK_CHROME_SURFACE if dark else LIGHT_CHROME_SURFACE
	control_surface = DARK_CONTROL_SURFACE if dark else LIGHT_CONTROL_SURFACE
	surface = DARK_SURFACE if dark else LIGHT_SURFACE
	hover_surface = DARK_HOVER_SURFACE if dark else LIGHT_HOVER_SURFACE
	elevated_surface = DARK_ELEVATED_SURFACE if dark else LIGHT_ELEVATED_SURFACE
	border = DARK_BORDER if dark else LIGHT_BORDER
	muted_border = DARK_MUTED_BORDER if dark else LIGHT_MUTED_BORDER
	subtle_border = DARK_SUBTLE_BORDER if dark else LIGHT_SUBTLE_BORDER
	primary_text = DARK_TEXT if dark else LIGHT_TEXT
	secondary_text = DARK_MUTED if dark else LIGHT_MUTED
	error = DARK_ERROR if dark else LIGHT_ERROR
	info = DARK_INFO if dark else LIGHT_INFO
	warning = DARK_WARNING if dark else LIGHT_WARNING
	success = DARK_SUCCESS if dark else LIGHT_SUCCESS
	purple = DARK_PURPLE if dark else LIGHT_PURPLE
	light_blue = DARK_LIGHT_BLUE if dark else LIGHT_LIGHT_BLUE
	info_surface = DARK_INFO_SURFACE if dark else LIGHT_INFO_SURFACE
	purple_surface = DARK_PURPLE_SURFACE if dark else LIGHT_PURPLE_SURFACE
	success_surface = DARK_SUCCESS_SURFACE if dark else LIGHT_SUCCESS_SURFACE
	warning_surface = DARK_WARNING_SURFACE if dark else LIGHT_WARNING_SURFACE
	neutral_surface = DARK_NEUTRAL_SURFACE if dark else LIGHT_NEUTRAL_SURFACE
	pass
