class_name SearchButton
extends RefCounted

## Toolbar entry point for session chat search.

const SEARCH_ICON_PATH := "res://agent/asset/image/ui/search.svg"

var button: Button


func setup(p_button: Button) -> void:
	button = p_button
	button.pressed.connect(on_button_pressed)
	button.mouse_entered.connect(on_mouse_entered)
	button.mouse_exited.connect(on_mouse_exited)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_theme)
	AgentEvents.events.search_shortcut_changed.connect(on_search_shortcut_changed)
	apply_shortcut()
	apply_theme()
	pass


func on_search_shortcut_changed() -> void:
	apply_shortcut()
	button.tooltip_text = search_tooltip()
	pass


func apply_shortcut() -> void:
	button.shortcut = ShortcutSetting.make_search_shortcut()
	pass


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
	AgentToolbarButton.style_round(button, search_tooltip())
	update_icon(button.is_hovered())
	pass


func search_tooltip() -> String:
	return I18n.t("agent.search.tooltip") + " (" + OS.get_keycode_string(ShortcutSetting.get_search_shortcut()) + ")"


func update_icon(hovered: bool) -> void:
	button.icon = ImageHelper.tint_svg(SEARCH_ICON_PATH, Colors.primary_text if hovered else Colors.secondary_text, 2.0)
	pass
