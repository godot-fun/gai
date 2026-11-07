class_name WorkflowButton
extends RefCounted

## Toolbar entry point for the standalone workflow window.

var button: Button


func setup(p_button: Button) -> void:
	button = p_button
	button.pressed.connect(on_button_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_theme)
	apply_theme()
	pass


func apply_theme() -> void:
	AgentToolbarButton.style(button, I18n.t("agent.toolbar.open_workflow"))
	pass


func on_button_pressed() -> void:
	WorkflowWindow.show_workflow()
	pass
