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
	apply_equal_icon_margins(Margin.ma_1)
	button.text = ""
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_constant_override("icon_max_width", ControlSize.xs)
	button.add_theme_constant_override("icon_max_height", ControlSize.xs)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	update_icon(button.is_hovered())
	pass


func apply_equal_icon_margins(margin: int) -> void:
	for state_name: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state_name) as StyleBoxFlat
		if box == null:
			continue
		box.content_margin_left = margin
		box.content_margin_right = margin
		box.content_margin_top = margin
		box.content_margin_bottom = margin
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
	var icon_color: Color = ColorBase.secondary_text
	if show_moon:
		icon_color = ThemeColor.accent_theme_color()
	if hovered:
		if icon_color == ColorBase.secondary_text:
			icon_color = ColorBase.primary_text
		else:
			icon_color = icon_color.lightened(0.12)
	button.icon = make_icon(icon_color, show_moon)
	pass


func make_icon(color: Color, show_moon: bool) -> ImageTexture:
	if show_moon:
		return make_moon_icon(color)
	return make_sun_icon(color)


func make_sun_icon(color: Color) -> ImageTexture:
	return svg_to_texture(SUN_ICON_PATH, color)


func make_moon_icon(color: Color) -> ImageTexture:
	return svg_to_texture(MOON_ICON_PATH, color)


func svg_to_texture(path: String, color: Color) -> ImageTexture:
	var svg: String = FileAccess.get_file_as_string(path)
	svg = svg.replace("#" + Color.WHITE.to_html(false), "#" + color.to_html(false))
	var image: Image = Image.new()
	if image.load_svg_from_string(svg, 2.0) != OK:
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)
