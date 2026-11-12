class_name ThinkingBubble
extends BubbleContainer

var markdown_label: MarkdownRichTextLabel
var view_button: Button
var line_label: Label

const PREVIEW_LINES := 3

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
	title_label.add_theme_font_size_override("font_size", Typography.label_medium)
	header.add_child(title_label)

	view_button = Button.new()
	view_button.text = "…"
	style_view_button(view_button)
	view_button.pressed.connect(entry.open_full_view)
	header.add_child(view_button)

	line_label = Label.new()
	line_label.add_theme_color_override("font_color", Colors.secondary_text)
	line_label.add_theme_font_size_override("font_size", Typography.label_small)
	header.add_child(line_label)

	vbox.add_child(header)

	markdown_label = MarkdownHelper.create_plain_rich_text_label(Colors.secondary_text)
	vbox.add_child(markdown_label)
	refresh(entry)
	pass


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(markdown_label) or entry == null:
		return
	BubblePreview.apply(markdown_label, view_button, line_label, entry.body, true, PREVIEW_LINES)
	pass


static func style_view_button(button: Button) -> void:
	button.tooltip_text = I18n.t("agent.chat.view_full_thinking")
	button.custom_minimum_size = ControlSize.square(ControlSize.xs)
	button.add_theme_font_size_override("font_size", Typography.label_small)
	ButtonStyle.apply_font_colors(button, Colors.info, ThemeColor.promote(Colors.info, Weights.w_2), ThemeColor.demote(Colors.info, Weights.w_2))

	var border := ThemeColor.demote(Colors.info, Weights.w_2)
	var normal := StyleBoxHelper.create_style_box_flat(ThemeColor.promote(Colors.purple_surface, Weights.w_2), ControlSize.radius_sm, Margin.ma_1, Margin.ma_0, border, ControlSize.border_xs)
	ButtonStyle.apply_style(button, normal,
		StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.promote(Colors.purple_surface, Weights.w_3), Colors.info),
		StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.demote(Colors.purple_surface, Weights.w_2), Colors.info))
	pass
