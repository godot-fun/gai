class_name AppearanceSettingSection
extends SettingSection

var language_label: Label
var language_select: OptionButton
var markdown_label: Label
var markdown_toggle_button: CheckButton
var ui_scale_label: Label
var ui_scale_select: OptionButton


func set_up(p_ui: AgentSettingWindow, parent: VBoxContainer, window: Window) -> void:
	super.set_up(p_ui, parent, window)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.appearance"))
	var locale_scale_parts := ui.make_setting_row(parent, 6)
	# Control-band width weights: two cols per dropdown (2+0+1+2+0 = 5).
	locale_scale_parts[1].size_flags_stretch_ratio = 2.0
	locale_scale_parts[2].size_flags_stretch_ratio = 0.0
	locale_scale_parts[3].size_flags_stretch_ratio = 1.0
	locale_scale_parts[4].size_flags_stretch_ratio = 2.0
	locale_scale_parts[5].size_flags_stretch_ratio = 0.0
	# Column 1 — language label (label band).
	language_label = ui.make_label(I18n.t("agent.settings.language"))
	style_appearance_grid_label(language_label)
	locale_scale_parts[0].add_child(language_label)
	# Columns 2–3 — language selector (two control columns).
	language_select = OptionButton.new()
	language_select.custom_minimum_size = Vector2(0, 38)
	language_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for locale in I18nHelper.LOCALE_PATHS:
		var config: I18nHelper.LocaleConfig = I18nHelper.LOCALE_PATHS[locale]
		language_select.add_item(config.language)
		language_select.set_item_metadata(language_select.item_count - 1, locale)
	language_select.item_selected.connect(on_language_selected)
	locale_scale_parts[1].add_child(language_select)
	# Column 4 — UI scale label (one control column).
	ui_scale_label = ui.make_label(I18n.t("agent.settings.ui_scale"))
	ui_scale_label.tooltip_text = ui_scale_tooltip()
	style_appearance_grid_label(ui_scale_label)
	locale_scale_parts[3].add_child(ui_scale_label)
	# Columns 5–6 — UI scale selector (two control columns).
	ui_scale_select = OptionButton.new()
	ui_scale_select.tooltip_text = ui_scale_tooltip()
	ui_scale_select.custom_minimum_size = Vector2(0, 38)
	ui_scale_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for scale in DisplayScale.UI_SCALE_PRESETS:
		ui_scale_select.add_item(StringUtils.format("{}%", roundi(scale * 100.0)))
		ui_scale_select.set_item_metadata(ui_scale_select.item_count - 1, scale)
	ui_scale_select.item_selected.connect(on_ui_scale_selected)
	locale_scale_parts[4].add_child(ui_scale_select)
	var markdown_parts := ui.make_setting_row(parent)
	markdown_label = ui.make_label(I18n.t("agent.settings.markdown"))
	markdown_parts[0].add_child(markdown_label)
	markdown_label.tooltip_text = I18n.t("agent.settings.markdown_help")
	var control := ui.make_option_row(markdown_parts[1], Margin.ma_0)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_stretch_ratio = AgentSettingWindow.FIELD_CONTROL_RATIO
	markdown_toggle_button = ui.add_check_button(control, "", AgentSetting.get_markdown_enabled())
	markdown_toggle_button.tooltip_text = I18n.t("agent.settings.markdown_help")
	markdown_toggle_button.toggled.connect(on_markdown_toggled)
	gdf.events.ui_scale_changed.connect(on_ui_scale_changed)
	select_current_language()
	select_current_ui_scale()
	pass


func style_appearance_grid_label(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	ui_scale_select.select(DisplayScale.find_ui_scale_index(DisplayScale.get_ui_scale()))
	pass


func on_ui_scale_changed(_scale: float) -> void:
	select_current_ui_scale()
	pass


func on_ui_scale_selected(index: int) -> void:
	DisplayScale.set_ui_scale(float(ui_scale_select.get_item_metadata(index)))
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
	ui_scale_label.tooltip_text = ui_scale_tooltip()
	ui_scale_select.tooltip_text = ui_scale_tooltip()
	select_current_language()
	pass


func ui_scale_tooltip() -> String:
	if OSUtils.is_mac():
		return I18n.t("agent.settings.ui_scale_help_mac")
	return I18n.t("agent.settings.ui_scale_help")
	pass


func apply_theme() -> void:
	super.apply_theme()
	ui.style_field_label(language_label)
	ui.style_field_label(markdown_label)
	ui.style_field_label(ui_scale_label)
	for select in [language_select, ui_scale_select]:
		ButtonStyle.apply_option_button(select)
		select.get_popup().add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(
			ThemeColor.card_surface, ControlSize.radius_lg, Margin.ma_1, Margin.ma_1,
			Color(ThemeColor.title_color, 0.10), ControlSize.border_xs))
	ButtonStyle.apply_check_button(markdown_toggle_button)
	pass
