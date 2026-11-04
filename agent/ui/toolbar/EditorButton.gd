class_name EditorButton
extends RefCounted

## Toolbar entry point for the editor scene.

const EDITOR_SCENE_PATH := "res://agent/app/editor/Editor.tscn"

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
	await SceneHelper.async_change_scene_to_file(EDITOR_SCENE_PATH)
	pass


func apply_theme() -> void:
	AgentToolbarButton.style(button, I18n.t("editor.tooltip"))
	button.text = I18n.t("editor.title")
	pass
