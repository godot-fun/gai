class_name SettingButton
extends RefCounted

## Toolbar control that opens the agent settings window.

const SETTINGS_ICON_PATH: String = "res://agent/asset/image/icon/settings.svg"

var button: Button


func setup(p_button: Button) -> void:
	button = p_button
	button.pressed.connect(on_button_pressed)
	button.mouse_entered.connect(on_mouse_entered)
	button.mouse_exited.connect(on_mouse_exited)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_theme)
	apply_theme()
	pass


func on_button_pressed() -> void:
	AgentSettingWindow.show_setting()
	pass


func on_mouse_entered() -> void:
	update_icon(true)
	pass


func on_mouse_exited() -> void:
	update_icon(false)
	pass


func apply_theme() -> void:
	AgentToolbarButton.style_round(button, I18n.t("agent.settings.tooltip"))
	update_icon(button.is_hovered())
	pass


func update_icon(hovered: bool) -> void:
	var icon_color := Colors.primary_text if hovered else Colors.secondary_text
	button.icon = make_icon(icon_color)
	pass


func make_icon(color: Color) -> ImageTexture:
	var svg := FileAccess.get_file_as_string(SETTINGS_ICON_PATH)
	svg = svg.replace("#" + Color.WHITE.to_html(false), "#" + color.to_html(false))
	var image := Image.new()
	if image.load_svg_from_string(svg, 2.0) != OK:
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)
