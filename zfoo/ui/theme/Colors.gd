class_name Colors
extends Object


# =============================================================================
# Neutral application colors
# =============================================================================

## Shared foundation for neutral colors used by framework palettes and application themes.
## Component and business-specific colors belong in their own palette.

# Dark canvas ---------------------------------------------------------------------------------------------------------
const DARK_BACKGROUND := Color(0.07, 0.08, 0.10)

# Dark surfaces -------------------------------------------------------------------------------------------------------
## Recessed chrome (toolbars, etc.): noticeably darker than [constant DARK_BACKGROUND] so layers read on near-black UI.
const DARK_DEEP_SURFACE := Color(0.04, 0.05, 0.07)
const DARK_CONTROL_SURFACE := Color(0.11, 0.12, 0.15)
const DARK_CHROME_SURFACE := Color(0.10, 0.11, 0.13)

# Dark content surfaces -----------------------------------------------------------------------------------------------
## Default dark content surface (#202124).
const DARK_SURFACE := Color(0.13, 0.13, 0.14)
## Material-style content layers, ordered from subtle grouping to strongest nested emphasis.
const DARK_SURFACE_CONTAINER := Color(1.0, 1.0, 1.0, 0.08)
const DARK_SURFACE_CONTAINER_HIGH := Color(0.15, 0.16, 0.18)
const DARK_SURFACE_CONTAINER_HIGHEST := Color(0.45, 0.47, 0.52, 0.18)
const DARK_SURFACE_CONTAINER_OUTLINE_VARIANT := Color(0.35, 0.36, 0.41)

# Dark borders --------------------------------------------------------------------------------------------------------
const DARK_BORDER := Color(0.22, 0.24, 0.28)
const DARK_MUTED_BORDER := Color(0.18, 0.20, 0.24)
const DARK_SUBTLE_BORDER := Color(0.16, 0.18, 0.22)

# Dark text -----------------------------------------------------------------------------------------------------------
const DARK_TEXT := Color(0.91, 0.92, 0.93) # #E8EAED
const DARK_SECONDARY_TEXT := Color(0.60, 0.63, 0.65) # #9AA0A6
const DARK_DISABLED := Color(0.37, 0.39, 0.41) # #5F6368

# Light canvas --------------------------------------------------------------------------------------------------------
const LIGHT_BACKGROUND := Color(0.98, 0.98, 0.98)

# Light surfaces ------------------------------------------------------------------------------------------------------
const LIGHT_DEEP_SURFACE := Color(0.91, 0.92, 0.94)
const LIGHT_CONTROL_SURFACE := Color(0.96, 0.96, 0.96)
const LIGHT_CHROME_SURFACE := Color(0.95, 0.95, 0.96)

# Light content surfaces ----------------------------------------------------------------------------------------------
## Default light content surface (#FFFFFF).
const LIGHT_SURFACE := Color(1.00, 1.00, 1.00)
const LIGHT_SURFACE_CONTAINER := Color(0.0, 0.0, 0.0, 0.05)
const LIGHT_SURFACE_CONTAINER_HIGH := Color(0.45, 0.47, 0.52, 0.18)
const LIGHT_SURFACE_CONTAINER_HIGHEST := Color(0.96, 0.965, 0.97)
const LIGHT_SURFACE_CONTAINER_OUTLINE_VARIANT := Color(0.78, 0.79, 0.82)

# Light borders -------------------------------------------------------------------------------------------------------
const LIGHT_BORDER := Color(0.84, 0.85, 0.87)
const LIGHT_MUTED_BORDER := Color(0.86, 0.87, 0.89)
const LIGHT_SUBTLE_BORDER := Color(0.87, 0.88, 0.90)

# Light text ----------------------------------------------------------------------------------------------------------
const LIGHT_TEXT := Color(0.13, 0.13, 0.14) # #202124
const LIGHT_SECONDARY_TEXT := Color(0.37, 0.39, 0.41) # #5F6368
const LIGHT_DISABLED := Color(0.60, 0.63, 0.65) # #9AA0A6

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │  app_background  — main window canvas behind everything                     │
# │  ┌───────────────────────────────────────────────────────────────────────┐  │
# │  │ deep_surface  — recessed strip “behind” neighbors (toolbars)          │  │
# │  │ (subtle_border)                                                       │  │
# │  │  [control_surface]  buttons · fields · icon toggles on the toolbar    │  │
# │  └───────────────────────────────────────────────────────────────────────┘  │
# │  ┌────────────────┬──────────────────────────────────────────────────────┐  │
# │  │ chrome_surface │  surface  — main content panel / editor / chat area  │  │
# │  │ (muted_border) │                                                      │  │
# │  │                │  surface_container → high → highest                  │  │
# │  │                │  (surface_container_outline_variant)                 │  │
# │  │                │  ┌──────────────────────────────────────────────────┐│  │
# │  │  sidebar /     │  │ surface_container_high — raised content panel    ││  │
# │  │  nav rail /    │  │                                                  ││  │
# │  │  app frame     │  │  primary_text · secondary_text · disabled_text   ││  │
# │  │                │  └──────────────────────────────────────────────────┘│  │
# │  │  list rows:    │                                                      │  │
# │  │  surface →     │  inline controls still use control_surface           │  │
# │  │  hover(surface)│                                                      │  │
# │  │  on hover      │                                                      │  │
# │  └────────────────┴──────────────────────────────────────────────────────┘  │
# └─────────────────────────────────────────────────────────────────────────────┘
# Canvas --------------------------------------------------------------------------------------------------------------
## Main application canvas behind panels and content.
static var app_background: Color = DARK_BACKGROUND

# Surfaces ------------------------------------------------------------------------------------------------------------
## Deepest application layer, used by chrome that should sit behind adjacent regions, such as a toolbar.
static var deep_surface: Color = DARK_DEEP_SURFACE
## Resting fill for interactive controls such as toolbar buttons and fields.
static var control_surface: Color = DARK_CONTROL_SURFACE
## Application chrome surface: persistent navigation and framing regions such as a sidebar.
## Here, "chrome" means application frame/navigation UI, not the Chrome browser.
static var chrome_surface: Color = DARK_CHROME_SURFACE

# Content surfaces ----------------------------------------------------------------------------------------------------
## Default panel, dialog and content-card surface.
static var surface: Color = DARK_SURFACE
## Material-style neutral containers for nested content such as tables and code.
static var surface_container: Color = DARK_SURFACE_CONTAINER
static var surface_container_high: Color = DARK_SURFACE_CONTAINER_HIGH
static var surface_container_highest: Color = DARK_SURFACE_CONTAINER_HIGHEST
## Decorative boundaries and dividers paired with surface containers.
static var surface_container_outline_variant: Color = DARK_SURFACE_CONTAINER_OUTLINE_VARIANT

# Borders -------------------------------------------------------------------------------------------------------------
## Strong outline for panels and chat bubbles.
static var border: Color = DARK_BORDER
## Quieter outline for application chrome such as sidebars.
static var muted_border: Color = DARK_MUTED_BORDER
## Lightest outline for compact controls and toolbar elements.
static var subtle_border: Color = DARK_SUBTLE_BORDER

# Text ----------------------------------------------------------------------------------------------------------------
## Chrome-style primary, secondary, and disabled foreground roles.
static var primary_text: Color = DARK_TEXT
static var secondary_text: Color = DARK_SECONDARY_TEXT
static var disabled_text: Color = DARK_DISABLED

# Interaction states --------------------------------------------------------------------------------------------------
const HOVER_STATE_OPACITY := 0.08

## Material-style hover state layer: blend the active foreground over the component's own base.
static func hover(base: Color) -> Color:
	return base.blend(Color(primary_text, HOVER_STATE_OPACITY))


# =============================================================================
# Semantic foreground colors
# =============================================================================

## Semantic colors are brighter on dark surfaces and darker on pale surfaces.
const DARK_INFO := Color(0.35, 0.65, 0.95)
const DARK_SUCCESS := Color(0.30, 0.78, 0.45)
const DARK_WARNING := Color(1.00, 0.65, 0.30)
const DARK_ERROR := Color(0.85, 0.30, 0.30)
const DARK_PURPLE := Color(0.72, 0.58, 0.88)

const LIGHT_INFO := Color(0.15, 0.39, 0.92)
const LIGHT_SUCCESS := Color(0.05, 0.50, 0.20)
const LIGHT_WARNING := Color(0.72, 0.28, 0.02)
const LIGHT_ERROR := Color(0.86, 0.15, 0.15)
const LIGHT_PURPLE := Color(0.49, 0.23, 0.93)

## Active semantic foreground colors. Use these for text, icons and status marks.
static var info: Color = DARK_INFO
static var success: Color = DARK_SUCCESS
static var warning: Color = DARK_WARNING
static var error: Color = DARK_ERROR
static var purple: Color = DARK_PURPLE


# =============================================================================
# Semantic surface colors
# =============================================================================

## Semantic surfaces keep status/category fills readable without using strong text colors as fills.
const DARK_INFO_SURFACE := Color(0.10, 0.17, 0.22)
const DARK_SUCCESS_SURFACE := Color(0.14, 0.20, 0.16)
const DARK_WARNING_SURFACE := Color(0.22, 0.16, 0.10)
const DARK_ERROR_SURFACE := Color(0.25, 0.12, 0.14)
const DARK_BLUE_GREY_SURFACE := Color(0.13, 0.16, 0.20)
const DARK_GREY_SURFACE := Color(0.13, 0.13, 0.15)
const DARK_PURPLE_SURFACE := Color(0.19, 0.18, 0.30)
const DARK_LIME_SURFACE := Color(0.16, 0.22, 0.10)

const LIGHT_INFO_SURFACE := Color(0.93, 0.98, 1.00)
const LIGHT_SUCCESS_SURFACE := Color(0.94, 0.99, 0.96)
const LIGHT_WARNING_SURFACE := Color(1.00, 0.97, 0.93)
const LIGHT_ERROR_SURFACE := Color(1.00, 0.92, 0.92)
const LIGHT_BLUE_GREY_SURFACE := Color(0.94, 0.95, 0.97)
const LIGHT_GREY_SURFACE := Color(0.95, 0.95, 0.95)
const LIGHT_PURPLE_SURFACE := Color(0.96, 0.95, 1.00)
const LIGHT_LIME_SURFACE := Color(0.96, 1.00, 0.92)

## Low-emphasis semantic fills paired with their matching foreground colors above.
static var info_surface: Color = DARK_INFO_SURFACE
static var success_surface: Color = DARK_SUCCESS_SURFACE
static var warning_surface: Color = DARK_WARNING_SURFACE
static var error_surface: Color = DARK_ERROR_SURFACE
static var blue_grey_surface: Color = DARK_BLUE_GREY_SURFACE
static var grey_surface: Color = DARK_GREY_SURFACE
static var purple_surface: Color = DARK_PURPLE_SURFACE
static var lime_surface: Color = DARK_LIME_SURFACE


# =============================================================================
# Theme refresh
# =============================================================================

static func _static_init() -> void:
	refresh()
	pass


## Select neutral and semantic colors with suitable contrast for the current theme.
static func refresh() -> void:
	var dark := ThemeColor.is_dark_theme()
	app_background = DARK_BACKGROUND if dark else LIGHT_BACKGROUND
	deep_surface = DARK_DEEP_SURFACE if dark else LIGHT_DEEP_SURFACE
	control_surface = DARK_CONTROL_SURFACE if dark else LIGHT_CONTROL_SURFACE
	chrome_surface = DARK_CHROME_SURFACE if dark else LIGHT_CHROME_SURFACE
	surface = DARK_SURFACE if dark else LIGHT_SURFACE
	surface_container = DARK_SURFACE_CONTAINER if dark else LIGHT_SURFACE_CONTAINER
	surface_container_high = DARK_SURFACE_CONTAINER_HIGH if dark else LIGHT_SURFACE_CONTAINER_HIGH
	surface_container_highest = DARK_SURFACE_CONTAINER_HIGHEST if dark else LIGHT_SURFACE_CONTAINER_HIGHEST
	surface_container_outline_variant = DARK_SURFACE_CONTAINER_OUTLINE_VARIANT if dark else LIGHT_SURFACE_CONTAINER_OUTLINE_VARIANT
	border = DARK_BORDER if dark else LIGHT_BORDER
	muted_border = DARK_MUTED_BORDER if dark else LIGHT_MUTED_BORDER
	subtle_border = DARK_SUBTLE_BORDER if dark else LIGHT_SUBTLE_BORDER
	primary_text = DARK_TEXT if dark else LIGHT_TEXT
	secondary_text = DARK_SECONDARY_TEXT if dark else LIGHT_SECONDARY_TEXT
	disabled_text = DARK_DISABLED if dark else LIGHT_DISABLED
	info = DARK_INFO if dark else LIGHT_INFO
	success = DARK_SUCCESS if dark else LIGHT_SUCCESS
	warning = DARK_WARNING if dark else LIGHT_WARNING
	error = DARK_ERROR if dark else LIGHT_ERROR
	purple = DARK_PURPLE if dark else LIGHT_PURPLE
	info_surface = DARK_INFO_SURFACE if dark else LIGHT_INFO_SURFACE
	success_surface = DARK_SUCCESS_SURFACE if dark else LIGHT_SUCCESS_SURFACE
	warning_surface = DARK_WARNING_SURFACE if dark else LIGHT_WARNING_SURFACE
	error_surface = DARK_ERROR_SURFACE if dark else LIGHT_ERROR_SURFACE
	blue_grey_surface = DARK_BLUE_GREY_SURFACE if dark else LIGHT_BLUE_GREY_SURFACE
	grey_surface = DARK_GREY_SURFACE if dark else LIGHT_GREY_SURFACE
	purple_surface = DARK_PURPLE_SURFACE if dark else LIGHT_PURPLE_SURFACE
	lime_surface = DARK_LIME_SURFACE if dark else LIGHT_LIME_SURFACE
	pass
