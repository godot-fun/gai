class_name NoteButton
extends RefCounted

## Toolbar entry point for the Note app.

var button: Button


func setup(p_button: Button) -> void:
	button = p_button
	button.pressed.connect(on_button_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_theme)
	apply_theme()
	pass


func on_button_pressed() -> void:
	NoteWindow.show_note()
	pass


func apply_theme() -> void:
	AgentToolbarButton.style(button, I18n.t("note.tooltip"))
	button.text = I18n.t("note.title")
	pass
