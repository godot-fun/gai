class_name ChatBubbleFactory
extends Object

## Creates the transcript bubble matching a chat entry kind.

const META_BUBBLE_RICH_TEXT: String = "bubble_rich_text"


static func append(chat_list: VBoxContainer, session_id: int, entry: ChatEntry) -> RichTextLabel:
	match entry.kind:
		ChatEntry.KIND_SYSTEM:
			return append_default(chat_list, entry, Colors.secondary_text, Colors.info_surface, Colors.info)
		ChatEntry.KIND_SKILL, ChatEntry.KIND_MEMORY, ChatEntry.KIND_AGENT_PROMPT:
			return ContextBubble.append(chat_list, session_id, entry, build_style(Colors.info_surface))
		ChatEntry.KIND_USER:
			return UserBubble.append(
				chat_list,
				session_id,
				entry,
				build_style(ThemeColor.emphasize(Colors.info_surface, Colors.am_2), true),
				Colors.primary_text
			)
		ChatEntry.KIND_THINKING:
			return ThinkingBubble.append(chat_list, entry, build_style(Colors.purple_surface))
		ChatEntry.KIND_AGENT:
			return AgentBubble.append(chat_list, entry, build_style(Colors.surface), Colors.primary_text)
		ChatEntry.KIND_TOOL:
			return ToolBubble.append(chat_list, entry, build_style(Colors.success_surface))
		ChatEntry.KIND_WEB_TOOL:
			return WebToolBubble.append(chat_list, entry, build_style(Colors.light_blue_surface))
		ChatEntry.KIND_FILE_TOOL:
			return FileBubble.append(chat_list, entry, build_style(Colors.warning_surface))
		ChatEntry.KIND_GIT_DIFF:
			return GitDiffBubble.append(chat_list, session_id, entry, build_style(Colors.surface))
		ChatEntry.KIND_RESULT:
			return ResultBubble.append(chat_list, entry, build_style(Colors.neutral_surface))
		ChatEntry.KIND_WEB:
			return WebResultBubble.append(chat_list, entry, build_style(Colors.neutral_surface))
		ChatEntry.KIND_ERROR:
			return ErrorBubble.append(
				chat_list,
				entry,
				build_style(Colors.surface),
				session_id,
				RuntimeManager.is_running(session_id)
			)
		ChatEntry.KIND_COMPACTION:
			return CompactionBubble.append(
				chat_list,
				entry,
				build_style(ThemeColor.alpha_theme_color(0.08))
			)
		_:
			return append_default(chat_list, entry, Colors.secondary_text, Colors.surface)


static func append_default(
	chat_list: VBoxContainer,
	entry: ChatEntry,
	text_color: Color,
	bg_color: Color,
	title_color: Color = Colors.secondary_text
) -> RichTextLabel:
	var wrapper: PanelContainer = PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", build_style(bg_color))

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	wrapper.add_child(vbox)

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", title_color)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	vbox.add_child(title_label)

	var rich_text: RichTextLabel = MarkdownHelper.create_rich_text_label(
		text_color,
		entry.body,
		AgentSetting.get_markdown_enabled()
	)
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	vbox.add_child(rich_text)
	wrapper.set_meta(META_BUBBLE_RICH_TEXT, rich_text)

	chat_list.add_child(wrapper)
	return rich_text


static func build_style(bg_color: Color, user_beam: bool = false) -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(bg_color, 8, Margin.ma_3, Margin.ma_3)
	if not user_beam and ThemeColor.is_light_theme():
		style.border_color = Colors.border
		style.set_border_width_all(ControlSize.border_xs)
		style.shadow_color = Color(0, 0, 0, 0.04)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 2)
	return style
