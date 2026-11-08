class_name AgentSettingSection
extends SettingSection

var sandbox_toggle_button: CheckButton
var sandbox_label: Label
var max_turns_label: Label
var max_turns_spin: SpinBox
var external_editor_label: Label
var external_editor_edit: LineEdit
var external_editor_button: Button
var external_editor_dialog: FileDialog
var read_image_with_api_label: Label
var read_image_with_api_toggle_button: CheckButton
var browser_headless_label: Label
var browser_headless_toggle_button: CheckButton
var restart_web_server_label: Label
var restart_web_server_button: Button


func set_up(p_ui: AgentSettingWindow, parent: VBoxContainer, window: Window) -> void:
	super.set_up(p_ui, parent, window)
	heading_label = ui.add_heading(parent, I18n.t("common.agent"))
	var sandbox_parts := ui.make_setting_row(parent, 6)
	sandbox_label = ui.make_label(I18n.t("agent.settings.sandbox_mode"))
	sandbox_parts[0].add_child(sandbox_label)
	sandbox_toggle_button = ui.add_check_button(sandbox_parts[1], "", SandboxPolicy.is_enabled())
	sandbox_toggle_button.tooltip_text = I18n.t("agent.settings.sandbox_mode_help")
	sandbox_toggle_button.toggled.connect(on_sandbox_toggled)
	max_turns_label = ui.make_label(I18n.t("agent.settings.max_turns"))
	max_turns_label.tooltip_text = I18n.t("agent.settings.max_turns_help")
	sandbox_parts[2].add_child(max_turns_label)
	max_turns_spin = SpinBox.new()
	max_turns_spin.min_value = AgentSetting.MIN_MAX_TURNS
	max_turns_spin.max_value = AgentSetting.MAX_MAX_TURNS
	max_turns_spin.step = 1
	max_turns_spin.custom_minimum_size = Vector2(0, ControlSize.md)
	max_turns_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_turns_spin.tooltip_text = I18n.t("agent.settings.max_turns_help")
	max_turns_spin.value = AgentSetting.get_max_turns()
	max_turns_spin.value_changed.connect(on_max_turns_changed)
	sandbox_parts[3].add_child(max_turns_spin)
	var editor_parts := ui.make_setting_row(parent)
	external_editor_label = ui.make_label(I18n.t("agent.settings.external_editor"))
	external_editor_label.tooltip_text = I18n.t("agent.settings.external_editor_help")
	editor_parts[0].add_child(external_editor_label)
	var editor_row := HBoxContainer.new()
	editor_row.add_theme_constant_override("separation", Margin.ma_2)
	editor_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_parts[1].add_child(editor_row)
	external_editor_edit = ui.make_line_edit(I18n.t("agent.settings.external_editor_placeholder"))
	external_editor_edit.text = AgentSetting.get_custom_editor_path()
	external_editor_edit.tooltip_text = I18n.t("agent.settings.external_editor_help")
	external_editor_edit.text_submitted.connect(on_external_editor_submitted)
	external_editor_edit.focus_exited.connect(save_external_editor)
	editor_row.add_child(external_editor_edit)
	external_editor_button = Button.new()
	external_editor_button.text = I18n.t("agent.settings.browse")
	external_editor_button.focus_mode = Control.FOCUS_NONE
	external_editor_button.custom_minimum_size.y = ControlSize.md
	external_editor_button.pressed.connect(open_external_editor_dialog)
	editor_row.add_child(external_editor_button)
	build_external_editor_dialog(window)
	var read_image_parts := ui.make_setting_row(parent)
	read_image_with_api_label = ui.make_label(I18n.t("agent.settings.read_image_remotely"))
	read_image_with_api_label.tooltip_text = I18n.t("agent.settings.read_image_remotely_help")
	read_image_parts[0].add_child(read_image_with_api_label)
	read_image_with_api_toggle_button = ui.add_check_button(read_image_parts[1], "", AgentSetting.get_read_image_with_api())
	read_image_with_api_toggle_button.tooltip_text = I18n.t("agent.settings.read_image_remotely_help")
	read_image_with_api_toggle_button.toggled.connect(on_read_image_with_api_toggled)
	var browser_parts := ui.make_setting_row(parent, 6)
	# Column 1 — browser headless label (label band).
	browser_headless_label = ui.make_label(I18n.t("agent.settings.browser_headless"))
	style_browser_row_label(browser_headless_label)
	browser_parts[0].add_child(browser_headless_label)
	browser_headless_label.tooltip_text = I18n.t("agent.settings.browser_headless_help")
	# Column 2 — browser headless toggle (control band, 1/5).
	browser_headless_toggle_button = ui.add_check_button(browser_parts[1], "", AgentSetting.get_browser_headless())
	browser_headless_toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	browser_headless_toggle_button.tooltip_text = I18n.t("agent.settings.browser_headless_help")
	browser_headless_toggle_button.toggled.connect(on_browser_headless_toggled)
	# Column 3 — browser service label (control band, 2/5).
	restart_web_server_label = ui.make_label(I18n.t("agent.settings.browser_service"))
	style_browser_row_label(restart_web_server_label)
	restart_web_server_label.tooltip_text = I18n.t("agent.settings.restart_browser_service_help")
	browser_parts[2].add_child(restart_web_server_label)
	# Column 4 — restart browser service button (control band, 3/5).
	restart_web_server_button = Button.new()
	restart_web_server_button.text = I18n.t("agent.settings.restart_browser_service")
	restart_web_server_button.tooltip_text = I18n.t("agent.settings.restart_browser_service_help")
	restart_web_server_button.focus_mode = Control.FOCUS_NONE
	restart_web_server_button.custom_minimum_size.y = ControlSize.sm
	restart_web_server_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_web_server_button.pressed.connect(on_restart_web_server_pressed)
	browser_parts[3].add_child(restart_web_server_button)
	# Columns 5–6 — unused; keeps alignment with the 6-column notification row.
	pass


func build_external_editor_dialog(window: Window) -> void:
	external_editor_dialog = FileDialog.new()
	external_editor_dialog.title = I18n.t("agent.settings.external_editor_title")
	external_editor_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	external_editor_dialog.access = FileDialog.ACCESS_FILESYSTEM
	external_editor_dialog.ok_button_text = I18n.t("common.select")
	external_editor_dialog.get_cancel_button().text = I18n.t("common.cancel")
	if OSUtils.is_windows():
		external_editor_dialog.add_filter("*.exe,*.cmd,*.bat", "Executables")
	external_editor_dialog.file_selected.connect(on_external_editor_selected)
	window.add_child(external_editor_dialog)
	pass


func style_browser_row_label(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass


func refresh() -> void:
	ui.refresh_check_button(sandbox_toggle_button, SandboxPolicy.is_enabled())
	max_turns_spin.set_value_no_signal(AgentSetting.get_max_turns())
	external_editor_edit.text = AgentSetting.get_custom_editor_path()
	ui.refresh_check_button(read_image_with_api_toggle_button, AgentSetting.get_read_image_with_api())
	ui.refresh_check_button(browser_headless_toggle_button, AgentSetting.get_browser_headless())
	pass


func save() -> void:
	save_external_editor()
	pass


func on_sandbox_toggled(enabled: bool) -> void:
	SandboxPolicy.set_enabled(enabled)
	pass


func on_max_turns_changed(turns: float) -> void:
	AgentSetting.set_max_turns(roundi(turns))
	pass


func on_external_editor_submitted(_path: String) -> void:
	save_external_editor()
	pass


func save_external_editor() -> void:
	AgentSetting.set_custom_editor_path(external_editor_edit.text)
	if FileAccess.file_exists(AgentSetting.get_custom_editor_path()):
		AgentSetting.set_workspace_editor("custom")
	pass


func open_external_editor_dialog() -> void:
	if external_editor_dialog.visible:
		return
	var path := external_editor_edit.text.strip_edges()
	if FileAccess.file_exists(path):
		external_editor_dialog.current_path = path
	FileDialogStyle.present_centered(external_editor_dialog, 60, 70, I18nHelper.file_dialog_label_texts())
	pass


func on_external_editor_selected(path: String) -> void:
	external_editor_edit.text = FileUtils.normalize_path(path)
	save_external_editor()
	pass


func on_read_image_with_api_toggled(enabled: bool) -> void:
	AgentSetting.set_read_image_with_api(enabled)
	AgentToolRegistry.reload_tools()
	pass


func on_browser_headless_toggled(enabled: bool) -> void:
	AgentSetting.set_browser_headless(enabled)
	pass


func on_restart_web_server_pressed() -> void:
	if restart_web_server_button.disabled:
		return
	restart_web_server_button.disabled = true
	restart_web_server_button.text = I18n.t("agent.settings.restarting_browser_service")
	Alert.alert(I18n.t("agent.settings.restarting_browser_service"), Colors.info)
	restart_web_server.call_deferred()
	pass


func restart_web_server() -> void:
	var error := await WebServer.async_restart()
	restart_web_server_button.disabled = false
	restart_web_server_button.text = I18n.t("agent.settings.restart_browser_service")
	if error == OK:
		Alert.alert(I18n.t("agent.settings.browser_service_restarted"), Colors.success)
	else:
		Alert.alert(I18n.t("agent.settings.browser_service_restart_failed"), Colors.error)
	pass


func apply_locale() -> void:
	heading_label.text = I18n.t("common.agent")
	sandbox_label.text = I18n.t("agent.settings.sandbox_mode")
	sandbox_label.tooltip_text = I18n.t("agent.settings.sandbox_mode_help")
	sandbox_toggle_button.tooltip_text = I18n.t("agent.settings.sandbox_mode_help")
	max_turns_label.text = I18n.t("agent.settings.max_turns")
	max_turns_label.tooltip_text = I18n.t("agent.settings.max_turns_help")
	max_turns_spin.tooltip_text = I18n.t("agent.settings.max_turns_help")
	external_editor_label.text = I18n.t("agent.settings.external_editor")
	external_editor_label.tooltip_text = I18n.t("agent.settings.external_editor_help")
	external_editor_edit.placeholder_text = I18n.t("agent.settings.external_editor_placeholder")
	external_editor_edit.tooltip_text = I18n.t("agent.settings.external_editor_help")
	external_editor_button.text = I18n.t("agent.settings.browse")
	external_editor_dialog.title = I18n.t("agent.settings.external_editor_title")
	external_editor_dialog.ok_button_text = I18n.t("common.select")
	external_editor_dialog.get_cancel_button().text = I18n.t("common.cancel")
	FileDialogStyle.apply(external_editor_dialog, I18nHelper.file_dialog_label_texts())
	read_image_with_api_label.text = I18n.t("agent.settings.read_image_remotely")
	read_image_with_api_label.tooltip_text = I18n.t("agent.settings.read_image_remotely_help")
	read_image_with_api_toggle_button.tooltip_text = I18n.t("agent.settings.read_image_remotely_help")
	browser_headless_label.text = I18n.t("agent.settings.browser_headless")
	browser_headless_label.tooltip_text = I18n.t("agent.settings.browser_headless_help")
	browser_headless_toggle_button.tooltip_text = I18n.t("agent.settings.browser_headless_help")
	restart_web_server_label.text = I18n.t("agent.settings.browser_service")
	restart_web_server_label.tooltip_text = I18n.t("agent.settings.restart_browser_service_help")
	restart_web_server_button.tooltip_text = I18n.t("agent.settings.restart_browser_service_help")
	if not restart_web_server_button.disabled:
		restart_web_server_button.text = I18n.t("agent.settings.restart_browser_service")
	else:
		restart_web_server_button.text = I18n.t("agent.settings.restarting_browser_service")
	pass


func apply_theme() -> void:
	super.apply_theme()
	ui.style_field_label(sandbox_label)
	ButtonStyle.apply_check_button(sandbox_toggle_button)
	ui.style_field_label(max_turns_label)
	ui.style_spin_box(max_turns_spin)
	ui.style_field_label(external_editor_label)
	LineEditStyle.apply(external_editor_edit)
	ui.style_action_button(external_editor_button)
	FileDialogStyle.apply(external_editor_dialog, I18nHelper.file_dialog_label_texts())
	ui.style_field_label(read_image_with_api_label)
	ButtonStyle.apply_check_button(read_image_with_api_toggle_button)
	ui.style_field_label(browser_headless_label)
	ButtonStyle.apply_check_button(browser_headless_toggle_button)
	ui.style_field_label(restart_web_server_label)
	ui.style_action_button(restart_web_server_button)
	pass
