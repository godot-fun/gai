class_name BehaviorSettingSection
extends SettingSection

var sandbox_toggle_button: CheckButton
var sandbox_label: Label
var browser_headless_label: Label
var browser_headless_toggle_button: CheckButton
var restart_web_server_label: Label
var restart_web_server_button: Button


func set_up(p_ui: AgentSettingDialog, parent: VBoxContainer, dialog: ConfirmationDialog) -> void:
	super.set_up(p_ui, parent, dialog)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.agent_behavior"))
	var sandbox_parts := ui.make_multi_column_row(parent, [1.0, 1.0, 2.0])
	sandbox_label = ui.make_label(I18n.t("agent.settings.sandbox_mode"))
	sandbox_parts[0].add_child(sandbox_label)
	sandbox_toggle_button = ui.add_check_button(sandbox_parts[1], "", SandboxPolicy.is_enabled())
	sandbox_toggle_button.tooltip_text = I18n.t("agent.settings.sandbox_mode_help")
	sandbox_toggle_button.toggled.connect(on_sandbox_toggled)
	var browser_parts := ui.make_multi_column_row(parent, [1.0, 1.0, 1.0, 1.0])
	browser_headless_label = ui.make_label(I18n.t("agent.settings.browser_headless"))
	browser_parts[0].add_child(browser_headless_label)
	browser_headless_label.tooltip_text = I18n.t("agent.settings.browser_headless_help")
	browser_headless_toggle_button = ui.add_check_button(browser_parts[1], "", AgentSetting.get_browser_headless())
	browser_headless_toggle_button.tooltip_text = I18n.t("agent.settings.browser_headless_help")
	browser_headless_toggle_button.toggled.connect(on_browser_headless_toggled)
	restart_web_server_label = ui.make_label(I18n.t("agent.settings.browser_service"))
	restart_web_server_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_web_server_label.tooltip_text = I18n.t("agent.settings.restart_browser_service_help")
	browser_parts[2].add_child(restart_web_server_label)
	restart_web_server_button = Button.new()
	restart_web_server_button.text = I18n.t("agent.settings.restart_browser_service")
	restart_web_server_button.tooltip_text = I18n.t("agent.settings.restart_browser_service_help")
	restart_web_server_button.focus_mode = Control.FOCUS_NONE
	restart_web_server_button.custom_minimum_size.y = ControlSize.sm
	restart_web_server_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_web_server_button.pressed.connect(on_restart_web_server_pressed)
	browser_parts[3].add_child(restart_web_server_button)
	pass


func refresh() -> void:
	ui.refresh_check_button(sandbox_toggle_button, SandboxPolicy.is_enabled())
	ui.refresh_check_button(browser_headless_toggle_button, AgentSetting.get_browser_headless())
	pass


func on_sandbox_toggled(enabled: bool) -> void:
	SandboxPolicy.set_enabled(enabled)
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
	heading_label.text = I18n.t("agent.settings.agent_behavior")
	sandbox_label.text = I18n.t("agent.settings.sandbox_mode")
	sandbox_label.tooltip_text = I18n.t("agent.settings.sandbox_mode_help")
	sandbox_toggle_button.tooltip_text = I18n.t("agent.settings.sandbox_mode_help")
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
	ui.style_check_button(sandbox_toggle_button)
	ui.style_field_label(browser_headless_label)
	ui.style_check_button(browser_headless_toggle_button)
	ui.style_field_label(restart_web_server_label)
	ui.style_action_button(restart_web_server_button)
	pass
