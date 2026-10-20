class_name ChatBubbleFactory
extends Object

## Creates the transcript bubble matching a chat entry kind.

const META_BUBBLE_RICH_TEXT: String = "bubble_rich_text"


static func append(chat_list: VBoxContainer, session_id: int, entry: ChatEntry) -> RichTextLabel:
	match entry.kind:
		ChatEntry.KIND_SYSTEM:
			return DefaultBubble.append(chat_list, entry, build_style(Colors.info_surface), Colors.secondary_text, Colors.info)
		ChatEntry.KIND_SKILL, ChatEntry.KIND_MEMORY, ChatEntry.KIND_AGENT_PROMPT:
			return ContextBubble.append(chat_list, session_id, entry, build_style(Colors.info_surface))
		ChatEntry.KIND_USER:
			return UserBubble.append(chat_list, session_id, entry, build_style(ThemeColor.card_surface), Colors.primary_text)
		ChatEntry.KIND_THINKING:
			return ThinkingBubble.append(chat_list, entry, build_style(Colors.purple_surface))
		ChatEntry.KIND_AGENT:
			return AgentBubble.append(chat_list, entry, build_style(Colors.surface), Colors.primary_text)
		ChatEntry.KIND_TOOL:
			return ToolBubble.append(chat_list, entry, build_style(Colors.success_surface))
		ChatEntry.KIND_WEB_TOOL:
			return WebToolBubble.append(chat_list, entry, build_style(Colors.info_surface))
		ChatEntry.KIND_FILE_TOOL:
			return FileBubble.append(chat_list, entry, build_style(Colors.warning_surface))
		ChatEntry.KIND_GIT_DIFF:
			return GitDiffBubble.append(chat_list, session_id, entry, build_style(Colors.surface))
		ChatEntry.KIND_RESULT:
			return ResultBubble.append(chat_list, entry, build_style(Colors.neutral_surface))
		ChatEntry.KIND_WEB:
			return WebResultBubble.append(chat_list, entry, build_style(Colors.neutral_surface))
		ChatEntry.KIND_ERROR:
			return ErrorBubble.append(chat_list, entry, build_style(Colors.surface), session_id, RuntimeManager.is_running(session_id))
		ChatEntry.KIND_COMPACTION:
			return CompactionBubble.append(chat_list, entry, build_style(ThemeColor.alpha_theme_color(0.08)))
		_:
			return DefaultBubble.append(chat_list, entry, build_style(Colors.surface), Colors.secondary_text)


## Push entry.body into the bubble RichTextLabel using the refresh rules for its kind.
static func refresh_rich_text(rich_text: RichTextLabel, entry: ChatEntry) -> void:
	if not is_instance_valid(rich_text) or entry == null:
		return
	match entry.kind:
		ChatEntry.KIND_THINKING, ChatEntry.KIND_RESULT:
			ChatBubblePreview.apply(rich_text, entry.body)
		ChatEntry.KIND_WEB:
			WebResultBubble.refresh(rich_text, entry)
		ChatEntry.KIND_COMPACTION:
			CompactionBubble.refresh(rich_text, entry)
		ChatEntry.KIND_TOOL:
			ToolBubble.refresh(rich_text, entry)
		ChatEntry.KIND_WEB_TOOL:
			WebToolBubble.refresh(rich_text, entry)
		ChatEntry.KIND_FILE_TOOL:
			FileBubble.refresh(rich_text, entry)
		ChatEntry.KIND_GIT_DIFF:
			GitDiffBubble.refresh(rich_text, entry)
		ChatEntry.KIND_ERROR:
			ErrorBubble.refresh(rich_text, entry)
		ChatEntry.KIND_SKILL, ChatEntry.KIND_MEMORY, ChatEntry.KIND_AGENT_PROMPT:
			ContextBubble.refresh(rich_text, entry)
		_:
			rich_text.visible = StringUtils.is_not_blank(entry.body)
			MarkdownHelper.update_rich_text_label_text(rich_text, entry.body, AgentSetting.get_markdown_enabled())
	pass


static func build_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(bg_color, 8, Margin.ma_3, Margin.ma_3)
	if ThemeColor.is_light_theme():
		style.border_color = Colors.border
		style.set_border_width_all(ControlSize.border_xs)
		style.shadow_color = Color(0, 0, 0, 0.04)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 2)
	return style
