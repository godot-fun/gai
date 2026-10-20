class_name ErrorBubble
extends BubbleContainer

var rich_text: RichTextLabel

## Error bubble with optional resume action for the agent chat transcript.

const MAX_LINES: int = 28

const META_RESUME_BUTTON: String = "resume_button"


func apply(session_id: int, entry: ChatEntry) -> void:
	apply_panel_style(Colors.surface)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	add_child(vbox)

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.secondary_text)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	vbox.add_child(title_label)

	rich_text = MarkdownHelper.create_rich_text_label(
			Colors.error,
			StringUtils.EMPTY,
			AgentSetting.get_markdown_enabled()
	)
	vbox.add_child(rich_text)
	refresh(entry)

	if is_resumable(entry.body):
		var resume_button: Button = Button.new()
		resume_button.text = "Resume"
		resume_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		resume_button.disabled = RuntimeManager.is_running(session_id)
		style_resume_button(resume_button)
		resume_button.pressed.connect(on_resume_pressed.bind(session_id, entry))
		set_meta(META_RESUME_BUTTON, resume_button)
		vbox.add_child(resume_button)
	pass


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(rich_text) or entry == null:
		return
	var display: String = StringUtils.first_lines(entry.body, MAX_LINES)
	MarkdownHelper.update_rich_text_label_text(rich_text, display, AgentSetting.get_markdown_enabled())
	pass


static func refresh_resume_buttons(chat_list: VBoxContainer, running: bool) -> void:
	for child in chat_list.get_children():
		if not child.has_meta(META_RESUME_BUTTON):
			continue
		var resume_button: Button = child.get_meta(META_RESUME_BUTTON)
		resume_button.disabled = running
	pass


static func is_resumable(message: String) -> bool:
	return message != "session is busy"


static func on_resume_pressed(session_id: int, entry: ChatEntry) -> void:
	if RuntimeManager.is_running(session_id):
		Alert.alert("session is busy", Colors.error)
		return
	AgentSessionManager.delete_chat_from_entry(session_id, entry)
	RuntimeManager.resume_agent(session_id)
	pass


static func style_resume_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(0, ControlSize.md)
	button.add_theme_font_size_override("font_size", Typography.label_large_size)

	var theme_color := ThemeColor.accent_theme_color()
	ButtonStyle.apply_font_colors(button,theme_color,ButtonStyle.hover_color(theme_color, 0.12),
		ButtonStyle.press_color(theme_color, 0.08),ThemeColor.alpha_theme_color(0.45))

	var normal := StyleBoxHelper.create_style_box_flat(ThemeColor.alpha_theme_color(0.08),5,
		Margin.ma_3,Margin.ma_1,ThemeColor.alpha_theme_color(0.35),ControlSize.border_xs)
	ButtonStyle.apply(button, normal,
		ButtonStyle.filled(normal, ThemeColor.alpha_theme_color(0.16), ThemeColor.alpha_theme_color(0.55)),
		ButtonStyle.filled(normal, ThemeColor.alpha_theme_color(0.22)),
		ButtonStyle.filled(normal, ThemeColor.alpha_theme_color(0.04), ThemeColor.alpha_theme_color(0.12)))
	pass
