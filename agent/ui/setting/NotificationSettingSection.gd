class_name NotificationSettingSection
extends SettingSection

const FOLDER_DIALOG_SIZE: Vector2i = Vector2i(900, 600)

var toast_toggle_button: CheckButton
var sound_toggle_button: CheckButton
var toast_label: Label
var sound_label: Label
var sound_seconds_label: Label
var sound_folder_label: Label
var sound_folder_row: HBoxContainer
var sound_seconds_spin: SpinBox
var sound_folder_edit: LineEdit
var sound_folder_dialog: FileDialog
var folder_field_typing: bool = false


func set_up(p_ui: AgentSettingDialog, parent: VBoxContainer, dialog: ConfirmationDialog) -> void:
	super.set_up(p_ui, parent, dialog)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.notification"))
	var toast_parts := ui.make_setting_row(parent)
	toast_label = ui.make_label(I18n.t("agent.settings.notification_window"))
	toast_parts[0].add_child(toast_label)
	toast_label.tooltip_text = I18n.t("agent.settings.notification_window_help")
	toast_toggle_button = ui.add_check_button(toast_parts[1], "", AgentSetting.get_notification_window())
	toast_toggle_button.tooltip_text = I18n.t("agent.settings.notification_window_help")
	toast_toggle_button.toggled.connect(on_toast_toggled)
	var sound_parts := ui.make_setting_row(parent, 4)
	sound_label = ui.make_label(I18n.t("agent.settings.notification_sound"))
	sound_parts[0].add_child(sound_label)
	sound_label.tooltip_text = I18n.t("agent.settings.notification_sound_help")
	sound_toggle_button = ui.add_check_button(sound_parts[1], "", AgentSetting.get_notification_sound())
	sound_toggle_button.tooltip_text = I18n.t("agent.settings.notification_sound_help")
	sound_toggle_button.toggled.connect(on_sound_toggled)
	add_sound_seconds_controls(sound_parts[2], sound_parts[3])
	var folder_parts := ui.make_setting_row(parent)
	sound_folder_row = folder_parts[1]
	sound_folder_label = ui.make_label(I18n.t("agent.settings.sound_folder"))
	folder_parts[0].add_child(sound_folder_label)
	sound_folder_label.tooltip_text = I18n.t("agent.settings.sound_folder_help")
	sound_folder_edit = LineEdit.new()
	sound_folder_edit.custom_minimum_size = Vector2(0, 34)
	sound_folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_folder_edit.placeholder_text = AgentSetting.DEFAULT_SOUND_FOLDER
	sound_folder_edit.text = AgentSetting.get_notification_sound_folder()
	sound_folder_edit.tooltip_text = I18n.t("agent.settings.sound_folder_help")
	sound_folder_edit.gui_input.connect(on_sound_folder_input)
	sound_folder_edit.text_changed.connect(on_sound_folder_text_changed)
	sound_folder_row.add_child(sound_folder_edit)
	ui.bind_auto_save(sound_folder_edit, save)
	build_folder_dialog(dialog)
	update_sound_options_visible(AgentSetting.get_notification_sound())
	pass


func add_sound_seconds_controls(label_parent: HBoxContainer, spin_parent: HBoxContainer) -> void:
	sound_seconds_label = ui.make_label(I18n.t("agent.settings.sound_duration"))
	sound_seconds_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_parent.add_child(sound_seconds_label)
	sound_seconds_spin = SpinBox.new()
	sound_seconds_spin.min_value = AgentSetting.MIN_SOUND_SECONDS
	sound_seconds_spin.max_value = AgentSetting.MAX_SOUND_SECONDS
	sound_seconds_spin.step = 1
	sound_seconds_spin.suffix = " s"
	sound_seconds_spin.custom_minimum_size = Vector2(104, 34)
	sound_seconds_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_seconds_spin.value = AgentSetting.get_notification_sound_seconds()
	sound_seconds_spin.value_changed.connect(on_sound_seconds_changed)
	spin_parent.add_child(sound_seconds_spin)
	pass


func build_folder_dialog(dialog: ConfirmationDialog) -> void:
	sound_folder_dialog = FileDialog.new()
	sound_folder_dialog.title = I18n.t("agent.settings.sound_folder_title")
	sound_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	sound_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	sound_folder_dialog.ok_button_text = I18n.t("common.select")
	sound_folder_dialog.size = FOLDER_DIALOG_SIZE
	sound_folder_dialog.dir_selected.connect(on_sound_folder_selected)
	dialog.add_child(sound_folder_dialog)
	pass


func refresh() -> void:
	ui.refresh_check_button(toast_toggle_button, AgentSetting.get_notification_window())
	ui.refresh_check_button(sound_toggle_button, AgentSetting.get_notification_sound())
	update_sound_options_visible(sound_toggle_button.button_pressed)
	sound_seconds_spin.set_value_no_signal(AgentSetting.get_notification_sound_seconds())
	sound_folder_edit.text = AgentSetting.get_notification_sound_folder()
	folder_field_typing = false
	pass


func save() -> void:
	AgentSetting.set_notification_sound_folder(sound_folder_edit.text)
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


func update_sound_options_visible(enabled: bool) -> void:
	sound_seconds_label.visible = enabled
	sound_seconds_spin.visible = enabled
	sound_folder_label.visible = enabled
	sound_folder_row.visible = enabled
	pass


func on_sound_folder_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT or folder_field_typing:
		return
	open_sound_folder_dialog()
	pass


func on_sound_folder_text_changed(_text: String) -> void:
	folder_field_typing = true
	pass


func open_sound_folder_dialog() -> void:
	if sound_folder_dialog.visible:
		return
	var folder := AgentSetting.get_notification_sound_folder()
	if not folder.begins_with("res://") and not folder.begins_with("user://") and DirAccess.dir_exists_absolute(folder):
		sound_folder_dialog.current_dir = folder
	sound_folder_dialog.popup_centered(FOLDER_DIALOG_SIZE)
	sound_folder_dialog.oversampling_override = DisplayScale.compute_ui_scale()
	pass


func on_sound_folder_selected(folder: String) -> void:
	sound_folder_edit.text = folder
	save()
	pass


func apply_locale() -> void:
	heading_label.text = I18n.t("agent.settings.notification")
	toast_label.text = I18n.t("agent.settings.notification_window")
	toast_label.tooltip_text = I18n.t("agent.settings.notification_window_help")
	toast_toggle_button.tooltip_text = I18n.t("agent.settings.notification_window_help")
	sound_label.text = I18n.t("agent.settings.notification_sound")
	sound_label.tooltip_text = I18n.t("agent.settings.notification_sound_help")
	sound_toggle_button.tooltip_text = I18n.t("agent.settings.notification_sound_help")
	sound_seconds_label.text = I18n.t("agent.settings.sound_duration")
	sound_folder_label.text = I18n.t("agent.settings.sound_folder")
	sound_folder_label.tooltip_text = I18n.t("agent.settings.sound_folder_help")
	sound_folder_edit.tooltip_text = I18n.t("agent.settings.sound_folder_help")
	sound_folder_dialog.title = I18n.t("agent.settings.sound_folder_title")
	sound_folder_dialog.ok_button_text = I18n.t("common.select")
	pass


func apply_theme() -> void:
	super.apply_theme()
	ui.style_field_label(toast_label)
	ui.style_field_label(sound_label)
	ButtonStyle.apply_check_button(toast_toggle_button)
	ButtonStyle.apply_check_button(sound_toggle_button)
	ui.style_field_label(sound_seconds_label)
	ui.style_field_label(sound_folder_label)
	ui.style_spin_box(sound_seconds_spin)
	ui.style_line_edit(sound_folder_edit)
	pass


func has_open_popup() -> bool:
	return sound_folder_dialog.visible
