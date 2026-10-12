class_name AgentQueueRow
extends PanelContainer

signal action_pressed

var title: Label
var action_button: Button
var header: bool = false
var hovered: bool = false


func setup(text: String, tooltip: String, icon: Texture2D, is_header: bool) -> void:
	header = is_header
	custom_minimum_size.y = ControlSize.lg
	mouse_filter = Control.MOUSE_FILTER_STOP

	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_theme_constant_override("separation", Margin.ma_2)
	add_child(content)

	title = Label.new()
	title.text = text
	title.tooltip_text = text if not header else ""
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(title)

	action_button = Button.new()
	action_button.icon = icon
	action_button.tooltip_text = tooltip
	action_button.custom_minimum_size = ControlSize.square(ControlSize.xs)
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_button.pressed.connect(action_pressed.emit)
	content.add_child(action_button)

	for control: Control in [self, content, title, action_button]:
		control.mouse_entered.connect(on_mouse_entered)
		control.mouse_exited.connect(on_mouse_exited)
	apply_theme()
	pass


func apply_theme() -> void:
	AgentChatInputTheme.apply_queue_row(self, title, action_button, header, hovered)
	pass


func on_mouse_entered() -> void:
	hovered = true
	apply_theme()
	pass


func on_mouse_exited() -> void:
	if get_global_rect().has_point(get_global_mouse_position()):
		return
	hovered = false
	apply_theme()
	pass
