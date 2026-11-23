class_name NetworkSettingSection
extends SettingSection

var proxy_label: Label
var proxy_help_label: Label
var proxy_address_edit: LineEdit


func set_up(p_ui: AgentSettingWindow, parent: VBoxContainer, window: Window) -> void:
	super.set_up(p_ui, parent, window)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.network"))
	var group := ui.make_field_group(parent)
	var parts := ui.make_setting_row(group)
	proxy_label = ui.make_label(I18n.t("agent.settings.proxy"))
	parts[0].add_child(proxy_label)
	proxy_address_edit = ui.make_line_edit("http://127.0.0.1:10809")
	parts[1].add_child(proxy_address_edit)
	proxy_help_label = ui.add_help_label(group, I18n.t("agent.settings.proxy_help"))
	pass


func refresh() -> void:
	proxy_address_edit.text = NetworkSetting.get_proxy_address()
	pass


func save() -> void:
	var proxy_address := proxy_address_edit.text.strip_edges()
	if StringUtils.is_not_blank(proxy_address) and not HttpUtils.is_valid_http_url(proxy_address):
		Alert.alert(I18n.t("agent.settings.invalid_proxy"), Colors.error)
		refresh()
		return
	NetworkSetting.save_proxy_address(proxy_address)
	pass


func apply_locale() -> void:
	heading_label.text = I18n.t("agent.settings.network")
	proxy_label.text = I18n.t("agent.settings.proxy")
	proxy_help_label.text = I18n.t("agent.settings.proxy_help")
	pass


func apply_theme() -> void:
	super.apply_theme()
	ui.style_field_label(proxy_label)
	ui.style_help_label(proxy_help_label)
	LineEditStyle.apply(proxy_address_edit)
	pass
