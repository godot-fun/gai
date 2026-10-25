class_name NotificationSettingSection
extends SettingSection

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


func set_up(p_ui: AgentSettingDialog, parent: VBoxContainer, window: Window) -> void:
	super.set_up(p_ui, parent, window)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.notification"))
	var notification_parts := ui.make_setting_row(parent, 6)
	# Column 1 — popup notification label (label band).
	toast_label = ui.make_label(I18n.t("agent.settings.notification_window"))
	style_notification_row_label(toast_label)
	notification_parts[0].add_child(toast_label)
	toast_label.tooltip_text = I18n.t("agent.settings.notification_window_help")
	# Column 2 — popup notification toggle (control band, 1/5).
	toast_toggle_button = ui.add_check_button(notification_parts[1], "", AgentSetting.get_notification_window())
	toast_toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toast_toggle_button.tooltip_text = I18n.t("agent.settings.notification_window_help")
	toast_toggle_button.toggled.connect(on_toast_toggled)
	# Column 3 — sound notification label (control band, 2/5).
	sound_label = ui.make_label(I18n.t("agent.settings.notification_sound"))
	style_notification_row_label(sound_label)
	notification_parts[2].add_child(sound_label)
	sound_label.tooltip_text = I18n.t("agent.settings.notification_sound_help")
	# Column 4 — sound notification toggle (control band, 3/5).
	sound_toggle_button = ui.add_check_button(notification_parts[3], "", AgentSetting.get_notification_sound())
	sound_toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sound_toggle_button.tooltip_text = I18n.t("agent.settings.notification_sound_help")
	sound_toggle_button.toggled.connect(on_sound_toggled)
	# Column 5 — sound duration label (control band, 4/5).
	sound_seconds_label = ui.make_label(I18n.t("agent.settings.sound_duration"))
	style_notification_row_label(sound_seconds_label)
	notification_parts[4].add_child(sound_seconds_label)
	# Column 6 — sound duration spin box (control band, 5/5).
	sound_seconds_spin = SpinBox.new()
	sound_seconds_spin.min_value = AgentSetting.MIN_SOUND_SECONDS
	sound_seconds_spin.max_value = AgentSetting.MAX_SOUND_SECONDS
	sound_seconds_spin.step = 1
	sound_seconds_spin.suffix = " s"
	sound_seconds_spin.custom_minimum_size = Vector2(0, 34)
	sound_seconds_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_seconds_spin.value = AgentSetting.get_notification_sound_seconds()
	sound_seconds_spin.value_changed.connect(on_sound_seconds_changed)
	notification_parts[5].add_child(sound_seconds_spin)
	var folder_parts := ui.make_setting_row(parent)
	sound_folder_row = folder_parts[1]
	# Column 1 — sound folder label (label band).
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
	# Column 2 — sound folder path (full control band).
	sound_folder_row.add_child(sound_folder_edit)
	ui.bind_auto_save(sound_folder_edit, save)
	build_folder_dialog(window)
	update_sound_options_visible(AgentSetting.get_notification_sound())
	pass


func style_notification_row_label(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass


func build_folder_dialog(window: Window) -> void:
	sound_folder_dialog = FileDialog.new()
	sound_folder_dialog.title = I18n.t("agent.settings.sound_folder_title")
	sound_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	sound_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	sound_folder_dialog.ok_button_text = I18n.t("common.select")
	sound_folder_dialog.get_cancel_button().text = I18n.t("common.cancel")
	sound_folder_dialog.dir_selected.connect(on_sound_folder_selected)
	window.add_child(sound_folder_dialog)
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
	FileDialogStyle.present_centered(sound_folder_dialog, 60, 70, I18nHelper.file_dialog_label_texts())
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
	sound_folder_dialog.get_cancel_button().text = I18n.t("common.cancel")
	FileDialogStyle.apply(sound_folder_dialog, I18nHelper.file_dialog_label_texts())
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
	FileDialogStyle.apply(sound_folder_dialog, I18nHelper.file_dialog_label_texts())
	pass
