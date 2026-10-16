class_name ConnectionSettingSection
extends SettingSection

var description_label: Label
var provider_label: Label
var api_url_label: Label
var model_label: Label
var api_token_label: Label
var proxy_label: Label
var help_labels: Array[Label] = []
var provider_select: OptionButton
var api_url_edit: LineEdit
var model_edit: LineEdit
var api_token_edit: LineEdit
var proxy_address_edit: LineEdit


func set_up(p_ui: AgentSettingDialog, parent: VBoxContainer, dialog: ConfirmationDialog) -> void:
	super.set_up(p_ui, parent, dialog)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.heading"))
	description_label = Label.new()
	description_label.text = I18n.t("agent.settings.description")
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", Typography.body_small_size)
	parent.add_child(description_label)
	provider_select = add_provider_field(parent)
	var api_result := add_field(parent, I18n.t("agent.settings.api_endpoint"), "https://api.example.com/v1/chat/completions", I18n.t("agent.settings.api_endpoint_help"))
	api_url_edit = api_result[0]
	api_url_label = api_result[1]
	var model_result := add_field(parent, I18n.t("agent.settings.model"), ApiSetting.DEFAULT_MODEL, I18n.t("agent.settings.model_help"))
	model_edit = model_result[0]
	model_label = model_result[1]
	var token_result := add_field(parent, I18n.t("agent.settings.api_token"), "sk-...", I18n.t("agent.settings.token_help"))
	api_token_edit = token_result[0]
	api_token_label = token_result[1]
	api_token_edit.secret = true
	api_token_edit.secret_character = "*"
	var proxy_result := add_field(parent, I18n.t("agent.settings.proxy"), "http://127.0.0.1:10809", I18n.t("agent.settings.proxy_help"))
	proxy_address_edit = proxy_result[0]
	proxy_label = proxy_result[1]
	for edit in [api_url_edit, model_edit, api_token_edit, proxy_address_edit]:
		ui.bind_auto_save(edit, save)
	pass


func add_provider_field(parent: VBoxContainer) -> OptionButton:
	var group := ui.make_field_group(parent)
	var parts := ui.make_field_row(group, I18n.t("agent.settings.provider"))
	provider_label = parts[1]
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(0, 38)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.size_flags_stretch_ratio = AgentSettingDialog.FIELD_CONTROL_RATIO
	select.add_item(I18n.t("agent.settings.custom_provider"))
	for provider in ApiSupport.PROVIDERS:
		select.add_item(provider.name)
	select.item_selected.connect(on_provider_selected)
	select.get_popup().popup_hide.connect(ui.request_focus_check)
	(parts[0] as HBoxContainer).add_child(select)
	help_labels.append(ui.add_help_label(group, I18n.t("agent.settings.provider_help")))
	return select


func add_field(parent: VBoxContainer, label_text: String, placeholder: String, help_text: String) -> Array:
	var group := ui.make_field_group(parent)
	var parts := ui.make_field_row(group, label_text)
	var edit := ui.make_line_edit(placeholder)
	(parts[0] as HBoxContainer).add_child(edit)
	help_labels.append(ui.add_help_label(group, help_text))
	return [edit, parts[1]]


func refresh() -> void:
	api_url_edit.text = ApiSetting.get_api_url()
	model_edit.text = ApiSetting.get_model()
	provider_select.select(0)
	api_token_edit.text = ApiSetting.get_api_token()
	proxy_address_edit.text = ApiSetting.get_proxy_address()
	api_token_edit.secret = true
	pass


func save() -> void:
	ApiSetting.save(api_url_edit.text, api_token_edit.text, model_edit.text, proxy_address_edit.text)
	pass


func on_provider_selected(selected_index: int) -> void:
	if selected_index <= 0:
		return
	var provider: ApiProvider = ApiSupport.get_provider(selected_index - 1)
	if provider == null:
		return
	api_url_edit.text = provider.api_url
	model_edit.text = provider.model
	save()
	pass


func apply_locale() -> void:
	heading_label.text = I18n.t("agent.settings.heading")
	description_label.text = I18n.t("agent.settings.description")
	provider_label.text = I18n.t("agent.settings.provider")
	api_url_label.text = I18n.t("agent.settings.api_endpoint")
	model_label.text = I18n.t("agent.settings.model")
	api_token_label.text = I18n.t("agent.settings.api_token")
	proxy_label.text = I18n.t("agent.settings.proxy")
	var help_keys := ["provider_help", "api_endpoint_help", "model_help", "token_help", "proxy_help"]
	for index in range(help_labels.size()):
		help_labels[index].text = I18n.t("agent.settings." + help_keys[index])
	provider_select.set_item_text(0, I18n.t("agent.settings.custom_provider"))
	pass


func apply_theme() -> void:
	super.apply_theme()
	description_label.add_theme_color_override("font_color", Colors.secondary_text)
	for label in [provider_label, api_url_label, model_label, api_token_label, proxy_label]:
		ui.style_field_label(label)
	for help in help_labels:
		ui.style_help_label(help)
	for edit in [api_url_edit, model_edit, api_token_edit, proxy_address_edit]:
		ui.style_line_edit(edit)
	ui.style_option_button(provider_select)
	pass


func has_open_popup() -> bool:
	return provider_select.get_popup().visible
