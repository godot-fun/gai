class_name NotificationSettingSection
extends SettingSection

var toast_toggle_button: CheckButton
var sound_toggle_button: CheckButton
var toast_label: Label
var sound_label: Label
var sound_seconds_label: Label
var sound_volume_label: Label
var sound_volume_value_label: Label
var sound_folder_label: Label
var sound_folder_row: HBoxContainer
var sound_volume_box: HBoxContainer
var sound_seconds_spin: SpinBox
var sound_volume_slider: HSlider
var sound_folder_edit: LineEdit
var sound_folder_dialog: FileDialog
var folder_field_typing: bool = false


func set_up(p_ui: AgentSettingWindow, parent: VBoxContainer, window: Window) -> void:
	super.set_up(p_ui, parent, window)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.notification"))
	# Row 1 — popup notification on a row of its own.
	var toast_parts := ui.make_setting_row(parent)
	toast_label = ui.make_label(I18n.t("agent.settings.notification_window"))
	style_notification_row_label(toast_label)
	toast_label.tooltip_text = I18n.t("agent.settings.notification_window_help")
	toast_parts[0].add_child(toast_label)
	toast_toggle_button = ui.add_check_button(toast_parts[1], "", AgentSetting.get_notification_window())
	toast_toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toast_toggle_button.tooltip_text = I18n.t("agent.settings.notification_window_help")
	toast_toggle_button.toggled.connect(on_toast_toggled)
	# Row 2 — sound notification toggle and duration, on the shared 1:5 grid so the switch and the
	# field line up with the rows in the sections above.
	var sound_parts := ui.make_setting_row(parent, 6)
	# Column 1 — sound notification label (label band).
	sound_label = ui.make_label(I18n.t("agent.settings.notification_sound"))
	style_notification_row_label(sound_label)
	sound_parts[0].add_child(sound_label)
	sound_label.tooltip_text = I18n.t("agent.settings.notification_sound_help")
	# Column 2 — sound notification toggle (control band, 1/5).
	sound_toggle_button = ui.add_check_button(sound_parts[1], "", AgentSetting.get_notification_sound())
	sound_toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sound_toggle_button.tooltip_text = I18n.t("agent.settings.notification_sound_help")
	sound_toggle_button.toggled.connect(on_sound_toggled)
	# Column 3 — sound duration label (control band, 2/5).
	sound_seconds_label = ui.make_label(I18n.t("agent.settings.sound_duration"))
	style_notification_row_label(sound_seconds_label)
	sound_parts[2].add_child(sound_seconds_label)
	# Column 4 — sound duration spin box (control band, 3/5).
	sound_seconds_spin = SpinBox.new()
	sound_seconds_spin.min_value = AgentSetting.MIN_SOUND_SECONDS
	sound_seconds_spin.max_value = AgentSetting.MAX_SOUND_SECONDS
	sound_seconds_spin.step = 1
	sound_seconds_spin.suffix = " s"
	sound_seconds_spin.custom_minimum_size = Vector2(0, ControlSize.md)
	sound_seconds_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_seconds_spin.value = AgentSetting.get_notification_sound_seconds()
	sound_seconds_spin.value_changed.connect(on_sound_seconds_changed)
	sound_parts[3].add_child(sound_seconds_spin)
	# Row 3 — sound volume. A slider only fits the shared grid by filling its control band, so it
	# takes a label band of its own instead of trailing the field above.
	var volume_parts := ui.make_setting_row(parent)
	sound_volume_label = ui.make_label(I18n.t("agent.settings.sound_volume"))
	style_notification_row_label(sound_volume_label)
	sound_volume_label.tooltip_text = I18n.t("agent.settings.sound_volume_help")
	volume_parts[0].add_child(sound_volume_label)
	sound_volume_box = build_volume_box()
	volume_parts[1].add_child(sound_volume_box)
	# Row 4 — sound folder.
	var folder_parts := ui.make_setting_row(parent)
	sound_folder_row = folder_parts[1]
	sound_folder_label = ui.make_label(I18n.t("agent.settings.sound_folder"))
	folder_parts[0].add_child(sound_folder_label)
	sound_folder_label.tooltip_text = I18n.t("agent.settings.sound_folder_help")
	sound_folder_edit = LineEdit.new()
	sound_folder_edit.custom_minimum_size = Vector2(0, ControlSize.md)
	sound_folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_folder_edit.placeholder_text = AgentSetting.DEFAULT_SOUND_FOLDER
	sound_folder_edit.text = AgentSetting.get_notification_sound_folder()
	sound_folder_edit.tooltip_text = I18n.t("agent.settings.sound_folder_help")
	sound_folder_edit.gui_input.connect(on_sound_folder_input)
	sound_folder_edit.text_changed.connect(on_sound_folder_text_changed)
	sound_folder_row.add_child(sound_folder_edit)
	build_folder_dialog(window)
	update_sound_options_visible(AgentSetting.get_notification_sound())
	pass


## Slider plus a fixed-width percentage readout, so dragging the slider never reflows the row.
func build_volume_box() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", Margin.ma_2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_volume_slider = HSlider.new()
	sound_volume_slider.min_value = AgentSetting.MIN_SOUND_VOLUME
	sound_volume_slider.max_value = AgentSetting.MAX_SOUND_VOLUME
	sound_volume_slider.step = 1
	sound_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_volume_slider.value = AgentSetting.get_notification_sound_volume()
	sound_volume_slider.tooltip_text = I18n.t("agent.settings.sound_volume_help")
	sound_volume_slider.value_changed.connect(on_sound_volume_changed)
	box.add_child(sound_volume_slider)
	sound_volume_value_label = ui.make_label(volume_text(sound_volume_slider.value))
	sound_volume_value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	sound_volume_value_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	sound_volume_value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Exactly the widest value ("100%"): the number starts right after the slider, and the slider
	# keeps its length while the digits change.
	sound_volume_value_label.custom_minimum_size.x = roundi(readout_width(sound_volume_value_label))
	box.add_child(sound_volume_value_label)
	return box


## Percentage readout of the volume slider.
func volume_text(volume: float) -> String:
	return "%d%%" % roundi(volume)


## Width of the widest readout at [param label]'s font, so no blank sits between it and the slider.
func readout_width(label: Label) -> float:
	var font := label.get_theme_font("font")
	if font == null:
		return ControlSize.icon_xxl
	var font_size := label.get_theme_font_size("font_size")
	return font.get_string_size(volume_text(AgentSetting.MAX_SOUND_VOLUME), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 1.0


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
	sound_volume_slider.set_value_no_signal(AgentSetting.get_notification_sound_volume())
	sound_volume_value_label.text = volume_text(sound_volume_slider.value)
	sound_folder_edit.text = AgentSetting.get_notification_sound_folder()
	folder_field_typing = false
	pass


func save() -> void:
	AgentSetting.set_notification_sound_seconds(roundi(sound_seconds_spin.value))
	AgentSetting.set_notification_sound_volume(roundi(sound_volume_slider.value))
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


## Persist the volume — it applies from the next notification sound on.
func on_sound_volume_changed(volume: float) -> void:
	AgentSetting.set_notification_sound_volume(roundi(volume))
	sound_volume_value_label.text = volume_text(volume)
	pass


func update_sound_options_visible(enabled: bool) -> void:
	sound_seconds_label.visible = enabled
	sound_seconds_spin.visible = enabled
	sound_volume_label.visible = enabled
	sound_volume_box.visible = enabled
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
	sound_volume_label.text = I18n.t("agent.settings.sound_volume")
	sound_volume_label.tooltip_text = I18n.t("agent.settings.sound_volume_help")
	sound_volume_slider.tooltip_text = I18n.t("agent.settings.sound_volume_help")
	sound_volume_value_label.text = volume_text(sound_volume_slider.value)
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
	CheckButtonStyle.apply(toast_toggle_button)
	CheckButtonStyle.apply(sound_toggle_button)
	ui.style_field_label(sound_seconds_label)
	ui.style_spin_box(sound_seconds_spin)
	ui.style_field_label(sound_volume_label)
	RangeStyle.apply_slider(sound_volume_slider)
	ui.style_help_label(sound_volume_value_label)
	ui.style_field_label(sound_folder_label)
	LineEditStyle.apply(sound_folder_edit)
	FileDialogStyle.apply(sound_folder_dialog, I18nHelper.file_dialog_label_texts())
	pass
