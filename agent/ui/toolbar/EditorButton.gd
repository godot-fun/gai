class_name EditorButton
extends RefCounted

## Toolbar entry point for the standalone editor. Launches shell/editor.ps1 in a new process (Windows).

const EDITOR_SCRIPT := "shell/editor.ps1"

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
	launch_standalone_editor()
	pass


func launch_standalone_editor() -> void:
	if not OSUtils.is_windows():
		Alert.alert("The standalone editor launcher is only available on Windows", Colors.error)
		return
	var script := FileUtils.get_project_root_path().path_join(EDITOR_SCRIPT)
	if not FileAccess.file_exists(script):
		Log.error("editor launcher script missing path:[{}]", script)
		Alert.alert("Could not start the editor", Colors.error)
		return
	var pid := OS.create_process("powershell.exe", PackedStringArray(["-ExecutionPolicy", "Bypass", "-File", script, "--data-dir", AgentWorkspace.data_dir]), true)
	if pid <= 0:
		Log.error("failed to launch standalone editor script:[{}]", script)
		Alert.alert("Could not start the editor", Colors.error)
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
