class_name UserBubble
extends Object

## User message bubble with a moving accent border shared with the chat input.
## Delete drops this turn and everything after it — chat only, code is left alone.
## Revert does the same and restores the workspace snapshot taken before the turn (only shown when
## the entry has one). Both hand the message body back to the chat input for re-editing.
## The body follows the shared Markdown toolbar setting, matching agent replies.

const BORDER_HIGHLIGHT_STRENGTH: float = 1.0


static func append(
	chat_list: VBoxContainer,
	session_id: int,
	entry: ChatEntry,
	panel_style: StyleBoxFlat,
	text_color: Color,
	title_color: Color = Colors.secondary_text
) -> RichTextLabel:
	var host: Control = Control.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.clip_contents = false

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.set_offsets_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style)
	host.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", Margin.ma_2)
	panel.add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_label: Label = Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", title_color)
	title_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	header.add_child(title_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	# Revert is only offered when this turn has a workspace snapshot (older chats have none).
	var checkpoint: String = entry.details.get(ChatEntry.DETAIL_CHECKPOINT, "")
	if StringUtils.is_not_blank(checkpoint):
		var revert_button: Button = Button.new()
		revert_button.name = "RevertButton"
		revert_button.text = I18n.t("git.revert")
		AgentBubble.style_header_button(revert_button, panel_style.bg_color, I18n.t("git.revert_user_message"), 58.0)
		revert_button.pressed.connect(on_revert_pressed.bind(session_id, entry))
		header.add_child(revert_button)

	var delete_from_here_button: Button = Button.new()
	delete_from_here_button.name = "DeleteFromHereButton"
	delete_from_here_button.text = "Delete"
	AgentBubble.style_header_button(delete_from_here_button, panel_style.bg_color, "Delete from here (message goes back to the input box, workspace is kept)", 52.0)
	delete_from_here_button.pressed.connect(on_delete_from_here_pressed.bind(session_id, entry))
	header.add_child(delete_from_here_button)

	vbox.add_child(header)

	var rich_text: RichTextLabel = MarkdownHelper.create_rich_text_label(
		text_color,
		entry.body,
		AgentSetting.get_markdown_enabled()
	)
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	vbox.add_child(rich_text)

	var moving_border := MovingAccentBorder.new()
	moving_border.name = "MovingAccentBorder"
	moving_border.z_index = 10
	moving_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moving_border.set_corner_radius(ControlSize.radius_lg)
	moving_border.set_highlight_strength(BORDER_HIGHLIGHT_STRENGTH)
	host.add_child(moving_border)

	panel.minimum_size_changed.connect(sync_layout.bind(host, panel, moving_border))
	panel.resized.connect(sync_layout.bind(host, panel, moving_border))
	host.resized.connect(sync_layout.bind(host, panel, moving_border))

	host.set_meta(ChatBubbleFactory.META_BUBBLE_RICH_TEXT, rich_text)
	chat_list.add_child(host)
	sync_layout.call_deferred(host, panel, moving_border)
	return rich_text


## Both actions drop the message — the body goes back to the chat input for re-editing
## (via AgentEvents.events.chat_input_prefill, see AgentChatInput).
static func on_delete_from_here_pressed(session_id: int, entry: ChatEntry) -> void:
	AgentEvents.events.chat_input_prefill.emit(entry.body)
	Alert.alert("Message moved to the input box", Colors.success)
	AgentSessionManager.delete_chat_from_entry(session_id, entry)
	pass


## Delete plus a workspace revert to the snapshot taken before this turn.
static func on_revert_pressed(session_id: int, entry: ChatEntry) -> void:
	AgentEvents.events.chat_input_prefill.emit(entry.body)
	var sha: String = entry.details.get(ChatEntry.DETAIL_CHECKPOINT, "")
	if not await GitCheckpointManager.async_restore(session_id, sha):
		Alert.alert(I18n.t("git.restore_failed"), Colors.error)
		return
	AgentSessionManager.delete_chat_from_entry(session_id, entry)
	Alert.alert(I18n.t("git.restored"), Colors.success)
	pass

static func sync_layout(host: Control, panel: PanelContainer, moving_border: MovingAccentBorder) -> void:
	if not is_instance_valid(host) or not is_instance_valid(panel) or not is_instance_valid(moving_border):
		return
	host.custom_minimum_size = panel.get_combined_minimum_size()
	var pad: int = Margin.ma_1
	var panel_size: Vector2 = panel.size
	if panel_size.x < 1.0 or panel_size.y < 1.0:
		panel_size = panel.get_combined_minimum_size()
	moving_border.layout_mode = 0
	moving_border.position = panel.position - Vector2(pad, pad)
	moving_border.size = panel_size + Vector2(pad * 2.0, pad * 2.0)
	moving_border.sync_geometry_uniforms()
	pass
