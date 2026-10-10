class_name ThemeToggle
extends RefCounted

## Circular toolbar button for switching dark / light color schemes.

const SUN_ICON_PATH: String = "res://agent/asset/image/icon/sun.svg"
const MOON_ICON_PATH: String = "res://agent/asset/image/icon/moon.svg"

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
		button.icon = make_moon_icon(moon_color)
		return
	var body: Color = ColorBase.secondary_text
	var rays: Color = ThemeColor.accent_theme_color().darkened(0.18)
	if hovered:
		body = ColorBase.primary_text
		rays = rays.lightened(0.12)
	button.icon = make_sun_icon(body, rays)
	pass


func make_sun_icon(body: Color, rays: Color) -> ImageTexture:
	var svg: String = FileAccess.get_file_as_string(SUN_ICON_PATH)
	svg = svg.replace("#" + Color.BLACK.to_html(false), "#" + body.to_html(false))
	svg = svg.replace("#" + Color.WHITE.to_html(false), "#" + rays.to_html(false))
	return svg_string_to_texture(svg)


func make_moon_icon(color: Color) -> ImageTexture:
	var svg: String = FileAccess.get_file_as_string(MOON_ICON_PATH)
	svg = svg.replace("#" + Color.WHITE.to_html(false), "#" + color.to_html(false))
	return svg_string_to_texture(svg)


func svg_string_to_texture(svg: String) -> ImageTexture:
	var image: Image = Image.new()
	if image.load_svg_from_string(svg, 2.0) != OK:
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)
