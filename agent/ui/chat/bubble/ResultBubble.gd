class_name ResultBubble
extends BubbleContainer

var rich_text: RichTextLabel
var view_button: Button
var line_label: Label

## Result bubble — plain text preview in chat.
## Full text lives on ChatEntry.body; the header ··· button opens it in PopupWindow.


func apply(_session_id: int, entry: ChatEntry) -> void:
	apply_panel_style(Colors.neutral_surface)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", title_color_for(entry))
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	view_button = Button.new()
	view_button.text = "…"
	style_view_button(view_button)
	view_button.pressed.connect(entry.open_full_view)
	header.add_child(view_button)

	line_label = Label.new()
	line_label.add_theme_color_override("font_color", Colors.secondary_text)
	line_label.add_theme_font_size_override("font_size", Typography.label_small_size)
	header.add_child(line_label)

	vbox.add_child(header)

	rich_text = MarkdownHelper.create_plain_rich_text_label(Colors.secondary_text)
	vbox.add_child(rich_text)
	refresh(entry)
	pass


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(rich_text) or entry == null:
		return
	BubblePreview.apply(rich_text, view_button, line_label, entry.body)
	pass


static func title_color_for(entry: ChatEntry) -> Color:
	if not entry.title.begins_with("exit_code:"):
		return Colors.secondary_text
	var exit_code: int = int(StringUtils.substring_after(entry.title, "exit_code:"))
	return Colors.secondary_text if exit_code == 0 else Colors.error


static func style_view_button(button: Button) -> void:
	button.tooltip_text = I18n.t("agent.chat.view_full_result")
	button.custom_minimum_size = Vector2(22, 18)
	button.add_theme_font_size_override("font_size", Typography.label_small_size)
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, ButtonStyle.hover_color(Colors.primary_text, 0.08), ButtonStyle.press_color(Colors.secondary_text, 0.08))

	var border := ButtonStyle.press_color(Colors.secondary_text)
	var normal := StyleBoxHelper.create_style_box_flat(ButtonStyle.hover_color(Colors.neutral_surface, 0.08), 4, Margin.ma_1, Margin.ma_0, border, ControlSize.border_xs)
	ButtonStyle.apply(button, normal,
		ButtonStyle.filled(normal, ButtonStyle.hover_color(Colors.neutral_surface, 0.16), Colors.secondary_text),
		ButtonStyle.filled(normal, ButtonStyle.press_color(Colors.neutral_surface, 0.06), Colors.secondary_text))
	pass
