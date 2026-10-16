class_name BehaviorSettingSection
extends SettingSection

var sandbox_toggle_button: CheckButton


func set_up(p_ui: AgentSettingDialog, parent: VBoxContainer, dialog: ConfirmationDialog) -> void:
	super.set_up(p_ui, parent, dialog)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.agent_behavior"))
	sandbox_toggle_button = ui.add_check_button(ui.make_option_row(parent, Margin.ma_2), I18n.t("agent.settings.sandbox_mode"), SandboxPolicy.is_enabled())
	sandbox_toggle_button.tooltip_text = I18n.t("agent.settings.sandbox_mode_help")
	sandbox_toggle_button.toggled.connect(on_sandbox_toggled)
	pass


func refresh() -> void:
	ui.refresh_check_button(sandbox_toggle_button, SandboxPolicy.is_enabled())
	pass


func on_sandbox_toggled(enabled: bool) -> void:
	SandboxPolicy.set_enabled(enabled)
	pass


func apply_locale() -> void:
	heading_label.text = I18n.t("agent.settings.agent_behavior")
	sandbox_toggle_button.text = I18n.t("agent.settings.sandbox_mode")
	sandbox_toggle_button.tooltip_text = I18n.t("agent.settings.sandbox_mode_help")
	pass


func apply_theme() -> void:
	super.apply_theme()
	ui.style_check_button(sandbox_toggle_button)
	pass
