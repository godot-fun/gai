class_name ThemeToggle
extends RefCounted

## Circular toolbar button for switching dark / light color schemes.

const SUN_ICON_PATH: String = "res://agent/asset/image/ui/light_mode.svg"
const MOON_ICON_PATH: String = "res://agent/asset/image/ui/dark_mode.svg"

var button: Button


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(p_button: Button) -> void:
	button = p_button
	button.pressed.connect(on_pressed)
	button.mouse_entered.connect(on_mouse_entered)
	button.mouse_exited.connect(on_mouse_exited)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_theme)
	apply_theme()
	pass


# ---------------------------------------------------------------------------
# Theme
# ---------------------------------------------------------------------------

func apply_theme() -> void:
	var tooltip: String = I18n.t("agent.toolbar.light_theme") if ThemeColor.is_dark_theme() else I18n.t("agent.toolbar.dark_theme")
	AgentToolbarButton.style_round(button, tooltip)
	update_icon(button.is_hovered())
	pass


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func on_pressed() -> void:
	ThemeColor.toggle_theme()
	pass


func on_mouse_entered() -> void:
	update_icon(true)
	pass


func on_mouse_exited() -> void:
	update_icon(false)
	pass


# ---------------------------------------------------------------------------
# Icons
# ---------------------------------------------------------------------------

func update_icon(hovered: bool) -> void:
	var show_moon: bool = ThemeColor.is_light_theme()
	if show_moon:
		var moon_color: Color = ThemeColor.accent_theme_color()
		if hovered:
			moon_color = moon_color.lightened(0.12)
		button.icon = ImageHelper.tint_svg(MOON_ICON_PATH, moon_color, 2.0)
		return
	var sun_color: Color = ThemeColor.accent_theme_color().darkened(0.18)
	if hovered:
		sun_color = sun_color.lightened(0.12)
	button.icon = ImageHelper.tint_svg(SUN_ICON_PATH, sun_color, 2.0)
	pass
