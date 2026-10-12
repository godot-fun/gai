class_name CompactionBubble
extends Object

## Expandable summary left behind after older visible chat entries are compacted.

const PREVIEW_LINES: int = 8
const META_EXPANDED := "compaction_bubble_expanded"
const META_EXPAND_BUTTON := "compaction_bubble_expand_button"


static func append(chat_list: VBoxContainer, entry: ChatEntry, panel_style: StyleBoxFlat) -> RichTextLabel:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", panel_style)
	wrapper.set_meta(META_EXPANDED, false)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	wrapper.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	vbox.add_child(header)

	var title := Label.new()
	title.text = ChatEntry.TITLE_COMPACTION
	title.add_theme_font_override("font", Fonts.semibold())
	title.add_theme_font_size_override("font_size", Typography.label_medium_size)
	title.add_theme_color_override("font_color", ThemeColor.accent_theme_color())
	header.add_child(title)

	var expand_button := Button.new()
	expand_button.focus_mode = Control.FOCUS_NONE
	expand_button.pressed.connect(on_expand_pressed.bind(wrapper, entry))
	style_expand_button(expand_button)
	header.add_child(expand_button)
	wrapper.set_meta(META_EXPAND_BUTTON, expand_button)

	var rich_text := MarkdownHelper.create_rich_text_label(
		Colors.secondary_text,
		StringUtils.EMPTY,
		MarkdownToggle.markdown_enabled_for_entry(entry)
	)
	vbox.add_child(rich_text)
	wrapper.set_meta(AgentChatView.META_BUBBLE_RICH_TEXT, rich_text)
	chat_list.add_child(wrapper)
	refresh(rich_text, entry, wrapper)
	return rich_text


static func on_expand_pressed(wrapper: PanelContainer, entry: ChatEntry) -> void:
	if not is_instance_valid(wrapper):
		return
	var expanded := bool(wrapper.get_meta(META_EXPANDED, false))
	wrapper.set_meta(META_EXPANDED, not expanded)
	var rich_text := wrapper.get_meta(AgentChatView.META_BUBBLE_RICH_TEXT) as RichTextLabel
	refresh(rich_text, entry, wrapper)
	pass


static func refresh(rich_text: RichTextLabel, entry: ChatEntry, wrapper: PanelContainer = null) -> void:
	if not is_instance_valid(rich_text):
		return
	if wrapper == null:
		wrapper = rich_text.get_parent().get_parent() as PanelContainer
	if wrapper == null:
		return
	var expanded := bool(wrapper.get_meta(META_EXPANDED, false))
	var preview := StringUtils.first_lines(entry.body, PREVIEW_LINES)
	var can_expand := preview != entry.body
	MarkdownHelper.update_rich_text_label_text(
		rich_text,
		entry.body if expanded or not can_expand else preview,
		MarkdownToggle.markdown_enabled_for_entry(entry)
	)
	var expand_button := wrapper.get_meta(META_EXPAND_BUTTON) as Button
	if expand_button != null:
		expand_button.visible = can_expand
		if can_expand:
			if expanded:
				expand_button.text = I18n.t("agent.tokens.summary_collapse")
				expand_button.tooltip_text = I18n.t("agent.tokens.summary_collapse_tooltip")
			else:
				var hidden_lines := maxi(0, entry.body.count(FileUtils.NEWLINE_LF) + 1 - PREVIEW_LINES)
				expand_button.text = StringUtils.format(
					I18n.t("agent.tokens.summary_expand"),
					hidden_lines,
					"" if hidden_lines == 1 else "s"
				)
				expand_button.tooltip_text = I18n.t("agent.tokens.summary_expand_tooltip")
	pass


static func style_expand_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(0, 18)
	button.add_theme_font_size_override("font_size", Typography.label_small_size)
	var color := ThemeColor.accent_theme_color()
	ButtonStyle.apply_font_colors(button, color, ButtonStyle.hover_color(color, 0.12), ButtonStyle.press_color(color, 0.08))
	var normal := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, 4, Margin.ma_2, Margin.ma_0)
	ButtonStyle.apply(button, normal,
		ButtonStyle.filled(normal, ThemeColor.alpha_theme_color(0.12)),
		ButtonStyle.filled(normal, ThemeColor.alpha_theme_color(0.18)))
	pass
