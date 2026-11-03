class_name ShortcutSettingSection
extends SettingSection

## Settings category for rebinding in-app shortcuts. Search opens with Ctrl+F by default.

var search_label: Label
var search_button: Button
var recording: bool = false


func set_up(p_ui: AgentSettingWindow, parent: VBoxContainer, _window: Window) -> void:
	super.set_up(p_ui, parent, _window)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.shortcut"))
	var parts := ui.make_setting_row(parent, 6)
	# Column 1 — open-search label (label band).
	search_label = ui.make_label(I18n.t("agent.settings.open_search"))
	search_label.tooltip_text = I18n.t("agent.settings.shortcut_help")
	parts[0].add_child(search_label)
	# Column 2 — shortcut button (control band, 1/5). Columns 3–6 stay empty.
	search_button = Button.new()
	search_button.custom_minimum_size.y = ControlSize.sm
	search_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_button.tooltip_text = I18n.t("agent.settings.shortcut_help")
	show_binding()
	search_button.pressed.connect(on_capture_started)
	search_button.gui_input.connect(on_shortcut_input)
	search_button.focus_exited.connect(on_capture_cancelled)
	parts[1].add_child(search_button)
	pass


func refresh() -> void:
	recording = false
	show_binding()
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
	show_binding()
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
	show_binding()
	search_button.accept_event()
	pass


func apply_locale() -> void:
	heading_label.text = I18n.t("agent.settings.shortcut")
	search_label.text = I18n.t("agent.settings.open_search")
	search_label.tooltip_text = I18n.t("agent.settings.shortcut_help")
	search_button.tooltip_text = I18n.t("agent.settings.shortcut_help")
	if recording:
		search_button.text = I18n.t("agent.settings.shortcut_capture")
	else:
		show_binding()
	pass


func show_binding() -> void:
	search_button.text = OS.get_keycode_string(ShortcutSetting.get_search_shortcut())
	pass


func apply_theme() -> void:
	super.apply_theme()
	ui.style_field_label(search_label)
	ui.style_action_button(search_button)
	pass
