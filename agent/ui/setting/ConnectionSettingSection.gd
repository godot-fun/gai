class_name ConnectionSettingSection
extends SettingSection

var api_url_label: Label
var model_label: Label
var api_token_label: Label
var proxy_label: Label
var help_labels: Array[Label] = []
var history_layer: Control
var history_panel: PanelContainer
var history_list: VBoxContainer
var api_url_edit: LineEdit
var model_edit: LineEdit
var api_token_edit: LineEdit
var proxy_address_edit: LineEdit


func set_up(p_ui: AgentSettingDialog, parent: VBoxContainer, dialog: ConfirmationDialog) -> void:
	super.set_up(p_ui, parent, dialog)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.heading"))
	var api_result := add_field(parent, I18n.t("agent.settings.api_endpoint"), "https://api.example.com/v1/chat/completions", I18n.t("agent.settings.api_endpoint_help"))
	api_url_edit = api_result[0]
	api_url_label = api_result[1]
	api_url_edit.gui_input.connect(on_api_url_input)
	set_up_history_panel(dialog)
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
		ui.bind_auto_save(edit, save_current)
	pass


func set_up_history_panel(dialog: ConfirmationDialog) -> void:
	# A Window stretches direct Control children to its content rect. Use a passive full-size layer
	# so the panel remains a small, explicitly positioned child instead of covering the dialog.
	history_layer = Control.new()
	history_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	history_layer.z_index = 100
	dialog.add_child(history_layer)
	history_panel = PanelContainer.new()
	history_panel.visible = false
	history_layer.add_child(history_panel)
	history_list = VBoxContainer.new()
	history_list.add_theme_constant_override("separation", Margin.ma_1)
	history_panel.add_child(history_list)
	api_url_edit.focus_exited.connect(hide_history_panel)
	pass


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
	api_token_edit.text = ApiSetting.get_api_token()
	proxy_address_edit.text = ApiSetting.get_proxy_address()
	api_token_edit.secret = true
	refresh_history()
	pass


func save() -> void:
	save_current()
	ApiSetting.remember_connection(api_url_edit.text, api_token_edit.text, model_edit.text)
	refresh_history()
	pass


func save_current() -> void:
	ApiSetting.save(api_url_edit.text, api_token_edit.text, model_edit.text, proxy_address_edit.text)
	pass


func refresh_history() -> void:
	for child in history_list.get_children():
		history_list.remove_child(child)
		child.queue_free()
	for entry: ApiSetting.ApiModelConfig in ApiSetting.get_connection_history():
		var button := Button.new()
		button.text = entry.api_url
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = ControlSize.sm
		button.pressed.connect(on_history_selected.bind(entry))
		history_list.add_child(button)
		style_history_button(button)
	pass


func on_api_url_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	show_history_panel.call_deferred()
	pass


func show_history_panel() -> void:
	refresh_history()
	if history_list.get_child_count() == 0:
		return
	history_panel.position = api_url_edit.global_position + Vector2(0, api_url_edit.size.y + Margin.ma_1)
	history_panel.size = Vector2(api_url_edit.size.x, history_list.get_combined_minimum_size().y + Margin.ma_2)
	history_panel.visible = true
	pass


func hide_history_panel() -> void:
	history_panel.visible = false
	pass


func on_history_selected(entry: ApiSetting.ApiModelConfig) -> void:
	api_url_edit.text = entry.api_url
	model_edit.text = entry.model
	api_token_edit.text = entry.api_token
	hide_history_panel()
	save_current()
	pass


func apply_locale() -> void:
	heading_label.text = I18n.t("agent.settings.heading")
	api_url_label.text = I18n.t("agent.settings.api_endpoint")
	model_label.text = I18n.t("agent.settings.model")
	api_token_label.text = I18n.t("agent.settings.api_token")
	proxy_label.text = I18n.t("agent.settings.proxy")
	var help_keys := ["api_endpoint_help", "model_help", "token_help", "proxy_help"]
	for index in range(help_labels.size()):
		help_labels[index].text = I18n.t("agent.settings." + help_keys[index])
	pass


func apply_theme() -> void:
	super.apply_theme()
	for label in [api_url_label, model_label, api_token_label, proxy_label]:
		ui.style_field_label(label)
	for help in help_labels:
		ui.style_help_label(help)
	for edit in [api_url_edit, model_edit, api_token_edit, proxy_address_edit]:
		ui.style_line_edit(edit)
	var panel_style := StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, 7, Margin.ma_1, Margin.ma_1, Color(ThemeColor.title_color, 0.10), ControlSize.border_xs)
	history_panel.add_theme_stylebox_override("panel", panel_style)
	for button: Button in history_list.get_children():
		style_history_button(button)
	pass


func style_history_button(button: Button) -> void:
	var selected := button.text == api_url_edit.text.strip_edges()
	ButtonStyle.apply_font_colors(button, Colors.primary_text, Colors.primary_text, Colors.primary_text)
	var normal_color := ThemeColor.selected_surface if selected else Color.TRANSPARENT
	var normal := StyleBoxHelper.create_style_box_flat(normal_color, 5, Margin.ma_2, Margin.ma_2)
	var hover := StyleBoxHelper.create_style_box_flat(ThemeColor.selected_surface, 5, Margin.ma_2, Margin.ma_2)
	ButtonStyle.apply(button, normal, hover, hover.duplicate())
	pass
