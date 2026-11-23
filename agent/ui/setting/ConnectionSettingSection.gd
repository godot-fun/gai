class_name ConnectionSettingSection
extends SettingSection

var models_label: Label
var model_label: Label
var api_url_label: Label
var api_token_label: Label
var model_edit: LineEdit
var api_url_edit: LineEdit
var api_token_edit: LineEdit
var add_model_button: Button
var confirm_add_button: Button
var cancel_add_button: Button
var model_list: VBoxContainer
var add_form: VBoxContainer
var api_url_help_label: Label
var api_token_help_label: Label


func set_up(p_ui: AgentSettingWindow, parent: VBoxContainer, window: Window) -> void:
	super.set_up(p_ui, parent, window)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.connection"))
	set_up_models(parent)
	set_up_add_form(parent)
	AgentEvents.events.api_models_changed.connect(refresh_models)
	pass


func set_up_models(parent: VBoxContainer) -> void:
	var group := ui.make_field_group(parent)
	var parts := ui.make_setting_row(group)
	models_label = ui.make_label(I18n.t("agent.settings.models"))
	# Align the section label with the first model row instead of centering it across
	# the combined height of the model list and the add button below.
	models_label.custom_minimum_size.y = ControlSize.sm
	models_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parts[0].add_child(models_label)
	var model_controls := VBoxContainer.new()
	model_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_controls.add_theme_constant_override("separation", Margin.ma_2)
	parts[1].add_child(model_controls)
	model_list = VBoxContainer.new()
	model_list.add_theme_constant_override("separation", Margin.ma_1)
	model_controls.add_child(model_list)
	add_model_button = Button.new()
	add_model_button.text = I18n.t("agent.settings.add_model")
	add_model_button.custom_minimum_size.y = ControlSize.md
	add_model_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_model_button.pressed.connect(show_add_form)
	model_controls.add_child(add_model_button)
	pass


func set_up_add_form(parent: VBoxContainer) -> void:
	add_form = VBoxContainer.new()
	add_form.add_theme_constant_override("separation", Margin.ma_3)
	add_form.visible = false
	parent.add_child(add_form)
	var model_result := add_form_field(add_form, I18n.t("agent.settings.model_id"),
		I18n.t("agent.settings.model_placeholder"), "")
	model_edit = model_result[0]
	model_label = model_result[1]
	var api_result := add_form_field(add_form, I18n.t("agent.settings.api_url"),
		"https://api.example.com/v1/chat/completions", I18n.t("agent.settings.api_url_help"))
	api_url_edit = api_result[0]
	api_url_label = api_result[1]
	api_url_help_label = api_result[2]
	var token_result := add_form_field(add_form, I18n.t("agent.settings.api_token"),
		"sk-...", I18n.t("agent.settings.token_help"))
	api_token_edit = token_result[0]
	api_token_label = token_result[1]
	api_token_help_label = token_result[2]
	api_token_edit.secret = true
	api_token_edit.secret_character = "*"
	model_edit.text_submitted.connect(func(_text: String) -> void: confirm_add_model())
	api_url_edit.text_submitted.connect(func(_text: String) -> void: confirm_add_model())
	api_token_edit.text_submitted.connect(func(_text: String) -> void: confirm_add_model())
	var action_parts := ui.make_setting_row(add_form)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", Margin.ma_2)
	actions.size_flags_horizontal = Control.SIZE_SHRINK_END
	action_parts[1].add_child(actions)
	cancel_add_button = Button.new()
	cancel_add_button.text = I18n.t("common.cancel")
	cancel_add_button.custom_minimum_size.y = ControlSize.md
	cancel_add_button.pressed.connect(hide_add_form)
	actions.add_child(cancel_add_button)
	confirm_add_button = Button.new()
	confirm_add_button.text = I18n.t("agent.settings.add_model")
	confirm_add_button.custom_minimum_size.y = ControlSize.md
	confirm_add_button.pressed.connect(confirm_add_model)
	actions.add_child(confirm_add_button)
	pass


func add_form_field(parent: VBoxContainer, label_text: String, placeholder: String,
		help_text: String) -> Array:
	var group := ui.make_field_group(parent)
	var parts := ui.make_setting_row(group)
	var label := ui.make_label(label_text)
	parts[0].add_child(label)
	var edit := ui.make_line_edit(placeholder)
	parts[1].add_child(edit)
	var help: Label = null
	if not help_text.is_empty():
		help = ui.add_help_label(group, help_text)
	return [edit, label, help]


func refresh() -> void:
	hide_add_form()
	refresh_models()
	pass


func show_add_form() -> void:
	var active := ApiSetting.get_active_profile()
	model_edit.clear()
	api_url_edit.text = active.api_url
	api_token_edit.text = active.api_token
	add_form.visible = true
	add_model_button.visible = false
	model_edit.grab_focus()
	pass


func hide_add_form() -> void:
	add_form.visible = false
	add_model_button.visible = true
	model_edit.clear()
	pass


func confirm_add_model() -> void:
	var model := model_edit.text.strip_edges()
	var api_url := api_url_edit.text.strip_edges()
	if model.is_empty():
		model_edit.grab_focus()
		return
	if not HttpUtils.is_valid_http_url(api_url):
		Alert.alert(I18n.t("agent.settings.invalid_api_url"), Colors.error)
		api_url_edit.grab_focus()
		return
	if not ApiSetting.add_model(model, api_url, api_token_edit.text):
		Alert.alert(I18n.t("agent.settings.model_duplicate"), Colors.error)
		model_edit.grab_focus()
		return
	hide_add_form()
	pass


func refresh_models() -> void:
	if model_list == null:
		return
	for child in model_list.get_children():
		model_list.remove_child(child)
		child.queue_free()
	var active_model := ApiSetting.get_model()
	var profiles := ApiSetting.get_profiles()
	for profile in profiles:
		var row := PanelContainer.new()
		model_list.add_child(row)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", Margin.ma_1)
		row.add_child(content)
		var select_button := Button.new()
		select_button.text = profile.model
		select_button.tooltip_text = profile.api_url
		select_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		select_button.focus_mode = Control.FOCUS_NONE
		select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select_button.custom_minimum_size.y = ControlSize.sm
		select_button.pressed.connect(ApiSetting.set_active_model.bind(profile.model))
		content.add_child(select_button)
		var delete_button := Button.new()
		delete_button.text = "×"
		delete_button.tooltip_text = (I18n.t("agent.settings.keep_one_model")
			if profiles.size() == 1 else I18n.t("common.delete"))
		delete_button.disabled = profiles.size() == 1
		delete_button.focus_mode = Control.FOCUS_NONE
		delete_button.custom_minimum_size = Vector2(ControlSize.sm, ControlSize.sm)
		delete_button.pressed.connect(ApiSetting.remove_model.bind(profile.model))
		content.add_child(delete_button)
		style_model_row(row, profile.model == active_model)
		style_model_button(select_button)
		style_delete_button(delete_button)
	pass


func apply_locale() -> void:
	heading_label.text = I18n.t("agent.settings.connection")
	models_label.text = I18n.t("agent.settings.models")
	model_label.text = I18n.t("agent.settings.model_id")
	api_url_label.text = I18n.t("agent.settings.api_url")
	api_token_label.text = I18n.t("agent.settings.api_token")
	model_edit.placeholder_text = I18n.t("agent.settings.model_placeholder")
	api_url_help_label.text = I18n.t("agent.settings.api_url_help")
	api_token_help_label.text = I18n.t("agent.settings.token_help")
	add_model_button.text = I18n.t("agent.settings.add_model")
	confirm_add_button.text = I18n.t("agent.settings.add_model")
	cancel_add_button.text = I18n.t("common.cancel")
	refresh_models()
	pass


func apply_theme() -> void:
	super.apply_theme()
	for label in [models_label, model_label, api_url_label, api_token_label]:
		ui.style_field_label(label)
	ui.style_help_label(api_url_help_label)
	ui.style_help_label(api_token_help_label)
	for edit in [model_edit, api_url_edit, api_token_edit]:
		LineEditStyle.apply(edit)
	ButtonStyle.apply_action_button(add_model_button)
	ButtonStyle.apply_action_button(confirm_add_button)
	ButtonStyle.apply_action_button(cancel_add_button)
	for row: PanelContainer in model_list.get_children():
		var content := row.get_child(0) as HBoxContainer
		style_model_row(row, (content.get_child(0) as Button).text == ApiSetting.get_model())
		style_model_button(content.get_child(0) as Button)
		style_delete_button(content.get_child(1) as Button)
	pass


func style_model_row(row: PanelContainer, selected: bool) -> void:
	var color := ThemeColor.selected_surface if selected else Colors.surface_container_high
	row.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(color, ControlSize.radius_md))
	pass


func style_model_button(button: Button) -> void:
	ButtonStyle.apply_font_colors(button, Colors.primary_text, Colors.primary_text, Colors.primary_text)
	var empty := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, ControlSize.radius_md, Margin.ma_2, Margin.ma_2)
	ButtonStyle.apply_style(button, empty, empty.duplicate() as StyleBoxFlat, empty.duplicate() as StyleBoxFlat)
	pass


func style_delete_button(button: Button) -> void:
	button.flat = true
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.error, Colors.error)
	var empty := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, 0)
	ButtonStyle.apply_style(button, empty, empty.duplicate() as StyleBoxFlat, empty.duplicate() as StyleBoxFlat)
	pass
