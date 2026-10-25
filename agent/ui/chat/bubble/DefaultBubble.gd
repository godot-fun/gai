class_name DefaultBubble
extends BubbleContainer

var rich_text: RichTextLabel
var system_entry: bool = false

## Basic titled markdown bubble used by system and unknown chat entry kinds.


func panel_color() -> Color:
	return ThemeColor.promote(Colors.info_surface, Weights.w_2) if system_entry else Colors.surface


func apply(_session_id: int, entry: ChatEntry) -> void:
	system_entry = entry.kind == ChatEntry.KIND_SYSTEM
	apply_panel_style(panel_color())

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	add_child(vbox)

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", Colors.info if entry.kind == ChatEntry.KIND_SYSTEM else Colors.secondary_text)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	vbox.add_child(title_label)

	rich_text = MarkdownHelper.create_rich_text_label(
		Colors.secondary_text,
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
