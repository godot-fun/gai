class_name SearchButton
extends RefCounted

## Toolbar entry point for session chat search.

const SEARCH_ICON_PATH := "res://agent/asset/image/icon/search.svg"

var button: Button


func setup(p_button: Button) -> void:
	button = p_button
	button.shortcut = make_shortcut(KEY_F, true)
	button.pressed.connect(on_button_pressed)
	button.mouse_entered.connect(on_mouse_entered)
	button.mouse_exited.connect(on_mouse_exited)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_theme)
	apply_theme()
	pass


func make_shortcut(keycode: Key, ctrl_pressed: bool = false) -> Shortcut:
	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	key_event.ctrl_pressed = ctrl_pressed
	var shortcut := Shortcut.new()
	shortcut.events = [key_event]
	return shortcut


func on_button_pressed() -> void:
	SearchWindow.show_search()
	pass


func on_mouse_entered() -> void:
	update_icon(true)
	pass


func on_mouse_exited() -> void:
	update_icon(false)
	pass


func apply_theme() -> void:
	AgentToolbarButton.style_round(button, I18n.t("agent.search.tooltip"))
	update_icon(button.is_hovered())
	pass


func update_icon(hovered: bool) -> void:
	button.icon = make_icon(SEARCH_ICON_PATH, Colors.primary_text if hovered else Colors.secondary_text)
	pass


func make_icon(path: String, color: Color) -> ImageTexture:
	var svg := FileAccess.get_file_as_string(path)
	svg = svg.replace("#" + Color.WHITE.to_html(false), "#" + color.to_html(false))
	var image := Image.new()
	if image.load_svg_from_string(svg, 2.0) != OK:
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)
