class_name ThemeColor
extends Object

# Theme ---------------------------------------------------------------------------------------------------------------
const THEME_SETTING_KEY := "theme"

enum ThemeEnum {
	DARK,
	LIGHT,
}

static var current_theme: ThemeEnum = ThemeEnum.DARK


static func init() -> void:
	load_theme()
	load_theme_color()
	pass


static func load_theme() -> ThemeEnum:
	var use_dark := Setting.get_bool(THEME_SETTING_KEY, true)
	current_theme = ThemeEnum.DARK if use_dark else ThemeEnum.LIGHT
	refresh_derived_colors()
	return current_theme


static func set_theme(new_theme: ThemeEnum) -> void:
	current_theme = new_theme
	Setting.set_bool(THEME_SETTING_KEY, current_theme == ThemeEnum.DARK)
	Setting.save()
	refresh_derived_colors()
	gdf.events.theme_changed.emit()
	pass


static func toggle_theme() -> void:
	set_theme(ThemeEnum.LIGHT if is_dark_theme() else ThemeEnum.DARK)
	pass


static func is_dark_theme() -> bool:
	return current_theme == ThemeEnum.DARK


static func is_light_theme() -> bool:
	return current_theme == ThemeEnum.LIGHT


# Color ---------------------------------------------------------------------------------------------------------------
const THEME_COLOR_SETTING_KEY := "theme_color"
const DEFAULT_THEME_COLOR := Color(0.0, 0.84, 0.68, 0.58)

## Accent-derived card tones keep a fixed brightness per appearance so every selectable hue
## preserves readable contrast.
const SURFACE_SATURATION_DARK := 0.30
const SURFACE_SATURATION_LIGHT := 0.12
const SURFACE_VALUE_DARK := 0.15
const SURFACE_VALUE_LIGHT := 0.97
const INSET_SATURATION_DARK := 0.24
const INSET_SATURATION_LIGHT := 0.08
const INSET_VALUE_DARK := 0.10
const INSET_VALUE_LIGHT := 0.93
const CARD_SATURATION_DARK := 0.27
const CARD_SATURATION_LIGHT := 0.10
const CARD_VALUE_DARK := 0.16
const CARD_VALUE_LIGHT := 0.87
const DARK_SELECTED_SURFACE_BASE := Color(0.14, 0.15, 0.18)
const LIGHT_SELECTED_SURFACE_BASE := Color(1.00, 1.00, 1.00)
const DARK_SELECTED_SURFACE_MIX := 0.14
const LIGHT_SELECTED_SURFACE_MIX := 0.16
const TITLE_SATURATION_DARK := 0.12
const TITLE_SATURATION_LIGHT := 0.20
const TITLE_VALUE_DARK := 0.94
const TITLE_VALUE_LIGHT := 0.16
const BODY_SATURATION_DARK := 0.20
const BODY_SATURATION_LIGHT := 0.28
const BODY_VALUE_DARK := 0.68
const BODY_VALUE_LIGHT := 0.42
const SELECTION_MIX := 0.30

## User-selected accent color; its alpha is preserved for translucent theme effects.
static var theme_color: Color = DEFAULT_THEME_COLOR
## Background for floating windows and outer panels.
static var accent_surface: Color = Colors.DARK_SURFACE
## Background for content areas inside those panels.
static var inset_surface := Color(0.09, 0.10, 0.12)
## Background for cards inside a content area.
static var card_surface := Color(0.14, 0.15, 0.18)
## Large-area surface color for selected rows, nodes and pressed controls.
static var selected_surface: Color = DARK_SELECTED_SURFACE_BASE
## High-contrast primary text color displayed on accent-derived card surfaces.
static var title_color: Color = Colors.DARK_TEXT
## Lower-emphasis secondary text and resting control color on accent-derived surfaces.
static var body_color: Color = Colors.DARK_MUTED
## Text-selection background color used by editable and selectable text controls.
static var selection_color := Color(0.12, 0.29, 0.25)


static func load_theme_color() -> Color:
	var saved := Setting.get_string(THEME_COLOR_SETTING_KEY)
	theme_color = DEFAULT_THEME_COLOR if saved.is_empty() else Color.from_string(saved, DEFAULT_THEME_COLOR)
	refresh_derived_colors()
	return theme_color


static func set_theme_color(color: Color) -> void:
	theme_color = color
	Setting.set_string(THEME_COLOR_SETTING_KEY, theme_color.to_html(true))
	Setting.save()
	refresh_derived_colors()
	gdf.events.theme_color_changed.emit()
	pass


## Current theme color with alpha forced to 1 for UI highlights and controls.
static func accent_theme_color() -> Color:
	return Color(theme_color, 1.0)

## Current theme color with the specified alpha for translucent accent effects.
static func alpha_theme_color(alpha: float) -> Color:
	return Color(theme_color, alpha)


## Increase a color's visual emphasis against the active theme background.
## Dark themes lighten the color; light themes darken it. [param amount] uses the same `0.0` to
## `1.0` adjustment ratio as [method Color.lightened] and [method Color.darkened].
static func emphasize(color: Color, amount: float) -> Color:
	return color.lightened(amount) if is_dark_theme() else color.darkened(amount)


## Refresh every palette derived from the active appearance. Cards follow the accent hue; semantic,
## markdown and file colors select their hand-tuned dark or light variants.
static func refresh_derived_colors() -> void:
	refresh_theme_colors()
	Colors.refresh()
	MarkdownColors.refresh()
	CodeColors.refresh()
	FileColors.refresh()
	pass


## Recompute every color derived from [member theme_color].
static func refresh_theme_colors() -> void:
	var dark := is_dark_theme()
	accent_surface = derive_theme_color(SURFACE_SATURATION_DARK if dark else SURFACE_SATURATION_LIGHT, SURFACE_VALUE_DARK if dark else SURFACE_VALUE_LIGHT)
	inset_surface = derive_theme_color(INSET_SATURATION_DARK if dark else INSET_SATURATION_LIGHT, INSET_VALUE_DARK if dark else INSET_VALUE_LIGHT)
	card_surface = derive_theme_color(CARD_SATURATION_DARK if dark else CARD_SATURATION_LIGHT, CARD_VALUE_DARK if dark else CARD_VALUE_LIGHT)
	title_color = derive_theme_color(TITLE_SATURATION_DARK if dark else TITLE_SATURATION_LIGHT, TITLE_VALUE_DARK if dark else TITLE_VALUE_LIGHT)
	body_color = derive_theme_color(BODY_SATURATION_DARK if dark else BODY_SATURATION_LIGHT, BODY_VALUE_DARK if dark else BODY_VALUE_LIGHT)
	selection_color = inset_surface.lerp(accent_theme_color(), SELECTION_MIX)
	var selected_surface_base := DARK_SELECTED_SURFACE_BASE if dark else LIGHT_SELECTED_SURFACE_BASE
	selected_surface = selected_surface_base.lerp(accent_theme_color(), DARK_SELECTED_SURFACE_MIX if dark else LIGHT_SELECTED_SURFACE_MIX)
	pass


static func derive_theme_color(saturation: float, value: float) -> Color:
	return Color.from_hsv(theme_color.h, clampf(theme_color.s * saturation, 0.0, 1.0), value, 1.0)
