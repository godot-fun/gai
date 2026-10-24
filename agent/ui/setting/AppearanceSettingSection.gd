class_name AppearanceSettingSection
extends SettingSection

var language_label: Label
var language_select: OptionButton
var markdown_label: Label
var markdown_toggle_button: CheckButton
var ui_scale_label: Label
var ui_scale_select: OptionButton


func set_up(p_ui: AgentSettingDialog, parent: VBoxContainer, dialog: ConfirmationDialog) -> void:
	super.set_up(p_ui, parent, dialog)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.appearance"))
	var group := ui.make_field_group(parent)
	var parts := ui.make_setting_row(group)
	language_label = ui.make_label(I18n.t("agent.settings.language"))
	parts[0].add_child(language_label)
	language_select = OptionButton.new()
	language_select.custom_minimum_size = Vector2(0, 38)
	language_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_select.size_flags_stretch_ratio = AgentSettingDialog.FIELD_CONTROL_RATIO
	for locale in I18nHelper.LOCALE_PATHS:
		var config: I18nHelper.LocaleConfig = I18nHelper.LOCALE_PATHS[locale]
		language_select.add_item(config.language)
		language_select.set_item_metadata(language_select.item_count - 1, locale)
	language_select.item_selected.connect(on_language_selected)
	language_select.get_popup().popup_hide.connect(ui.request_focus_check)
	parts[1].add_child(language_select)
	var markdown_parts := ui.make_setting_row(parent)
	markdown_label = ui.make_label(I18n.t("agent.settings.markdown"))
	markdown_parts[0].add_child(markdown_label)
	markdown_label.tooltip_text = I18n.t("agent.settings.markdown_help")
	var control := ui.make_option_row(markdown_parts[1], Margin.ma_0)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_stretch_ratio = AgentSettingDialog.FIELD_CONTROL_RATIO
	markdown_toggle_button = ui.add_check_button(control, "", AgentSetting.get_markdown_enabled())
	markdown_toggle_button.tooltip_text = I18n.t("agent.settings.markdown_help")
	markdown_toggle_button.toggled.connect(on_markdown_toggled)
	var scale_parts := ui.make_setting_row(parent)
	ui_scale_label = ui.make_label(I18n.t("agent.settings.ui_scale"))
	ui_scale_label.tooltip_text = I18n.t("agent.settings.ui_scale_help")
	scale_parts[0].add_child(ui_scale_label)
	ui_scale_select = OptionButton.new()
	ui_scale_select.custom_minimum_size = Vector2(0, 38)
	ui_scale_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_scale_select.size_flags_stretch_ratio = AgentSettingDialog.FIELD_CONTROL_RATIO
	for scale in AgentSetting.UI_SCALES:
		ui_scale_select.add_item(StringUtils.format("{}%", roundi(scale * 100.0)))
		ui_scale_select.set_item_metadata(ui_scale_select.item_count - 1, scale)
	ui_scale_select.item_selected.connect(on_ui_scale_selected)
	ui_scale_select.get_popup().popup_hide.connect(ui.request_focus_check)
	scale_parts[1].add_child(ui_scale_select)
	select_current_language()
	select_current_ui_scale()
	pass


func refresh() -> void:
	select_current_language()
	select_current_ui_scale()
	ui.refresh_check_button(markdown_toggle_button, AgentSetting.get_markdown_enabled())
	pass


func select_current_language() -> void:
	for index in range(language_select.item_count):
		if str(language_select.get_item_metadata(index)) == I18n.get_locale():
			language_select.select(index)
			return
	pass


func on_language_selected(index: int) -> void:
	var locale := str(language_select.get_item_metadata(index))
	if locale == I18n.get_locale() or not I18nHelper.LOCALE_PATHS.has(locale):
		return
	var config: I18nHelper.LocaleConfig = I18nHelper.LOCALE_PATHS[locale]
	I18n.set_locale(config.locale_path)
	pass


func select_current_ui_scale() -> void:
	var current := AgentSetting.get_ui_scale()
	for index in range(ui_scale_select.item_count):
		if is_equal_approx(float(ui_scale_select.get_item_metadata(index)), current):
			ui_scale_select.select(index)
			return
	pass


func on_ui_scale_selected(index: int) -> void:
	AgentSetting.set_ui_scale(float(ui_scale_select.get_item_metadata(index)))
	pass


func on_markdown_toggled(enabled: bool) -> void:
	AgentSetting.set_markdown_enabled(enabled)
	pass


func apply_locale() -> void:
	heading_label.text = I18n.t("agent.settings.appearance")
	language_label.text = I18n.t("agent.settings.language")
	markdown_label.text = I18n.t("agent.settings.markdown")
	markdown_label.tooltip_text = I18n.t("agent.settings.markdown_help")
	markdown_toggle_button.tooltip_text = I18n.t("agent.settings.markdown_help")
	ui_scale_label.text = I18n.t("agent.settings.ui_scale")
	ui_scale_label.tooltip_text = I18n.t("agent.settings.ui_scale_help")
	select_current_language()
	pass


func apply_theme() -> void:
	super.apply_theme()
	ui.style_field_label(language_label)
	ui.style_field_label(markdown_label)
	ui.style_field_label(ui_scale_label)
	ui.style_option_button(language_select)
	ui.style_option_button(ui_scale_select)
	ButtonStyle.apply_check_button(markdown_toggle_button)
	pass


func has_open_popup() -> bool:
	return language_select.get_popup().visible or ui_scale_select.get_popup().visible
