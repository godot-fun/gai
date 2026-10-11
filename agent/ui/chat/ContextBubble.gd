class_name ContextBubble
extends RefCounted

## Context chat bubble for skill index / AGENTS.md — expand/collapse with Markdown preview.
## Session / toolbar toggles live in SkillToggle and AgentPromptToggle.


const PREVIEW_LINES: int = 8
const META_EXPANDED: String = "context_bubble_expanded"
const META_EXPAND_BUTTON: String = "context_bubble_expand_button"


static func preview(body: String) -> String:
	return StringUtils.first_lines(body, PREVIEW_LINES)


static func needs_expand(body: String) -> bool:
	return StringUtils.is_not_blank(body) and preview(body) != body


static func hidden_line_count(body: String) -> int:
	if StringUtils.is_blank(body):
		return 0
	return maxi(0, body.count(FileUtils.NEWLINE_LF) + 1 - PREVIEW_LINES)


static func append(
	chat_list: VBoxContainer,
	entry: ChatEntry,
	panel_style: StyleBoxFlat
) -> RichTextLabel:
	var wrapper: PanelContainer = PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", panel_style)
	wrapper.set_meta(META_EXPANDED, false)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	wrapper.add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", ColorBase.secondary_text)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	var expand_button: Button = Button.new()
	style_expand_button(expand_button)
	expand_button.pressed.connect(on_expand_pressed.bind(wrapper, entry))
	header.add_child(expand_button)
	wrapper.set_meta(META_EXPAND_BUTTON, expand_button)

	vbox.add_child(header)

	var rich_text: RichTextLabel = MarkdownHelper.create_rich_text_label(
		ColorBase.secondary_text,
		StringUtils.EMPTY,
		true
	)
	vbox.add_child(rich_text)
	wrapper.set_meta(AgentChatView.META_BUBBLE_RICH_TEXT, rich_text)

	chat_list.add_child(wrapper)
	refresh(rich_text, entry, wrapper)
	return rich_text


static func on_expand_pressed(wrapper: PanelContainer, entry: ChatEntry) -> void:
	if not is_instance_valid(wrapper):
		return
	var expanded: bool = bool(wrapper.get_meta(META_EXPANDED, false))
	wrapper.set_meta(META_EXPANDED, not expanded)
	var rich_text: RichTextLabel = wrapper.get_meta(AgentChatView.META_BUBBLE_RICH_TEXT) as RichTextLabel
	if rich_text != null:
		refresh(rich_text, entry, wrapper)
	pass


static func refresh(rich_text: RichTextLabel, entry: ChatEntry, wrapper: PanelContainer = null) -> void:
	if not is_instance_valid(rich_text):
		return
	if wrapper == null:
		wrapper = find_wrapper(rich_text)
	if wrapper == null:
		return

	var expanded: bool = bool(wrapper.get_meta(META_EXPANDED, false))
	var can_expand: bool = needs_expand(entry.body)
	var display: String = entry.body if expanded or not can_expand else preview(entry.body)
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	MarkdownHelper.update_rich_text_label_text(rich_text, display, true)

	var expand_button: Button = wrapper.get_meta(META_EXPAND_BUTTON) as Button
	if expand_button != null:
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


static func find_wrapper(rich_text: RichTextLabel) -> PanelContainer:
	var vbox: Node = rich_text.get_parent()
	if vbox == null:
		return null
	return vbox.get_parent() as PanelContainer


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
