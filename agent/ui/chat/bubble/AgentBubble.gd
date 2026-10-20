class_name AgentBubble
extends BubbleContainer

var rich_text: RichTextLabel

## Agent reply bubble 鈥?markdown body; header copy puts ChatEntry.body on the clipboard.


func apply(_session_id: int, entry: ChatEntry) -> void:
	apply_panel_style(Colors.surface)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.secondary_text)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	var copy_button: Button = Button.new()
	copy_button.text = I18n.t("common.copy")
	style_copy_button(copy_button, Colors.surface)
	copy_button.pressed.connect(on_copy_pressed.bind(entry))
	header.add_child(copy_button)

	vbox.add_child(header)

	rich_text = MarkdownHelper.create_rich_text_label(
		Colors.primary_text,
		StringUtils.EMPTY,
		AgentSetting.get_markdown_enabled()
	)
	vbox.add_child(rich_text)
	refresh(entry)
	pass


func refresh(entry: ChatEntry) -> void:
	if not is_instance_valid(rich_text) or entry == null:
		return
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	MarkdownHelper.update_rich_text_label_text(rich_text, entry.body, AgentSetting.get_markdown_enabled())
	pass


static func on_copy_pressed(entry: ChatEntry) -> void:
	if entry == null or StringUtils.is_blank(entry.body):
		return
	MarkdownHelper.copy_to_clipboard(entry.body)
	Alert.alert(I18n.t("common.copied"), Colors.success)
	pass


static func style_copy_button(button: Button, bubble_bg: Color) -> void:
	style_header_button(button, bubble_bg, I18n.t("common.copy_tooltip"), 40.0)
	pass
