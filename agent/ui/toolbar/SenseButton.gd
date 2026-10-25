class_name SenseButton
extends RefCounted

## Toolbar entry point for Sense settings.

var button: Button
var sense_input: SenseInput


func setup(p_button: Button, p_sense_input: SenseInput) -> void:
	button = p_button
	sense_input = p_sense_input
	button.pressed.connect(on_button_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_theme)
	apply_theme()
	pass


func on_button_pressed() -> void:
	SenseWindow.show_sense(sense_input)
	pass


func apply_theme() -> void:
	AgentToolbarButton.style(button, I18n.t("agent.sense.settings_tooltip"))
	button.text = "Sense"
	pass
