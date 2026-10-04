class_name SenseButton
extends RefCounted

## Sense input-method settings, including prompt-library search and live hotkey rebinding.

const DIALOG_SIZE := Vector2i(880, 1000)
const PROMPT_FILES := {I18n.ZH: "res://agent/config/prompts/zh.json", I18n.EN: "res://agent/config/prompts/en.json"}
const MAX_RESULTS := 30

var button: Button
var sense_input: SenseInput
var dialog: Window
var content_panel: PanelContainer
var title_label: Label
var enabled_check: CheckButton
var backend_select: OptionButton
var hotkey_button: Button
var prompt_edit: TextEdit
var search_edit: LineEdit
var results: ItemList
var prompt_entries: Array[Dictionary] = []
var separators: Array[HSeparator] = []
var field_labels: Array[Label] = []
var recording_hotkey: bool = false


func setup(p_button: Button, p_sense_input: SenseInput) -> void:
	button = p_button
	sense_input = p_sense_input
	build_dialog()
	button.pressed.connect(on_button_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_locale)
	apply_locale()
	apply_theme()
	pass


func build_dialog() -> void:
	dialog = ConfirmationDialog.new()
	dialog.title = ""
	dialog.borderless = true
	dialog.size = DIALOG_SIZE
	dialog.min_size = Vector2i(640, 680)
	dialog.transient = true
	dialog.unresizable = true
	dialog.exclusive = false
	dialog.visible = false
	dialog.close_requested.connect(dialog.hide)
	dialog.focus_exited.connect(on_dialog_focus_exited)
	button.add_child(dialog)
	(dialog as ConfirmationDialog).get_ok_button().hide()
	(dialog as ConfirmationDialog).get_cancel_button().hide()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, Margin.ma_5)
	dialog.add_child(margin)
	content_panel = PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content_panel)
	var card_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		card_margin.add_theme_constant_override(side, Margin.ma_3)
	content_panel.add_child(card_margin)
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", Margin.ma_3)
	card_margin.add_child(fields)
	title_label = Label.new()
	title_label.text = I18n.t("agent.sense.settings_title")
	title_label.add_theme_font_size_override("font_size", Typography.title_large_size)
	fields.add_child(title_label)
	var quick_settings := HBoxContainer.new()
	quick_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_settings.add_theme_constant_override("separation", Margin.ma_3)
	fields.add_child(quick_settings)
	var left_settings := HBoxContainer.new()
	left_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_settings.add_theme_constant_override("separation", Margin.ma_3)
	quick_settings.add_child(left_settings)
	var enabled_field := make_inline_field(left_settings, I18n.t("agent.sense.input_method"))
	enabled_field.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var enabled_control := HBoxContainer.new()
	enabled_control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	enabled_field.add_child(enabled_control)
	enabled_check = CheckButton.new()
	enabled_check.text = ""
	enabled_check.tooltip_text = I18n.t("agent.sense.enabled_tooltip")
	enabled_check.focus_mode = Control.FOCUS_NONE
	enabled_check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	enabled_check.toggled.connect(on_enabled_toggled)
	enabled_control.add_child(enabled_check)
	var model_field := make_inline_field(left_settings, I18n.t("agent.sense.model"))
	backend_select = OptionButton.new()
	backend_select.custom_minimum_size = Vector2(0, 38)
	backend_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backend_select.add_item(I18n.t("agent.sense.local_model"))
	backend_select.add_item(I18n.t("agent.sense.remote_model"))
	backend_select.item_selected.connect(on_backend_selected)
	backend_select.get_popup().popup_hide.connect(on_option_popup_hide)
	model_field.add_child(backend_select)
	var hotkey_field := make_inline_field(quick_settings, I18n.t("agent.sense.hotkey"))
	hotkey_button = Button.new()
	hotkey_button.custom_minimum_size.y = ControlSize.lg
	hotkey_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hotkey_button.tooltip_text = I18n.t("agent.sense.hotkey_tooltip")
	hotkey_button.pressed.connect(on_hotkey_capture_started)
	hotkey_button.gui_input.connect(on_hotkey_input)
	hotkey_field.add_child(hotkey_button)
	add_separator(fields)
	fields.add_child(make_label(I18n.t("agent.sense.system_prompt")))
	prompt_edit = TextEdit.new()
	prompt_edit.custom_minimum_size.y = 210
	prompt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	prompt_edit.placeholder_text = I18n.t("agent.sense.system_prompt_placeholder")
	prompt_edit.focus_exited.connect(save_prompt)
	fields.add_child(prompt_edit)
	add_separator(fields)
	fields.add_child(make_label(I18n.t("agent.sense.prompt_search")))
	var search_column := VBoxContainer.new()
	search_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_column.add_theme_constant_override("separation", Margin.ma_2)
	fields.add_child(search_column)
	search_edit = LineEdit.new()
	search_edit.clear_button_enabled = true
	search_edit.placeholder_text = I18n.t("agent.sense.prompt_search_placeholder")
	search_edit.tooltip_text = I18n.t("agent.sense.prompt_search_tooltip")
	search_edit.text_changed.connect(refresh_results)
	search_column.add_child(search_edit)
	results = ItemList.new()
	results.custom_minimum_size.y = 260
	results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results.item_activated.connect(insert_prompt)
	search_column.add_child(results)
	pass


func add_separator(parent: Container) -> void:
	var separator := HSeparator.new()
	separators.append(separator)
	parent.add_child(separator)
	pass


func make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", Typography.label_large_size)
	field_labels.append(label)
	return label


func make_inline_field(parent: Container, label_text: String) -> HBoxContainer:
	var field := HBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", Margin.ma_2)
	parent.add_child(field)
	var label := make_label(label_text)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	field.add_child(label)
	return field


func on_button_pressed() -> void:
	enabled_check.set_pressed_no_signal(SenseSetting.is_enabled())
	backend_select.select(0 if SenseSetting.use_local_model() else 1)
	hotkey_button.text = SenseSetting.hotkey_text()
	prompt_edit.text = SenseSetting.get_system_prompt()
	load_prompt_entries()
	refresh_results(search_edit.text)
	dialog.popup_centered(DIALOG_SIZE)
	pass


func on_enabled_toggled(enabled: bool) -> void:
	SenseSetting.set_enabled(enabled)
	sense_input.apply_settings()
	pass


func on_backend_selected(index: int) -> void:
	SenseSetting.set_use_local_model(index == 0)
	sense_input.apply_settings()
	pass


func on_hotkey_capture_started() -> void:
	recording_hotkey = true
	hotkey_button.text = I18n.t("agent.sense.hotkey_capture")
	hotkey_button.grab_focus()
	pass


func on_hotkey_input(event: InputEvent) -> void:
	if not recording_hotkey or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode in [KEY_CTRL, KEY_ALT, KEY_SHIFT, KEY_META]:
		return
	var modifiers := key_event.get_modifiers_mask()
	if modifiers == 0 or not Engine.has_singleton("GlobalHotkey") or not GlobalHotkey.is_key_supported(key_event.keycode):
		hotkey_button.text = I18n.t("agent.sense.hotkey_invalid")
		return
	recording_hotkey = false
	SenseSetting.set_hotkey(key_event.keycode, modifiers)
	hotkey_button.text = SenseSetting.hotkey_text()
	sense_input.apply_settings()
	hotkey_button.accept_event()
	pass


func save_prompt() -> void:
	SenseSetting.set_system_prompt(prompt_edit.text)
	pass


func load_prompt_entries() -> void:
	prompt_entries.clear()
	var locale := I18n.get_locale()
	var path: String = PROMPT_FILES.get(locale, PROMPT_FILES[I18n.EN])
	var parsed: Variant = JSON.parse_string(FileUtils.read_file_to_string(path))
	if not parsed is Array:
		return
	for value: Variant in parsed:
		if value is Dictionary:
			prompt_entries.append(value as Dictionary)
	pass


func refresh_results(query: String) -> void:
	results.clear()
	var needle := query.strip_edges().to_lower()
	for entry in prompt_entries:
		var title := str(entry.get("title", ""))
		var prompt := str(entry.get("prompt", ""))
		if not needle.is_empty() and not title.to_lower().contains(needle) and not prompt.to_lower().contains(needle):
			continue
		results.add_item(title)
		results.set_item_metadata(results.item_count - 1, prompt)
		if results.item_count >= MAX_RESULTS:
			break
	pass


func insert_prompt(index: int) -> void:
	var prompt := str(results.get_item_metadata(index)).strip_edges()
	if prompt.is_empty():
		return
	if not prompt_edit.text.strip_edges().is_empty():
		prompt_edit.insert_text_at_caret("\n\n")
	prompt_edit.insert_text_at_caret(prompt)
	SenseSetting.set_system_prompt(prompt_edit.text)
	prompt_edit.grab_focus()
	pass


func apply_theme() -> void:
	AgentToolbarButton.style(button, I18n.t("agent.sense.settings_tooltip"))
	button.text = "Sense"
	var dialog_style := StyleBoxHelper.create_style_box_flat(ColorBase.surface)
	dialog_style.expand_margin_right = Margin.ma_1
	dialog_style.expand_margin_bottom = Margin.ma_1
	dialog.add_theme_stylebox_override("panel", dialog_style)
	dialog.add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	dialog.add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())
	dialog.add_theme_constant_override("resize_margin", Margin.ma_0)
	dialog.add_theme_constant_override("buttons_separation", Margin.ma_0)
	content_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	title_label.add_theme_color_override("font_color", ColorBase.primary_text)
	for label in field_labels:
		label.add_theme_color_override("font_color", ColorBase.primary_text)
	var separator_style := StyleBoxLine.new()
	separator_style.color = ThemeColor.accent_theme_color()
	separator_style.thickness = 1
	for separator in separators:
		separator.add_theme_stylebox_override("separator", separator_style)
	style_check_button(enabled_check)
	style_option_button(backend_select)
	style_button(hotkey_button)
	style_text_edit(prompt_edit)
	style_line_edit(search_edit)
	style_results()
	pass


func check_dialog_focus() -> void:
	if dialog.visible and not backend_select.get_popup().visible and not dialog.has_focus():
		dialog.hide()
	pass


func on_dialog_focus_exited() -> void:
	check_dialog_focus.call_deferred()
	pass


func on_option_popup_hide() -> void:
	check_dialog_focus.call_deferred()
	pass


func apply_locale() -> void:
	title_label.text = I18n.t("agent.sense.settings_title")
	field_labels[0].text = I18n.t("agent.sense.input_method")
	field_labels[1].text = I18n.t("agent.sense.model")
	field_labels[2].text = I18n.t("agent.sense.hotkey")
	field_labels[3].text = I18n.t("agent.sense.system_prompt")
	field_labels[4].text = I18n.t("agent.sense.prompt_search")
	enabled_check.tooltip_text = I18n.t("agent.sense.enabled_tooltip")
	backend_select.set_item_text(0, I18n.t("agent.sense.local_model"))
	backend_select.set_item_text(1, I18n.t("agent.sense.remote_model"))
	hotkey_button.tooltip_text = I18n.t("agent.sense.hotkey_tooltip")
	prompt_edit.placeholder_text = I18n.t("agent.sense.system_prompt_placeholder")
	search_edit.placeholder_text = I18n.t("agent.sense.prompt_search_placeholder")
	search_edit.tooltip_text = I18n.t("agent.sense.prompt_search_tooltip")
	if recording_hotkey:
		hotkey_button.text = I18n.t("agent.sense.hotkey_capture")
	if dialog.visible:
		load_prompt_entries()
		refresh_results(search_edit.text)
	apply_theme()
	pass


func make_input_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(ColorBase.surface, 7, Margin.ma_3, Margin.ma_0, ColorBase.border, ControlSize.border_xs)


func style_line_edit(edit: LineEdit) -> void:
	edit.add_theme_color_override("font_color", ColorBase.primary_text)
	edit.add_theme_color_override("font_placeholder_color", ColorBase.secondary_text.darkened(0.08))
	edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	edit.caret_blink = true
	var normal := make_input_style()
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = ThemeColor.accent_theme_color()
	focus.set_border_width_all(ControlSize.border_sm)
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focus)
	pass


func style_text_edit(edit: TextEdit) -> void:
	edit.add_theme_color_override("font_color", ColorBase.primary_text)
	edit.add_theme_color_override("font_placeholder_color", ColorBase.secondary_text.darkened(0.08))
	edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	edit.add_theme_color_override("selection_color", ThemeColor.selected_surface)
	edit.caret_blink = true
	var normal := make_input_style()
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = ThemeColor.accent_theme_color()
	focus.set_border_width_all(ControlSize.border_sm)
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_stylebox_override("read_only", normal.duplicate())
	pass


func style_option_button(select: OptionButton) -> void:
	ButtonStyle.apply_font_colors(select, ColorBase.primary_text, ColorBase.primary_text, ColorBase.primary_text)
	var normal: StyleBoxFlat = make_input_style()
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.border_color = ThemeColor.accent_theme_color()
	select.add_theme_stylebox_override("normal", normal)
	select.add_theme_stylebox_override("hover", hover)
	select.add_theme_stylebox_override("pressed", hover.duplicate())
	select.add_theme_stylebox_override("focus", hover.duplicate())
	style_option_popup(select.get_popup())
	pass


func style_option_popup(popup: PopupMenu) -> void:
	popup.add_theme_color_override("font_color", ColorBase.primary_text)
	popup.add_theme_color_override("font_hover_color", ColorBase.primary_text)
	popup.add_theme_color_override("font_accelerator_color", ColorBase.secondary_text)
	popup.add_theme_color_override("font_disabled_color", ColorBase.secondary_text)
	popup.add_theme_color_override("font_separator_color", ColorBase.secondary_text)
	popup.add_theme_font_size_override("font_size", Typography.label_large_size)
	popup.add_theme_constant_override("v_separation", Margin.ma_2)
	popup.add_theme_constant_override("item_start_padding", Margin.ma_3)
	popup.add_theme_constant_override("item_end_padding", Margin.ma_3)
	popup.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(ColorBase.surface, 7, Margin.ma_1, Margin.ma_1, ColorBase.border, ControlSize.border_xs))
	popup.add_theme_stylebox_override("hover", StyleBoxHelper.create_style_box_flat(ThemeColor.selected_surface, 5, Margin.ma_2, 0))
	var empty_icon := ImageTexture.new()
	for state: String in ["radio_checked", "radio_unchecked", "checked", "unchecked"]:
		popup.add_theme_icon_override(state, empty_icon)
	pass


func style_check_button(check: CheckButton) -> void:
	check.add_theme_color_override("font_color", ColorBase.primary_text)
	check.add_theme_color_override("font_hover_color", ColorBase.primary_text)
	check.add_theme_color_override("button_checked_color", ThemeColor.accent_theme_color())
	var normal := StyleBoxEmpty.new()
	var hover := StyleBoxHelper.create_style_box_flat(ColorBase.hover_surface, 6)
	check.add_theme_stylebox_override("normal", normal)
	check.add_theme_stylebox_override("focus", normal.duplicate())
	check.add_theme_stylebox_override("hover", hover)
	check.add_theme_stylebox_override("pressed", hover.duplicate())
	check.add_theme_stylebox_override("hover_pressed", hover.duplicate())
	pass


func style_button(control: Button) -> void:
	ButtonStyle.apply_font_colors(control, ColorBase.primary_text, ColorBase.primary_text, ThemeColor.accent_theme_color())
	var normal := make_input_style()
	ButtonStyle.apply(control, normal, ButtonStyle.filled(normal, ColorBase.hover_surface), ButtonStyle.filled(normal, ThemeColor.selected_surface))
	pass


func style_results() -> void:
	results.add_theme_color_override("font_color", ColorBase.primary_text)
	results.add_theme_color_override("font_hovered_color", ColorBase.primary_text)
	results.add_theme_color_override("font_selected_color", ColorBase.primary_text)
	results.add_theme_stylebox_override("panel", make_input_style())
	results.add_theme_stylebox_override("hovered", StyleBoxHelper.create_style_box_flat(ColorBase.hover_surface, 5))
	results.add_theme_stylebox_override("selected", StyleBoxHelper.create_style_box_flat(ThemeColor.selected_surface, 5))
	results.add_theme_stylebox_override("selected_focus", StyleBoxHelper.create_style_box_flat(ThemeColor.selected_surface, 5, 0, 0, ThemeColor.accent_theme_color(), ControlSize.border_xs))
	pass
