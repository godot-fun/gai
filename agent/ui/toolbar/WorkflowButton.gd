class_name WorkflowButton
extends RefCounted

## Opens the workflow scene and aligns its toolbar button with the chat content.

const WORKFLOW_SCENE_PATH := "res://agent/app/workflow/Workflow.tscn"
const Layout := preload("res://agent/ui/AgentLayout.gd")

var button: Button
var workspace_button: Button


func setup(
	p_button: Button,
	p_workspace_button: Button
) -> void:
	button = p_button
	workspace_button = p_workspace_button
	button.pressed.connect(on_button_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_theme)
	apply_theme()
	update_alignment.call_deferred()
	pass


func apply_theme() -> void:
	AgentToolbarButton.style(button, I18n.t("agent.toolbar.open_workflow"))
	pass


func on_button_pressed() -> void:
	await SceneHelper.async_change_scene_to_file(WORKFLOW_SCENE_PATH)
	pass


## Places the action at the shared chat-content boundary after toolbar layout settles.
func update_alignment() -> void:
	var offset := Layout.CHAT_CONTENT_LEFT - button.global_position.x
	workspace_button.custom_minimum_size.x = maxf(0.0, workspace_button.size.x + offset)
	pass
