class_name ShortcutSettingSection
extends SettingSection

## Settings category for rebinding in-app shortcuts. Search opens with Ctrl+F by default.

enum CaptureTarget { NONE, SEARCH, PREV_USER_MESSAGE, NEXT_USER_MESSAGE }

var search_label: Label
var search_button: Button
var prev_user_message_label: Label
var prev_user_message_button: Button
var next_user_message_label: Label
var next_user_message_button: Button
var capture_target: CaptureTarget = CaptureTarget.NONE


func set_up(p_ui: AgentSettingWindow, parent: VBoxContainer, _window: Window) -> void:
	super.set_up(p_ui, parent, _window)
	heading_label = ui.add_heading(parent, I18n.t("agent.settings.shortcut"))
	search_label = ui.make_label(I18n.t("agent.settings.open_search"))
	search_label.tooltip_text = I18n.t("agent.settings.shortcut_help")
	search_button = add_shortcut_button(parent, search_label, I18n.t("agent.settings.shortcut_help"))
	search_button.pressed.connect(on_search_capture_started)
	add_user_message_shortcut_row(parent)
	show_bindings()
	pass


func add_shortcut_button(parent: VBoxContainer, label: Label, tooltip: String) -> Button:
	var parts := ui.make_setting_row(parent, 6)
	parts[0].add_child(label)
	var button := make_shortcut_button(tooltip)
	parts[1].add_child(button)
	return button


func add_user_message_shortcut_row(parent: VBoxContainer) -> void:
	var nav_help := I18n.t("agent.settings.user_nav_shortcut_help")
	var parts := ui.make_setting_row(parent, 6)
	parts[1].size_flags_stretch_ratio = 2.0
	parts[2].size_flags_stretch_ratio = 0.0
	parts[3].size_flags_stretch_ratio = 1.0
	parts[4].size_flags_stretch_ratio = 2.0
	parts[5].size_flags_stretch_ratio = 0.0
	prev_user_message_label = ui.make_label(I18n.t("agent.settings.prev_user_message"))
	prev_user_message_label.tooltip_text = nav_help
	parts[0].add_child(prev_user_message_label)
	prev_user_message_button = make_shortcut_button(nav_help)
	prev_user_message_button.pressed.connect(on_prev_user_message_capture_started)
	parts[1].add_child(prev_user_message_button)
	next_user_message_label = ui.make_label(I18n.t("agent.settings.next_user_message"))
	next_user_message_label.tooltip_text = nav_help
	parts[3].add_child(next_user_message_label)
	next_user_message_button = make_shortcut_button(nav_help)
	next_user_message_button.pressed.connect(on_next_user_message_capture_started)
	parts[4].add_child(next_user_message_button)
	pass


func make_shortcut_button(tooltip: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = ControlSize.sm
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = tooltip
	button.gui_input.connect(on_shortcut_input)
	button.focus_exited.connect(on_capture_cancelled)
	return button


func refresh() -> void:
	capture_target = CaptureTarget.NONE
	show_bindings()
	pass


func on_search_capture_started() -> void:
	begin_capture(CaptureTarget.SEARCH, search_button)
	pass


func on_prev_user_message_capture_started() -> void:
	begin_capture(CaptureTarget.PREV_USER_MESSAGE, prev_user_message_button)
	pass


func on_next_user_message_capture_started() -> void:
	begin_capture(CaptureTarget.NEXT_USER_MESSAGE, next_user_message_button)
	pass


func begin_capture(target: CaptureTarget, button: Button) -> void:
	capture_target = target
	button.text = I18n.t("agent.settings.shortcut_capture")
	button.grab_focus()
	pass


func on_capture_cancelled() -> void:
	if capture_target == CaptureTarget.NONE:
		return
	capture_target = CaptureTarget.NONE
	show_bindings()
	pass


func on_shortcut_input(event: InputEvent) -> void:
	if capture_target == CaptureTarget.NONE or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	var button := capture_button()
	if button == null:
		return
	if not key_event.pressed or key_event.echo or key_event.keycode in [KEY_CTRL, KEY_ALT, KEY_SHIFT, KEY_META]:
		button.accept_event()
		return
	var key := key_event.get_keycode_with_modifiers()
	if not ShortcutSetting.is_search_shortcut_valid(key):
		button.text = I18n.t("agent.settings.shortcut_invalid")
		button.accept_event()
		return
	var target := capture_target
	capture_target = CaptureTarget.NONE
	match target:
		CaptureTarget.SEARCH:
			ShortcutSetting.set_search_shortcut(key)
		CaptureTarget.PREV_USER_MESSAGE:
			ShortcutSetting.set_prev_user_message_shortcut(key)
		CaptureTarget.NEXT_USER_MESSAGE:
			ShortcutSetting.set_next_user_message_shortcut(key)
	show_bindings()
	button.accept_event()
	pass


func capture_button() -> Button:
	match capture_target:
		CaptureTarget.SEARCH:
			return search_button
		CaptureTarget.PREV_USER_MESSAGE:
			return prev_user_message_button
		CaptureTarget.NEXT_USER_MESSAGE:
			return next_user_message_button
	return null


func apply_locale() -> void:
	heading_label.text = I18n.t("agent.settings.shortcut")
	search_label.text = I18n.t("agent.settings.open_search")
	search_label.tooltip_text = I18n.t("agent.settings.shortcut_help")
	search_button.tooltip_text = I18n.t("agent.settings.shortcut_help")
	prev_user_message_label.text = I18n.t("agent.settings.prev_user_message")
	prev_user_message_label.tooltip_text = I18n.t("agent.settings.user_nav_shortcut_help")
	prev_user_message_button.tooltip_text = I18n.t("agent.settings.user_nav_shortcut_help")
	next_user_message_label.text = I18n.t("agent.settings.next_user_message")
	next_user_message_label.tooltip_text = I18n.t("agent.settings.user_nav_shortcut_help")
	next_user_message_button.tooltip_text = I18n.t("agent.settings.user_nav_shortcut_help")
	if capture_target != CaptureTarget.NONE:
		capture_button().text = I18n.t("agent.settings.shortcut_capture")
	else:
		show_bindings()
	pass


func show_bindings() -> void:
	search_button.text = OS.get_keycode_string(ShortcutSetting.get_search_shortcut())
	prev_user_message_button.text = OS.get_keycode_string(ShortcutSetting.get_prev_user_message_shortcut())
	next_user_message_button.text = OS.get_keycode_string(ShortcutSetting.get_next_user_message_shortcut())
	pass


func apply_theme() -> void:
	super.apply_theme()
	ui.style_field_label(search_label)
	ui.style_field_label(prev_user_message_label)
	ui.style_field_label(next_user_message_label)
	ui.style_action_button(search_button)
	ui.style_action_button(prev_user_message_button)
	ui.style_action_button(next_user_message_button)
	pass
