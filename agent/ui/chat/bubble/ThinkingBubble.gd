class_name ThinkingBubble
extends BubbleContainer

var rich_text: RichTextLabel
var view_button: Button
var line_label: Label

## Thinking / reasoning bubble — plain text preview in chat.
## Full text lives on ChatEntry.body; the header ··· button opens it in PopupWindow.


func panel_color() -> Color:
	return Colors.purple_surface


func apply(_session_id: int, entry: ChatEntry) -> void:
	apply_panel_style(panel_color())

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.purple)
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
	BubblePreview.apply(rich_text, view_button, line_label, entry.body, true)
	pass


static func style_view_button(button: Button) -> void:
	button.tooltip_text = I18n.t("agent.chat.view_full_thinking")
	button.custom_minimum_size = Vector2(22, 18)
	button.add_theme_font_size_override("font_size", Typography.label_small_size)
	ButtonStyle.apply_font_colors(button, Colors.info, ThemeColor.promote(Colors.info, Colors.am_2), ThemeColor.demote(Colors.info, Colors.am_2))

	var border := ThemeColor.demote(Colors.info, Colors.am_2)
	var normal := StyleBoxHelper.create_style_box_flat(ThemeColor.promote(Colors.purple_surface, Colors.am_2), 4, Margin.ma_1, Margin.ma_0, border, ControlSize.border_xs)
	ButtonStyle.apply_style(button, normal,
		ButtonStyle.filled(normal, ThemeColor.promote(Colors.purple_surface, Colors.am_3), Colors.info),
		ButtonStyle.filled(normal, ThemeColor.demote(Colors.purple_surface, Colors.am_2), Colors.info))
	pass
