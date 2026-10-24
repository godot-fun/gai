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
	var api_result := add_field(parent, I18n.t("agent.settings.api_url"), "https://api.example.com/v1/chat/completions", I18n.t("agent.settings.api_url_help"))
	api_url_edit = api_result[0]
	api_url_label = api_result[1]
	api_url_edit.gui_input.connect(on_api_url_input)
	set_up_history_panel(dialog)
	var model_result := add_field(parent, I18n.t("common.model"), ApiSetting.DEFAULT_MODEL, I18n.t("agent.settings.model_help"))
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
	dialog.window_input.connect(on_dialog_input)
	pass


func add_field(parent: VBoxContainer, label_text: String, placeholder: String, help_text: String) -> Array:
	var group := ui.make_field_group(parent)
	var parts := ui.make_setting_row(group)
	var label := ui.make_label(label_text)
	parts[0].add_child(label)
	var edit := ui.make_line_edit(placeholder)
	parts[1].add_child(edit)
	help_labels.append(ui.add_help_label(group, help_text))
	return [edit, label]


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
	refresh_history()
	pass


func save_current() -> void:
	var api_url := api_url_edit.text.strip_edges()
	if not HttpUtils.is_valid_http_url(api_url):
		Alert.alert(I18n.t("agent.settings.invalid_api_url"), Colors.error)
		refresh()
		return
	var proxy_address := proxy_address_edit.text.strip_edges()
	if StringUtils.is_not_blank(proxy_address) and not HttpUtils.is_valid_http_url(proxy_address):
		Alert.alert(I18n.t("agent.settings.invalid_proxy"), Colors.error)
		refresh()
		return
	ApiSetting.save(api_url, model_edit.text, api_token_edit.text, proxy_address)
	pass


## Rebuild each history row as PanelContainer -> HBoxContainer -> select/delete buttons.
## Keep the selected fill on the outer panel so it remains continuous behind the delete button.
func refresh_history() -> void:
	for child in history_list.get_children():
		history_list.remove_child(child)
		child.queue_free()
	var history := ApiSetting.get_connection_history()
	for index in range(history.size()):
		var entry := history[index]
		var row := PanelContainer.new()
		row.set_meta("connection", entry)
		history_list.add_child(row)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 0)
		row.add_child(content)
		var button := Button.new()
		button.text = entry.api_url
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = ControlSize.sm
		button.pressed.connect(on_history_selected.bind(entry))
		content.add_child(button)
		style_history_button(button)
		var delete_button := Button.new()
		delete_button.text = "×"
		delete_button.focus_mode = Control.FOCUS_NONE
		delete_button.custom_minimum_size.x = ControlSize.sm
		delete_button.pressed.connect(on_history_deleted.bind(index))
		content.add_child(delete_button)
		style_history_delete_button(delete_button)
		style_history_row(row)
	pass


func on_api_url_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	show_history_panel.call_deferred()
	pass


## Close the history when a click lands outside both its anchor field and floating panel.
## Read the position through a Control because Window input coordinates differ under canvas stretch.
func on_dialog_input(event: InputEvent) -> void:
	if not history_panel.visible:
		return
	if event is InputEventMouseMotion:
		refresh_history_hover()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	var click_position := api_url_edit.get_global_mouse_position()
	if api_url_edit.get_global_rect().has_point(click_position) or history_panel.get_global_rect().has_point(click_position):
		return
	hide_history_panel()
	pass


func show_history_panel() -> void:
	refresh_history()
	if history_list.get_child_count() == 0:
		return
	history_panel.position = api_url_edit.global_position + Vector2(0, api_url_edit.size.y + Margin.ma_1)
	history_panel.size = Vector2(api_url_edit.size.x, history_list.get_combined_minimum_size().y + Margin.ma_2)
	history_panel.visible = true
	refresh_history_hover()
	pass


func hide_history_panel() -> void:
	history_panel.visible = false
	pass


func on_history_selected(entry: ApiSetting.ApiModelConfig) -> void:
	ApiSetting.activate_connection(entry)
	api_url_edit.text = entry.api_url
	model_edit.text = entry.model
	api_token_edit.text = entry.api_token
	hide_history_panel()
	pass


func on_history_deleted(index: int) -> void:
	ApiSetting.remove_connection_at(index)
	api_url_edit.text = ApiSetting.get_api_url()
	model_edit.text = ApiSetting.get_model()
	api_token_edit.text = ApiSetting.get_api_token()
	refresh_history()
	if history_list.get_child_count() == 0:
		hide_history_panel()
	else:
		history_panel.size.y = history_list.get_combined_minimum_size().y + Margin.ma_2
	pass


func refresh_history_hover() -> void:
	for row: PanelContainer in history_list.get_children():
		style_history_row(row)
	pass


func apply_locale() -> void:
	heading_label.text = I18n.t("agent.settings.heading")
	api_url_label.text = I18n.t("agent.settings.api_url")
	model_label.text = I18n.t("common.model")
	api_token_label.text = I18n.t("agent.settings.api_token")
	proxy_label.text = I18n.t("agent.settings.proxy")
	var help_keys := ["api_url_help", "model_help", "token_help", "proxy_help"]
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
	for row: PanelContainer in history_list.get_children():
		var content := row.get_child(0) as HBoxContainer
		style_history_row(row)
		style_history_button(content.get_child(0) as Button)
		style_history_delete_button(content.get_child(1) as Button)
	pass


func style_history_row(row: PanelContainer) -> void:
	# Compare the complete configuration because multiple history rows may share one URL.
	var entry := row.get_meta("connection") as ApiSetting.ApiModelConfig
	var selected := (entry.api_url == api_url_edit.text.strip_edges()
		and entry.model == model_edit.text.strip_edges() and entry.api_token == api_token_edit.text.strip_edges())
	var hovered := row.get_global_rect().has_point(row.get_global_mouse_position())
	var color := ThemeColor.selected_surface if selected or hovered else Color.TRANSPARENT
	row.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(color, 5))
	pass


func style_history_button(button: Button) -> void:
	ButtonStyle.apply_font_colors(button, Colors.primary_text, Colors.primary_text, Colors.primary_text)
	var normal := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, 5, Margin.ma_2, Margin.ma_2)
	ButtonStyle.apply(button, normal, normal.duplicate() as StyleBoxFlat, normal.duplicate() as StyleBoxFlat)
	pass


func style_history_delete_button(button: Button) -> void:
	# Mirror LineEdit's clear affordance: a quiet glyph with no separate button background.
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, Colors.primary_text)
	var empty := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, 0)
	ButtonStyle.apply(button, empty, empty.duplicate() as StyleBoxFlat, empty.duplicate() as StyleBoxFlat)
	pass
