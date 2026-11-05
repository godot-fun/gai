class_name EditorButton
extends RefCounted

## Toolbar entry point for the editor scene. Its button marks the start of the chat content.

const EDITOR_SCENE_PATH := "res://agent/app/editor/Editor.tscn"

var button: Button
var workspace_button: Button


func setup(p_button: Button, p_workspace_button: Button) -> void:
	button = p_button
	workspace_button = p_workspace_button
	button.pressed.connect(on_button_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_theme)
	apply_theme()
	update_alignment.call_deferred()
	pass


func on_button_pressed() -> void:
	await SceneHelper.async_change_scene_to_file(EDITOR_SCENE_PATH)
	pass


func apply_theme() -> void:
	AgentToolbarButton.style(button, I18n.t("editor.tooltip"))
	button.text = I18n.t("editor.title")
	pass


## Places this button at the shared chat-content boundary after toolbar layout settles.
func update_alignment() -> void:
	var offset := AgentLayout.CHAT_CONTENT_LEFT - button.global_position.x
	workspace_button.custom_minimum_size.x = maxf(0.0, workspace_button.size.x + offset)
	pass
