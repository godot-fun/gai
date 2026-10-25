class_name WorkspaceButton
extends RefCounted

## Toolbar workspace button — shows the agent workspace root and opens the folder picker.
## A confirmed folder goes through [method AgentWorkspace.set_root], which announces the
## switch on [signal AgentEvents.events.workspace_changed].

var button: Button
var dialog: FileDialog


func setup(p_button: Button, p_dialog: FileDialog) -> void:
	button = p_button
	dialog = p_dialog
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = workspace_tooltip()
	button.pressed.connect(on_button_pressed)
	dialog.dir_selected.connect(on_dir_selected)
	gdf.events.locale_changed.connect(apply_locale)
	refresh()
	pass


func apply_locale() -> void:
	button.tooltip_text = workspace_tooltip()
	dialog.title = I18n.t("agent.workspace.dialog_title")
	dialog.ok_button_text = I18n.t("common.select")
	dialog.get_cancel_button().text = I18n.t("common.cancel")
	FileDialogStyle.apply(dialog, I18nHelper.file_dialog_label_texts())
	pass


func workspace_tooltip() -> String:
	return "Code Agent Workspace · " + I18n.t("agent.workspace.choose")


## Sync the button label and the picker start folder with [method AgentWorkspace.get_root].
func refresh() -> void:
	var workspace_root := AgentWorkspace.get_root()
	button.text = workspace_root
	if DirAccess.dir_exists_absolute(workspace_root):
		dialog.current_dir = workspace_root
	pass


func on_button_pressed() -> void:
	refresh()
	FileDialogStyle.present_centered(dialog, 60, 70, I18nHelper.file_dialog_label_texts())
	pass


func on_dir_selected(path: String) -> void:
	if not AgentWorkspace.set_root(path):
		return
	refresh()
	pass
