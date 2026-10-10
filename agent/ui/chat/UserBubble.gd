class_name UserBubble
extends Object

## User message bubble — flowing border beam (same shader as chat input).
## Delete drops this turn and everything after it — chat only, code is left alone.
## Revert does the same and restores the workspace snapshot taken before the turn (only shown when
## the entry has one). Both hand the message body back to the chat input for re-editing.
## The body follows the shared Markdown toolbar setting, matching agent replies.

const BeamLayer: GDScript = preload("res://agent/ui/shaders/AccentBorderBeamLayer.gd")
const BUBBLE_CORNER_RADIUS: float = 8.0
const BEAM_STRENGTH: float = 1.0


static func append(
	chat_list: VBoxContainer,
	session_id: int,
	entry: ChatEntry,
	panel_style: StyleBoxFlat,
	text_color: Color,
	title_color: Color = ColorBase.secondary_text
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
		revert_button.text = "Revert"
		AgentBubble.style_header_button(revert_button, panel_style.bg_color, "Delete from here and restore the workspace (message goes back to the input box)", 58.0)
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
		MarkdownToggle.markdown_enabled_for_entry(entry)
	)
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	vbox.add_child(rich_text)

	var beam: AccentBorderBeamLayer = BeamLayer.new()
	beam.name = "BorderBeam"
	beam.z_index = 10
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam.set_fixed_corner_radius(BUBBLE_CORNER_RADIUS)
	beam.set_highlight_strength(BEAM_STRENGTH)
	host.add_child(beam)

	panel.minimum_size_changed.connect(sync_layout.bind(host, panel, beam))
	panel.resized.connect(sync_layout.bind(host, panel, beam))
	host.resized.connect(sync_layout.bind(host, panel, beam))

	host.set_meta(AgentChatView.META_BUBBLE_RICH_TEXT, rich_text)
	chat_list.add_child(host)
	sync_layout.call_deferred(host, panel, beam)
	return rich_text


## Both actions drop the message — the body goes back to the chat input for re-editing
## (via AgentEvents.events.chat_input_prefill, see AgentChatInput).
static func on_delete_from_here_pressed(session_id: int, entry: ChatEntry) -> void:
	AgentEvents.events.chat_input_prefill.emit(entry.body)
	Alert.alert("Message moved to the input box", ColorBase.success)
	AgentSessionManager.delete_chat_from_entry(session_id, entry)
	pass


## Delete plus a workspace revert to the snapshot taken before this turn.
static func on_revert_pressed(session_id: int, entry: ChatEntry) -> void:
	AgentEvents.events.chat_input_prefill.emit(entry.body)
	AgentSessionManager.revert_to_entry(session_id, entry)
	pass

static func sync_layout(host: Control, panel: PanelContainer, beam: AccentBorderBeamLayer) -> void:
	if not is_instance_valid(host) or not is_instance_valid(panel) or not is_instance_valid(beam):
		return
	host.custom_minimum_size = panel.get_combined_minimum_size()
	var pad: int = Margin.ma_1
	var panel_size: Vector2 = panel.size
	if panel_size.x < 1.0 or panel_size.y < 1.0:
		panel_size = panel.get_combined_minimum_size()
	beam.layout_mode = 0
	beam.position = panel.position - Vector2(pad, pad)
	beam.size = panel_size + Vector2(pad * 2.0, pad * 2.0)
	beam.sync_shader_uniforms()
	pass
