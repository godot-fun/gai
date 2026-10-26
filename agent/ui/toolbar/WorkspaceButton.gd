class_name WorkspaceButton
extends RefCounted

## Toolbar workspace button — shows the agent workspace root and opens the folder picker.
## A confirmed folder goes through [method AgentWorkspace.set_root], which announces the
## switch on [signal AgentEvents.events.workspace_changed].

var button: Button


func setup(p_button: Button) -> void:
	button = p_button
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = workspace_tooltip()
	button.pressed.connect(on_button_pressed)
	gdf.events.locale_changed.connect(apply_locale)
	AgentEvents.events.workspace_changed.connect(on_workspace_changed)
	refresh()
	pass


func apply_locale() -> void:
	button.tooltip_text = workspace_tooltip()
	pass


func workspace_tooltip() -> String:
	return "Code Agent Workspace · " + I18n.t("agent.workspace.choose")


## Sync the button label and the picker start folder with [method AgentWorkspace.get_root].
func refresh() -> void:
	button.text = AgentWorkspace.get_root()
	pass


func on_button_pressed() -> void:
	WorkspaceWindow.show_workspace()
	pass


func on_workspace_changed(_path: String) -> void:
	refresh()
	pass
