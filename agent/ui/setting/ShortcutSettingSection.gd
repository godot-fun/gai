class_name ShortcutSettingSection
extends SettingSection

## Settings category for rebinding in-app shortcuts. Search opens with Ctrl+F by default.

var search_label: Label
var search_help: Label
var search_button: Button
var recording: bool = false


func set_up(p_ui: AgentSettingWindow, parent: VBoxContainer, _window: Window) -> void:
	super.set_up(p_ui, parent, _window)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.shortcut"))
	var parts := ui.make_setting_row(parent)
	search_label = ui.make_label(I18n.t("agent.settings.open_search"))
	search_label.tooltip_text = I18n.t("agent.settings.shortcut_help")
	parts[0].add_child(search_label)
	search_button = Button.new()
	search_button.custom_minimum_size = Vector2(0, 38)
	search_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	search_button.focus_mode = Control.FOCUS_ALL
	search_button.tooltip_text = I18n.t("agent.settings.shortcut_help")
	search_button.text = ShortcutSetting.search_shortcut_text()
	search_button.pressed.connect(on_capture_started)
	search_button.gui_input.connect(on_shortcut_input)
	search_button.focus_exited.connect(on_capture_cancelled)
	parts[1].add_child(search_button)
	search_help = ui.add_help_label(parent, I18n.t("agent.settings.shortcut_help"))
	pass


func refresh() -> void:
	recording = false
	search_button.text = ShortcutSetting.search_shortcut_text()
	pass


func on_capture_started() -> void:
	recording = true
	search_button.text = I18n.t("agent.settings.shortcut_capture")
	search_button.grab_focus()
	pass


func on_capture_cancelled() -> void:
	if not recording:
		return
	recording = false
	search_button.text = ShortcutSetting.search_shortcut_text()
	pass


func on_shortcut_input(event: InputEvent) -> void:
	if not recording or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode in [KEY_CTRL, KEY_ALT, KEY_SHIFT, KEY_META]:
		search_button.accept_event()
		return
	var key := key_event.get_keycode_with_modifiers()
	if not ShortcutSetting.is_search_shortcut_valid(key):
		search_button.text = I18n.t("agent.settings.shortcut_invalid")
		search_button.accept_event()
		return
	recording = false
	ShortcutSetting.set_search_shortcut(key)
	search_button.text = ShortcutSetting.search_shortcut_text()
	search_button.accept_event()
	pass


func apply_locale() -> void:
	heading_label.text = I18n.t("agent.settings.shortcut")
	search_label.text = I18n.t("agent.settings.open_search")
	search_label.tooltip_text = I18n.t("agent.settings.shortcut_help")
	search_button.tooltip_text = I18n.t("agent.settings.shortcut_help")
	search_help.text = I18n.t("agent.settings.shortcut_help")
	if recording:
		search_button.text = I18n.t("agent.settings.shortcut_capture")
	else:
		search_button.text = ShortcutSetting.search_shortcut_text()
	pass


func apply_theme() -> void:
	super.apply_theme()
	ui.style_field_label(search_label)
	ui.style_help_label(search_help)
	ui.style_action_button(search_button)
	pass
