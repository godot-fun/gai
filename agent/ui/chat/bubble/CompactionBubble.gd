class_name CompactionBubble
extends BubbleContainer

var rich_text: RichTextLabel

## Expandable summary left behind after older visible chat entries are compacted.

const PREVIEW_LINES: int = 8
var expanded: bool = false
var expand_button: Button


func apply(_session_id: int, entry: ChatEntry) -> void:
	apply_panel_style(ThemeColor.alpha_theme_color(0.08))

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	vbox.add_child(header)

	var title := Label.new()
	title.text = ChatEntry.TITLE_COMPACTION
	title.add_theme_font_override("font", Fonts.semibold())
	title.add_theme_font_size_override("font_size", Typography.label_medium_size)
	title.add_theme_color_override("font_color", ThemeColor.accent_theme_color())
	header.add_child(title)

	expand_button = Button.new()
	expand_button.focus_mode = Control.FOCUS_NONE
	expand_button.pressed.connect(on_expand_pressed.bind(entry))
	style_expand_button(expand_button)
	header.add_child(expand_button)

	rich_text = MarkdownHelper.create_rich_text_label(
		Colors.secondary_text,
		StringUtils.EMPTY,
		AgentSetting.get_markdown_enabled()
	)
	vbox.add_child(rich_text)
	refresh(entry)
	pass


func on_expand_pressed(entry: ChatEntry) -> void:
	expanded = not expanded
	refresh(entry)
	pass


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(rich_text) or entry == null:
		return
	var preview := ChatBubblePreview.first_lines(entry.body, PREVIEW_LINES)
	var can_expand := preview != entry.body
	MarkdownHelper.update_rich_text_label_text(
		rich_text,
		entry.body if expanded or not can_expand else preview,
		AgentSetting.get_markdown_enabled()
	)
	if is_instance_valid(expand_button):
		expand_button.visible = can_expand
		if can_expand:
			if expanded:
				expand_button.text = I18n.t("common.collapse")
				expand_button.tooltip_text = I18n.t("agent.tokens.summary_collapse_tooltip")
			else:
				var hidden_lines := ChatBubblePreview.hidden_line_count(entry.body, PREVIEW_LINES)
				expand_button.text = StringUtils.format(
					I18n.t("agent.chat.expand_lines"),
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
