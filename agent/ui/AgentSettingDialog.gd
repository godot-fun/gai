class_name AgentSettingDialog
extends RefCounted

## Toolbar UI for editing the persisted API connection and notification settings.
## There is no Save button: every field writes straight to [Setting] once editing finishes.

const DIALOG_SIZE: Vector2i = Vector2i(680, 1000)
const FOLDER_DIALOG_SIZE: Vector2i = Vector2i(900, 600)
const FIELD_LABEL_RATIO: float = 0.2
const FIELD_CONTROL_RATIO: float = 0.8
const SETTINGS_ICON_PATH: String = "res://agent/asset/image/icon/settings.svg"

var button: Button
var dialog: ConfirmationDialog
var content_panel: PanelContainer
var content_scroll: ScrollContainer
var appearance_heading_label: Label
var notification_heading_label: Label
var language_select: OptionButton
var heading_label: Label
var description_label: Label
var provider_select: OptionButton
var api_url_edit: LineEdit
var model_edit: LineEdit
var api_token_edit: LineEdit
var proxy_address_edit: LineEdit
var toast_toggle_button: CheckButton
var sound_toggle_button: CheckButton
var sound_seconds_group: HBoxContainer
var sound_folder_row: HBoxContainer
var sound_seconds_spin: SpinBox
var sound_folder_edit: LineEdit
var sound_folder_dialog: FileDialog
## True once the path was edited by hand, so a click no longer means "pick a folder".
var folder_field_typing: bool = false
var field_labels: Array[Label] = []
var help_labels: Array[Label] = []
var separators: Array[HSeparator] = []


func setup(p_button: Button) -> void:
	button = p_button
	build_dialog()
	button.text = ""
	button.icon = load(SETTINGS_ICON_PATH) as Texture2D
	button.pressed.connect(on_button_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_locale)
	apply_theme()
	pass


func build_dialog() -> void:
	dialog = ConfirmationDialog.new()
	dialog.title = ""
	dialog.borderless = true
	dialog.min_size = DIALOG_SIZE
	dialog.max_size = DIALOG_SIZE
	dialog.unresizable = true
	dialog.exclusive = false
	var dialog_theme := Theme.new()
	dialog_theme.default_font = Fonts.regular()
	dialog.theme = dialog_theme
	dialog.add_theme_font_override("title_font", Fonts.regular())
	dialog.focus_exited.connect(on_dialog_focus_exited)
	dialog.visibility_changed.connect(on_dialog_visibility_changed)
	button.add_child(dialog)
	# Every field auto-saves, so the default OK / Cancel row would only be noise.
	dialog.get_ok_button().hide()
	dialog.get_cancel_button().hide()

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", Margin.ma_5)
	margin.add_theme_constant_override("margin_right", Margin.ma_5)
	margin.add_theme_constant_override("margin_top", Margin.ma_3)
	margin.add_theme_constant_override("margin_bottom", Margin.ma_3)
	dialog.add_child(margin)

	content_panel = PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content_panel)
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", Margin.ma_5)
	card_margin.add_theme_constant_override("margin_right", Margin.ma_5)
	card_margin.add_theme_constant_override("margin_top", Margin.ma_4)
	card_margin.add_theme_constant_override("margin_bottom", Margin.ma_4)
	content_panel.add_child(card_margin)

	# The rows outgrow a short window, so keep them reachable instead of clipping the last one.
	content_scroll = ScrollContainer.new()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_margin.add_child(content_scroll)

	var fields: VBoxContainer = VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", Margin.ma_3)
	content_scroll.add_child(fields)
	appearance_heading_label = Label.new()
	appearance_heading_label.text = I18n.t("agent.settings.appearance")
	appearance_heading_label.add_theme_font_size_override("font_size", Typography.title_large_size)
	fields.add_child(appearance_heading_label)
	add_language_field(fields)
	add_separator(fields)
	heading_label = Label.new()
	heading_label.text = I18n.t("agent.settings.heading")
	heading_label.add_theme_font_size_override("font_size", Typography.title_large_size)
	fields.add_child(heading_label)
	description_label = Label.new()
	description_label.text = I18n.t("agent.settings.description")
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", Typography.body_small_size)
	fields.add_child(description_label)
	provider_select = add_provider_field(fields)
	api_url_edit = add_field(fields, I18n.t("agent.settings.api_endpoint"), "https://api.example.com/v1/chat/completions", I18n.t("agent.settings.api_endpoint_help"))
	model_edit = add_field(fields, I18n.t("agent.settings.model"), ApiSetting.DEFAULT_MODEL, I18n.t("agent.settings.model_help"))
	api_token_edit = add_token_field(fields)
	proxy_address_edit = add_field(fields, I18n.t("agent.settings.proxy"), "http://127.0.0.1:10809", I18n.t("agent.settings.proxy_help"))
	for edit: LineEdit in [api_url_edit, model_edit, api_token_edit, proxy_address_edit]:
		bind_auto_save(edit, save_api_settings)
	add_separator(fields)
	notification_heading_label = Label.new()
	notification_heading_label.text = I18n.t("agent.settings.notification")
	notification_heading_label.add_theme_font_size_override("font_size", Typography.title_large_size)
	fields.add_child(notification_heading_label)
	add_notify_fields(fields)
	add_separator(fields)
	build_folder_dialog()
	pass


func add_separator(parent: Container) -> HSeparator:
	var separator := HSeparator.new()
	separators.append(separator)
	parent.add_child(separator)
	return separator


func add_language_field(parent: VBoxContainer) -> void:
	var group := make_field_group(parent)
	var row := make_field_row(group, I18n.t("agent.settings.language"))
	language_select = OptionButton.new()
	language_select.custom_minimum_size = Vector2(0, 38)
	language_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_select.size_flags_stretch_ratio = FIELD_CONTROL_RATIO
	for locale: String in I18nHelper.LOCALE_PATHS:
		var config: I18nHelper.LocaleConfig = I18nHelper.LOCALE_PATHS[locale]
		language_select.add_item(config.language)
		language_select.set_item_metadata(language_select.item_count - 1, locale)
	language_select.item_selected.connect(on_language_selected)
	language_select.get_popup().popup_hide.connect(on_provider_popup_hide)
	row.add_child(language_select)
	select_current_language()
	pass


func select_current_language() -> void:
	var current_locale := I18n.get_locale()
	for index in range(language_select.item_count):
		if str(language_select.get_item_metadata(index)) == current_locale:
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


## Notification options, one row each, every row hugging the left edge: the toast toggle, the
## sound toggle with its duration, then the clip folder. Duration and folder hide with the sound.
func add_notify_fields(parent: VBoxContainer) -> void:
	toast_toggle_button = add_check_button(make_option_row(parent, Margin.ma_2), I18n.t("agent.settings.notification_window"), AgentSetting.get_notification_window())
	toast_toggle_button.toggled.connect(on_toast_toggled)

	var sound_row: HBoxContainer = make_option_row(parent, Margin.ma_4)
	sound_toggle_button = add_check_button(sound_row, I18n.t("agent.settings.notification_sound"), AgentSetting.get_notification_sound())
	sound_toggle_button.toggled.connect(on_sound_toggled)
	sound_seconds_group = add_sound_seconds_group(sound_row)

	sound_folder_row = make_option_row(parent, Margin.ma_2)
	sound_folder_edit = LineEdit.new()
	sound_folder_edit.custom_minimum_size = Vector2(0, 34)
	sound_folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_folder_edit.placeholder_text = AgentSetting.DEFAULT_SOUND_FOLDER
	sound_folder_edit.text = AgentSetting.get_notification_sound_folder()
	sound_folder_edit.tooltip_text = I18n.t("agent.settings.sound_folder_help")
	sound_folder_edit.gui_input.connect(on_sound_folder_input)
	sound_folder_edit.text_changed.connect(on_sound_folder_text_changed)
	sound_folder_row.add_child(sound_folder_edit)
	bind_auto_save(sound_folder_edit, save_sound_folder)

	update_sound_options_visible(AgentSetting.get_notification_sound())
	pass


## Sound length, saved on every step.
func add_sound_seconds_group(parent: HBoxContainer) -> HBoxContainer:
	var group: HBoxContainer = make_option_row(parent, Margin.ma_2)
	group.add_child(make_label(I18n.t("agent.settings.sound_duration")))
	sound_seconds_spin = SpinBox.new()
	sound_seconds_spin.min_value = AgentSetting.MIN_SOUND_SECONDS
	sound_seconds_spin.max_value = AgentSetting.MAX_SOUND_SECONDS
	sound_seconds_spin.step = 1
	sound_seconds_spin.suffix = " s"
	sound_seconds_spin.custom_minimum_size = Vector2(104, 34)
	sound_seconds_spin.value = AgentSetting.get_notification_sound_seconds()
	sound_seconds_spin.value_changed.connect(on_sound_seconds_changed)
	group.add_child(sound_seconds_spin)
	return group


## Options row with its own gap: label-to-control and group-to-group gaps differ.
func make_option_row(parent: Container, separation: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row


## Folder picker behind the path field — no Browse button, clicking the field opens it.
func build_folder_dialog() -> void:
	sound_folder_dialog = FileDialog.new()
	sound_folder_dialog.title = I18n.t("agent.settings.sound_folder_title")
	sound_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	sound_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	sound_folder_dialog.ok_button_text = I18n.t("agent.common.select")
	sound_folder_dialog.size = FOLDER_DIALOG_SIZE
	sound_folder_dialog.dir_selected.connect(on_sound_folder_selected)
	dialog.add_child(sound_folder_dialog)
	pass


## Caption label — centered so it lines up with the control on the row next to it.
func make_label(label_text: String) -> Label:
	var label: Label = Label.new()
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Typography.label_large_size)
	field_labels.append(label)
	return label


## Field group containing one horizontal label/control row and an optional help line.
func make_field_group(parent: Container) -> VBoxContainer:
	var group: VBoxContainer = VBoxContainer.new()
	group.add_theme_constant_override("separation", Margin.ma_2)
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(group)
	return group


func make_field_row(parent: Container, label_text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Margin.ma_3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var label := make_label(label_text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = FIELD_LABEL_RATIO
	row.add_child(label)
	return row


## Grey help line closing a field group.
func add_help_label(parent: Container, help_text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Margin.ma_3)
	parent.add_child(row)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = FIELD_LABEL_RATIO
	row.add_child(spacer)
	var help: Label = Label.new()
	help.text = help_text
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.size_flags_stretch_ratio = FIELD_CONTROL_RATIO
	help.add_theme_font_size_override("font_size", Typography.label_small_size)
	help_labels.append(help)
	row.add_child(help)
	pass


## Input field with the shared look: 38px tall, clear button, filling the row.
func make_line_edit(placeholder: String) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.custom_minimum_size = Vector2(0, 38)
	edit.placeholder_text = placeholder
	edit.clear_button_enabled = true
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.size_flags_stretch_ratio = FIELD_CONTROL_RATIO
	return edit


## Persist a line edit as soon as the user leaves it or presses Enter.
func bind_auto_save(edit: LineEdit, saver: Callable) -> void:
	edit.focus_exited.connect(saver)
	edit.text_submitted.connect(func(_text: String) -> void: saver.call())
	pass


func add_provider_field(parent: VBoxContainer) -> OptionButton:
	var group := make_field_group(parent)
	var row := make_field_row(group, I18n.t("agent.settings.provider"))
	var select: OptionButton = OptionButton.new()
	select.custom_minimum_size = Vector2(0, 38)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.size_flags_stretch_ratio = FIELD_CONTROL_RATIO
	select.add_item(I18n.t("agent.settings.custom_provider"))
	for provider: ApiProvider in ApiSupport.PROVIDERS:
		select.add_item(provider.name)
	select.item_selected.connect(on_provider_selected)
	select.get_popup().popup_hide.connect(on_provider_popup_hide)
	row.add_child(select)
	add_help_label(group, I18n.t("agent.settings.provider_help"))
	return select


func add_field(parent: Container, label_text: String, placeholder: String, help_text: String) -> LineEdit:
	var group := make_field_group(parent)
	var row := make_field_row(group, label_text)
	var edit: LineEdit = make_line_edit(placeholder)
	row.add_child(edit)
	add_help_label(group, help_text)
	return edit


func add_token_field(parent: VBoxContainer) -> LineEdit:
	var group := make_field_group(parent)
	var row := make_field_row(group, I18n.t("agent.settings.api_token"))
	var edit: LineEdit = make_line_edit("sk-...")
	edit.secret = true
	edit.secret_character = "*"
	row.add_child(edit)
	add_help_label(group, I18n.t("agent.settings.token_help"))
	return edit


## Check button with the theme-color-tinted switch: on / off is the switch itself, no On / Off caption.
func add_check_button(parent: Container, label_text: String, enabled: bool) -> CheckButton:
	var check: CheckButton = CheckButton.new()
	check.text = label_text
	check.button_pressed = enabled
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_size_override("font_size", Typography.label_large_size)
	parent.add_child(check)
	return check


## Check button: the switch is the built-in toggle icon, tinted with the CheckButton theme colors.
func style_check_button(check: CheckButton) -> void:
	check.add_theme_color_override("font_color", ColorBase.primary_text)
	check.add_theme_color_override("font_hover_color", ColorBase.primary_text)
	check.add_theme_color_override("font_focus_color", ColorBase.primary_text)
	check.add_theme_color_override("font_pressed_color", ColorBase.primary_text)
	check.add_theme_color_override("font_hover_pressed_color", ColorBase.primary_text)
	# Only the "on" track takes the theme color — the "off" one keeps the theme default.
	check.add_theme_color_override("button_checked_color", ThemeColor.accent_theme_color())
	check.add_theme_constant_override("h_separation", Margin.ma_2)
	# No left inset, so the caption lines up with the labels and fields around it. The margins are
	# the same on every state, otherwise hovering would shift the row.
	var empty := StyleBoxEmpty.new()
	StyleBoxHelper.apply_style_box_margin(empty, Margin.ma_0, Margin.ma_1, Margin.ma_2, Margin.ma_1)
	check.add_theme_stylebox_override("normal", empty)
	check.add_theme_stylebox_override("disabled", empty.duplicate())
	check.add_theme_stylebox_override("focus", empty.duplicate())
	check.add_theme_stylebox_override("hover", empty.duplicate())
	check.add_theme_stylebox_override("pressed", empty.duplicate())
	check.add_theme_stylebox_override("hover_pressed", empty.duplicate())
	pass


## Duration and clip folder only matter while the sound toggle is on: hiding the whole folder row
## drops its gap too, so the block collapses onto the two toggles.
func update_sound_options_visible(enabled: bool) -> void:
	sound_seconds_group.visible = enabled
	sound_folder_row.visible = enabled
	pass


func on_button_pressed() -> void:
	select_current_language()
	api_url_edit.text = ApiSetting.get_api_url()
	model_edit.text = ApiSetting.get_model()
	provider_select.select(0)
	api_token_edit.text = ApiSetting.get_api_token()
	proxy_address_edit.text = ApiSetting.get_proxy_address()
	api_token_edit.secret = true
	refresh_check_button(toast_toggle_button, AgentSetting.get_notification_window())
	refresh_check_button(sound_toggle_button, AgentSetting.get_notification_sound())
	update_sound_options_visible(sound_toggle_button.button_pressed)
	sound_seconds_spin.set_value_no_signal(AgentSetting.get_notification_sound_seconds())
	sound_folder_edit.text = AgentSetting.get_notification_sound_folder()
	folder_field_typing = false
	dialog.popup_centered(DIALOG_SIZE)
	dialog.size = DIALOG_SIZE
	pass


## Writes a persisted toggle back into its button without firing `toggled`.
func refresh_check_button(check: CheckButton, enabled: bool) -> void:
	check.set_block_signals(true)
	check.button_pressed = enabled
	check.set_block_signals(false)
	pass


func on_provider_selected(selected_index: int) -> void:
	if selected_index <= 0:
		return
	var provider: ApiProvider = ApiSupport.get_provider(selected_index - 1)
	if provider == null:
		return
	api_url_edit.text = provider.api_url
	model_edit.text = provider.model
	save_api_settings()
	pass


func on_toast_toggled(enabled: bool) -> void:
	AgentSetting.set_notification_window(enabled)
	pass


func on_sound_toggled(enabled: bool) -> void:
	AgentSetting.set_notification_sound(enabled)
	update_sound_options_visible(enabled)
	pass


func on_sound_seconds_changed(seconds: float) -> void:
	AgentSetting.set_notification_sound_seconds(roundi(seconds))
	pass


## A click on the path field opens the folder picker, until the path itself is being typed:
## after a manual edit, clicks place the caret instead of popping the picker back up.
func on_sound_folder_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if folder_field_typing:
		return
	open_sound_folder_dialog()
	pass


func on_sound_folder_text_changed(_text: String) -> void:
	folder_field_typing = true
	pass


func open_sound_folder_dialog() -> void:
	if sound_folder_dialog.visible:
		return
	var folder: String = AgentSetting.get_notification_sound_folder()
	if not folder.begins_with("res://") and not folder.begins_with("user://") and DirAccess.dir_exists_absolute(folder):
		sound_folder_dialog.current_dir = folder
	sound_folder_dialog.popup_centered(FOLDER_DIALOG_SIZE)
	pass


func on_sound_folder_selected(folder: String) -> void:
	sound_folder_edit.text = folder
	save_sound_folder()
	pass


## Editing finishes when the user leaves a field, presses Enter or the dialog is dismissed.
func save_api_settings() -> void:
	ApiSetting.save(api_url_edit.text, api_token_edit.text, model_edit.text, proxy_address_edit.text)
	pass


func save_sound_folder() -> void:
	AgentSetting.set_notification_sound_folder(sound_folder_edit.text)
	pass


func save_all_settings() -> void:
	save_api_settings()
	save_sound_folder()
	pass


func on_dialog_visibility_changed() -> void:
	# The dialog has no Save button: persist the fields as it closes.
	if dialog.visible or api_url_edit == null:
		return
	save_all_settings()
	pass


func on_dialog_focus_exited() -> void:
	check_dialog_focus.call_deferred()
	pass


func on_provider_popup_hide() -> void:
	check_dialog_focus.call_deferred()
	pass


func check_dialog_focus() -> void:
	if not dialog.visible or provider_select.get_popup().visible or language_select.get_popup().visible or sound_folder_dialog.visible:
		return
	if not dialog.has_focus():
		dialog.hide()
	pass


func apply_locale() -> void:
	appearance_heading_label.text = I18n.t("agent.settings.appearance")
	notification_heading_label.text = I18n.t("agent.settings.notification")
	heading_label.text = I18n.t("agent.settings.heading")
	description_label.text = I18n.t("agent.settings.description")
	field_labels[0].text = I18n.t("agent.settings.language")
	field_labels[1].text = I18n.t("agent.settings.provider")
	field_labels[2].text = I18n.t("agent.settings.api_endpoint")
	field_labels[3].text = I18n.t("agent.settings.model")
	field_labels[4].text = I18n.t("agent.settings.api_token")
	field_labels[5].text = I18n.t("agent.settings.proxy")
	field_labels[6].text = I18n.t("agent.settings.sound_duration")
	help_labels[0].text = I18n.t("agent.settings.provider_help")
	help_labels[1].text = I18n.t("agent.settings.api_endpoint_help")
	help_labels[2].text = I18n.t("agent.settings.model_help")
	help_labels[3].text = I18n.t("agent.settings.token_help")
	help_labels[4].text = I18n.t("agent.settings.proxy_help")
	provider_select.set_item_text(0, I18n.t("agent.settings.custom_provider"))
	toast_toggle_button.text = I18n.t("agent.settings.notification_window")
	sound_toggle_button.text = I18n.t("agent.settings.notification_sound")
	sound_folder_edit.tooltip_text = I18n.t("agent.settings.sound_folder_help")
	sound_folder_dialog.title = I18n.t("agent.settings.sound_folder_title")
	sound_folder_dialog.ok_button_text = I18n.t("agent.common.select")
	select_current_language()
	apply_theme()
	pass


func apply_theme() -> void:
	AgentToolbarButton.style_round(button, I18n.t("agent.settings.tooltip"))
	button.add_theme_constant_override("icon_max_width", 16)
	button.add_theme_constant_override("icon_max_height", 16)
	button.add_theme_color_override("icon_normal_color", ColorBase.secondary_text)
	button.add_theme_color_override("icon_hover_color", ColorBase.primary_text)
	button.add_theme_color_override("icon_pressed_color", ColorBase.primary_text)
	button.add_theme_color_override("icon_focus_color", ColorBase.primary_text)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ScrollBarStyle.apply(content_scroll.get_v_scroll_bar())
	style_dialog()
	pass


func style_dialog() -> void:
	if dialog == null:
		return
	var dialog_style := StyleBoxHelper.create_style_box_flat(ThemeColor.accent_surface)
	dialog_style.expand_margin_right = Margin.ma_1
	dialog_style.expand_margin_bottom = Margin.ma_1
	dialog_style.content_margin_bottom = Margin.ma_4
	dialog.add_theme_stylebox_override("panel", dialog_style)
	dialog.add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	dialog.add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())
	dialog.add_theme_constant_override("resize_margin", Margin.ma_0)
	dialog.add_theme_constant_override("buttons_separation", Margin.ma_0)
	content_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	appearance_heading_label.add_theme_color_override("font_color", ColorBase.primary_text)
	notification_heading_label.add_theme_color_override("font_color", ColorBase.primary_text)
	heading_label.add_theme_color_override("font_color", ColorBase.primary_text)
	description_label.add_theme_color_override("font_color", ColorBase.secondary_text)
	for label: Label in field_labels:
		label.add_theme_color_override("font_color", ColorBase.primary_text)
	for help: Label in help_labels:
		help.add_theme_color_override("font_color", ColorBase.secondary_text)
	var separator_style := StyleBoxLine.new()
	separator_style.color = ThemeColor.accent_theme_color()
	separator_style.thickness = 1
	for separator: HSeparator in separators:
		separator.add_theme_stylebox_override("separator", separator_style)
	for edit: LineEdit in [api_url_edit, model_edit, api_token_edit, proxy_address_edit, sound_folder_edit]:
		style_line_edit(edit)
	style_option_button(provider_select)
	style_option_button(language_select)
	style_spin_box(sound_seconds_spin)
	style_check_button(toast_toggle_button)
	style_check_button(sound_toggle_button)
	pass


func style_option_button(select: OptionButton) -> void:
	# Every font state, focus included: the dialog hands the focus to this select when it pops up,
	# and the engine's focus text is near white.
	ButtonStyle.apply_font_colors(select, ColorBase.primary_text, ColorBase.primary_text, ColorBase.primary_text)
	var normal: StyleBoxFlat = make_input_style()
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.border_color = ThemeColor.accent_theme_color()
	select.add_theme_stylebox_override("normal", normal)
	select.add_theme_stylebox_override("hover", hover)
	select.add_theme_stylebox_override("pressed", hover.duplicate())
	select.add_theme_stylebox_override("focus", hover.duplicate())
	style_provider_popup(select.get_popup())
	pass


func style_provider_popup(popup: PopupMenu) -> void:
	popup.add_theme_font_override("font", Fonts.regular())
	popup.add_theme_color_override("font_color", ColorBase.primary_text)
	popup.add_theme_color_override("font_hover_color", ColorBase.primary_text)
	popup.add_theme_color_override("font_accelerator_color", ColorBase.secondary_text)
	popup.add_theme_color_override("font_disabled_color", ColorBase.secondary_text)
	popup.add_theme_color_override("font_separator_color", ColorBase.secondary_text)
	popup.add_theme_font_size_override("font_size", Typography.label_large_size)
	popup.add_theme_constant_override("v_separation", Margin.ma_2)
	popup.add_theme_constant_override("item_start_padding", Margin.ma_3)
	popup.add_theme_constant_override("item_end_padding", Margin.ma_3)
	popup.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, 7, Margin.ma_1, Margin.ma_1, Color(ThemeColor.title_color, 0.10), ControlSize.border_xs))
	popup.add_theme_stylebox_override("hover", StyleBoxHelper.create_style_box_flat(ThemeColor.selected_surface, 5, Margin.ma_2, 0))
	var empty_icon: ImageTexture = ImageTexture.new()
	for state: String in ["radio_checked", "radio_unchecked", "checked", "unchecked"]:
		popup.add_theme_icon_override(state, empty_icon)
	pass


func style_line_edit(edit: LineEdit) -> void:
	edit.add_theme_color_override("font_color", ColorBase.primary_text)
	edit.add_theme_color_override("font_placeholder_color", ColorBase.secondary_text.darkened(0.08))
	edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	edit.caret_blink = true
	var normal: StyleBoxFlat = make_input_style()
	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.border_color = ThemeColor.accent_theme_color()
	focus.set_border_width_all(ControlSize.border_sm)
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_stylebox_override("read_only", normal.duplicate())
	pass


## Field look shared by the line edits and the spin box buttons.
func make_input_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, 7, Margin.ma_3, Margin.ma_0, Color(ThemeColor.title_color, 0.10), ControlSize.border_xs)


## Spin box: theme-color arrows on the shared field background.
func style_spin_box(spin: SpinBox) -> void:
	style_line_edit(spin.get_line_edit())
	spin.add_theme_color_override("font_color", ColorBase.primary_text)
	spin.add_theme_color_override("font_placeholder_color", ColorBase.secondary_text)
	spin.add_theme_color_override("up_icon_modulate", ColorBase.primary_text)
	spin.add_theme_color_override("down_icon_modulate", ColorBase.primary_text)
	spin.add_theme_color_override("up_hover_icon_modulate", ThemeColor.accent_theme_color())
	spin.add_theme_color_override("down_hover_icon_modulate", ThemeColor.accent_theme_color())
	spin.add_theme_color_override("up_pressed_icon_modulate", ThemeColor.accent_theme_color())
	spin.add_theme_color_override("down_pressed_icon_modulate", ThemeColor.accent_theme_color())
	var normal: StyleBoxFlat = make_input_style()
	normal.content_margin_left = Margin.ma_0
	normal.content_margin_right = Margin.ma_0
	var hover := ButtonStyle.filled(normal, ColorBase.hover_surface)
	for side: String in ["up", "down"]:
		spin.add_theme_stylebox_override(side + "_background", normal)
		spin.add_theme_stylebox_override(side + "_background_hovered", hover)
		spin.add_theme_stylebox_override(side + "_background_pressed", hover.duplicate())
		spin.add_theme_stylebox_override(side + "_background_disabled", normal.duplicate())
	spin.add_theme_stylebox_override("field_and_buttons_separator", StyleBoxEmpty.new())
	spin.add_theme_stylebox_override("up_down_buttons_separator", StyleBoxEmpty.new())
	pass
