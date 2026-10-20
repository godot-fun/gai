class_name ContextBubble
extends BubbleContainer

var rich_text: RichTextLabel

## Context chat bubble for skills / memory / AGENTS.md — expand/collapse with Markdown preview.
## Session / toolbar toggles live in SkillToggle and AgentPromptToggle.


const PREVIEW_LINES: int = 8
var expanded: bool = false
var expand_button: Button


static func preview(body: String) -> String:
	return StringUtils.first_lines(body, PREVIEW_LINES)


static func needs_expand(body: String) -> bool:
	return StringUtils.is_not_blank(body) and preview(body) != body


static func hidden_line_count(body: String) -> int:
	if StringUtils.is_blank(body):
		return 0
	return maxi(0, body.count(FileUtils.NEWLINE_LF) + 1 - PREVIEW_LINES)


func apply(session_id: int, entry: ChatEntry) -> void:
	apply_background(Colors.info_surface)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.secondary_text)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	expand_button = Button.new()
	style_expand_button(expand_button)
	expand_button.pressed.connect(on_expand_pressed.bind(entry))
	header.add_child(expand_button)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	var delete_button: Button = Button.new()
	delete_button.name = "DeleteButton"
	delete_button.text = "Delete"
	AgentBubble.style_header_button(delete_button, Colors.info_surface, "Delete from here", 52.0)
	delete_button.pressed.connect(on_delete_pressed.bind(session_id, entry))
	header.add_child(delete_button)

	vbox.add_child(header)

	rich_text = MarkdownHelper.create_rich_text_label(
		Colors.secondary_text,
		StringUtils.EMPTY,
		true
	)
	vbox.add_child(rich_text)
	refresh(entry)
	pass


static func on_delete_pressed(session_id: int, entry: ChatEntry) -> void:
	AgentSessionManager.delete_chat_from_entry(session_id, entry)
	pass


func on_expand_pressed(entry: ChatEntry) -> void:
	expanded = not expanded
	refresh(entry)
	pass


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(rich_text) or entry == null:
		return
	var can_expand: bool = needs_expand(entry.body)
	var display: String = entry.body if expanded or not can_expand else preview(entry.body)
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	MarkdownHelper.update_rich_text_label_text(rich_text, display, true)

	if is_instance_valid(expand_button):
		expand_button.visible = can_expand
		if can_expand:
			if expanded:
				expand_button.text = I18n.t("agent.common.collapse")
				expand_button.tooltip_text = I18n.t("agent.common.collapse_tooltip")
			else:
				var hidden: int = hidden_line_count(entry.body)
				expand_button.text = StringUtils.format(
					I18n.t("agent.common.expand_lines"),
					hidden,
					"" if hidden == 1 else "s"
				)
				expand_button.tooltip_text = I18n.t("agent.common.expand_tooltip")
	pass


static func style_expand_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 18)
	button.add_theme_font_size_override("font_size", Typography.label_small_size)
	var theme_color := ThemeColor.accent_theme_color()
	ButtonStyle.apply_font_colors(button, theme_color, ButtonStyle.hover_color(theme_color, 0.12), ButtonStyle.press_color(theme_color, 0.08))

	var normal := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, 0, Margin.ma_1, Margin.ma_0)
	var hover := ButtonStyle.filled(normal, ThemeColor.alpha_theme_color(0.12))
	hover.set_corner_radius_all(4)

	# Pressed looks exactly like hover here, so the two states share one box.
	ButtonStyle.apply(button, normal, hover, hover)
	pass
