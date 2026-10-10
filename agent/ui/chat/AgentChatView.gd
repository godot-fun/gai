class_name AgentChatView
extends RefCounted

## Chat transcript area — bubbles, streaming, scroll, error resume.
## One bubble list per session; switching shows the cached list.

const META_BUBBLE_RICH_TEXT: String = "bubble_rich_text"
## The color picker emits on every drag step; the transcript re-renders once the theme color settles.
const THEME_COLOR_REBUILD_DELAY_MS: int = 250
## Keeps a little context above an entry opened from search.
const SEARCH_ENTRY_TOP_MARGIN: float = 20.0


var chat_scroll: ScrollContainer
var chat_host: Control

var chat_list_caches: Dictionary[int, VBoxContainer] = {}
var scroll_position_caches: Dictionary[int, float] = {}
var chat_bubble_flusher: ChatBubbleFlusher = ChatBubbleFlusher.new()
## When true, new content keeps the transcript scrolled to the latest bubble.
var stick_to_bottom: bool = true
var scroll_to_bottom_queued: bool = false
var theme_color_rebuild_scheduled: bool = false
var search_target_session_id: int = 0
var search_target_entry_index: int = -1


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(
	p_chat_scroll: ScrollContainer,
	p_chat_host: Control
) -> void:
	chat_scroll = p_chat_scroll
	chat_host = p_chat_host
	chat_scroll.clip_contents = true
	chat_host.clip_contents = true
	ScrollBarStyle.apply(chat_scroll.get_v_scroll_bar())
	chat_bubble_flusher.setup()
	SchedulerBus.schedule_at_fixed_rate(queue_scroll_to_bottom, 1000, "agent_chat_stick_to_bottom")
	chat_scroll.gui_input.connect(on_chat_scroll_gui_input)
	# The bar swallows wheel/drag events before the container sees them.
	chat_scroll.get_v_scroll_bar().scrolling.connect(on_chat_scroll_bar_scrolling)
	chat_scroll.get_window().window_input.connect(on_chat_window_input)
	gdf.events.theme_changed.connect(on_theme_changed)
	gdf.events.theme_color_changed.connect(on_theme_color_changed)
	AgentEvents.events.markdown_changed.connect(on_markdown_changed)
	AgentEvents.events.skill_context_changed.connect(on_agent_context_changed)
	AgentEvents.events.agent_context_changed.connect(on_agent_context_changed)
	AgentEvents.events.session_selected.connect(on_session_selected)
	AgentEvents.events.session_removed.connect(on_session_removed)
	AgentEvents.events.agent_start.connect(on_agent_start)
	AgentEvents.events.session_stop.connect(on_session_stop)
	AgentEvents.events.chat_entry_add.connect(on_chat_entry_add)
	AgentEvents.events.chat_entry_update.connect(on_chat_entry_update)
	AgentEvents.events.chat_bubble_flushed.connect(on_chat_bubble_flushed)
	AgentEvents.events.chat_entry_delete.connect(on_chat_truncated)
	AgentEvents.events.chat_search_result_selected.connect(on_chat_search_result_selected)
	pass


# ---------------------------------------------------------------------------
# AgentEvents — session lifecycle
# ---------------------------------------------------------------------------

func on_session_selected(session_id: int, previous_session_id: int) -> void:
	cache_session_scroll(previous_session_id)
	show_session(session_id)
	refresh_error_resume_buttons()
	pass


func on_session_removed(session_id: int) -> void:
	clear_bubble_list(session_id)
	scroll_position_caches.erase(session_id)
	pass


func on_session_stop(session_id: int) -> void:
	if AgentSessionManager.is_active(session_id):
		refresh_error_resume_buttons()
	chat_bubble_flusher.flush_now()
	pass


func on_agent_start(session_id: int) -> void:
	if not AgentSessionManager.is_active(session_id):
		return
	reset_stick_to_bottom()
	refresh_error_resume_buttons()
	pass


# ---------------------------------------------------------------------------
# AgentEvents — chat entries & streaming
# ---------------------------------------------------------------------------

func on_chat_entry_add(session_id: int, entry: ChatEntry) -> void:
	if get_bubble_rich_text(session_id, entry) != null:
		return
	if chat_list_caches.get(session_id) == null:
		return
	append_entry_bubble(entry, session_id)
	pass


## Streaming token — resolve bubble from list cache, then queue UI refresh.
func on_chat_entry_update(session_id: int, entry: ChatEntry, _channel: String) -> void:
	if chat_list_caches.get(session_id) == null:
		return
	var rich_text: RichTextLabel = get_bubble_rich_text(session_id, entry)
	if rich_text == null:
		rich_text = append_entry_bubble(entry, session_id)
	if rich_text != null:
		chat_bubble_flusher.enqueue(rich_text, entry)
	pass


## Scroll after ChatBubbleFlusher drains a batch (see AgentEvents.bubble_rich_text_flushed).
func on_chat_bubble_flushed() -> void:
	queue_scroll_to_bottom()
	pass


func on_chat_truncated(session_id: int) -> void:
	var is_active: bool = AgentSessionManager.is_active(session_id)
	if is_active:
		cache_session_scroll(session_id)
	clear_bubble_list(session_id)
	if is_active:
		show_session(session_id)
	pass


## Reveals the persisted entry selected by chat search after the target session is visible.
func on_chat_search_result_selected(session_id: int, entry_index: int) -> void:
	if not AgentSessionManager.is_active(session_id):
		return
	search_target_session_id = session_id
	search_target_entry_index = entry_index
	stick_to_bottom = false
	reveal_entry_after_layout(session_id, entry_index)
	pass


## A newly opened transcript needs two layout passes before RichTextLabel heights and the
## ScrollContainer range are final. Waiting here also lets any queued bottom-scroll abort
## after [member stick_to_bottom] was disabled above.
func reveal_entry_after_layout(session_id: int, entry_index: int) -> void:
	var tree := chat_scroll.get_tree()
	if tree != null:
		await tree.process_frame
		await tree.process_frame
	if not AgentSessionManager.is_active(session_id) or search_target_session_id != session_id or search_target_entry_index != entry_index:
		return
	# First-open restoration enables bottom-follow one frame after session selection.
	# Disable it again at the final positioning point so the periodic follower cannot
	# overwrite the search result position.
	stick_to_bottom = false
	reveal_entry(entry_index)
	cache_session_scroll(session_id)
	search_target_session_id = 0
	search_target_entry_index = -1
	pass


func reveal_entry(entry_index: int) -> void:
	var list := get_active_chat_list()
	if list == null or entry_index < 0 or entry_index >= list.get_child_count():
		return
	var entry_control := list.get_child(entry_index) as Control
	var vbar := chat_scroll.get_v_scroll_bar()
	if entry_control == null or vbar == null:
		return
	# The bar value is expressed in ChatMargin content coordinates. The list starts after
	# ChatMargin's top inset, and each entry position is local to the list.
	var entry_y := list.position.y + entry_control.position.y
	var max_scroll := maxf(vbar.min_value, vbar.max_value - vbar.page)
	vbar.value = clampf(entry_y - SEARCH_ENTRY_TOP_MARGIN, vbar.min_value, max_scroll)
	pass


# ---------------------------------------------------------------------------
# AgentEvents — appearance
# ---------------------------------------------------------------------------

## Re-render the transcript after a context prompt (skill index / AGENTS.md) is added or removed.
func on_agent_context_changed(session_id: int) -> void:
	var is_active: bool = AgentSessionManager.is_active(session_id)
	if is_active:
		cache_session_scroll(session_id)
	clear_bubble_list(session_id)
	if is_active:
		show_session(session_id)
	pass


func on_markdown_changed(_enabled: bool) -> void:
	var session: AgentSession = AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	if session == null:
		return
	for entry: ChatEntry in session.chat_entries:
		var rich_text: RichTextLabel = get_bubble_rich_text(session.id, entry)
		if rich_text == null:
			continue
		match entry.kind:
			ChatEntry.KIND_THINKING, ChatEntry.KIND_RESULT:
				ChatBubblePreview.apply(rich_text, entry.body)
			ChatEntry.KIND_FILE_TOOL:
				FileBubble.refresh(rich_text, entry)
			ChatEntry.KIND_GIT_DIFF:
				GitDiffBubble.refresh(rich_text, entry)
			ChatEntry.KIND_ERROR:
				ErrorBubble.refresh(rich_text, entry)
			_:
				ChatBubbleFlusher.refresh_rich_text(rich_text, entry)
	clear_inactive_bubble_lists()
	pass


func on_theme_changed() -> void:
	ScrollBarStyle.apply(chat_scroll.get_v_scroll_bar())
	rebuild(AgentSessionManager.active_session_id)
	pass


## Markdown colors are derived from the theme color, so a color pick has to re-render the
## transcript — but only once: the picker emits on every drag step.
func on_theme_color_changed() -> void:
	ScrollBarStyle.apply(chat_scroll.get_v_scroll_bar())
	if theme_color_rebuild_scheduled:
		return
	theme_color_rebuild_scheduled = true
	SchedulerBus.schedule(on_theme_color_rebuild, THEME_COLOR_REBUILD_DELAY_MS)
	pass


func on_theme_color_rebuild() -> void:
	theme_color_rebuild_scheduled = false
	rebuild(AgentSessionManager.active_session_id)
	pass


# ---------------------------------------------------------------------------
# Session bubble lists (cache)
# ---------------------------------------------------------------------------

func show_session(session_id: int) -> void:
	var session: AgentSession = AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var has_cached_scroll: bool = scroll_position_caches.has(session_id)

	# One bubble list per session — create on first open, reuse on later switches.
	var list: VBoxContainer = chat_list_caches.get(session_id)
	if list == null:
		list = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", Margin.ma_3)
		chat_host.add_child(list)
		chat_list_caches[session_id] = list

	for id: int in chat_list_caches:
		chat_list_caches[id].visible = id == session_id

	if list.get_child_count() == 0:
		fill_list(session)

	queue_restore_session_scroll_after_layout(session_id, has_cached_scroll)
	pass


func rebuild(session_id: int) -> void:
	cache_session_scroll(session_id)
	clear_all_bubble_lists()
	show_session(session_id)
	pass


func fill_list(session: AgentSession) -> void:
	for entry: ChatEntry in session.chat_entries:
		append_entry_bubble(entry, session.id)
	pass


func clear_bubble_list(session_id: int) -> void:
	var list: VBoxContainer = chat_list_caches.get(session_id)
	if list == null:
		return
	chat_list_caches.erase(session_id)
	list.queue_free()
	pass


func clear_inactive_bubble_lists() -> void:
	var drop_ids: Array[int] = []
	for session_id: int in chat_list_caches:
		if session_id != AgentSessionManager.active_session_id:
			drop_ids.append(session_id)
	for session_id: int in drop_ids:
		clear_bubble_list(session_id)
	pass


func clear_all_bubble_lists() -> void:
	var drop_ids: Array[int] = []
	drop_ids.assign(chat_list_caches.keys())
	for session_id: int in drop_ids:
		clear_bubble_list(session_id)
	pass


func get_active_chat_list() -> VBoxContainer:
	return chat_list_caches.get(AgentSessionManager.active_session_id)


# ---------------------------------------------------------------------------
# Bubbles
# ---------------------------------------------------------------------------

func append_entry_bubble(chat_entry: ChatEntry, session_id: int) -> RichTextLabel:
	var chat_list: VBoxContainer = chat_list_caches.get(session_id)
	if chat_list == null:
		return null
	var rich_text: RichTextLabel = null
	match chat_entry.kind:
		ChatEntry.KIND_SYSTEM:
			rich_text = append_bubble(chat_list, chat_entry, ColorBase.secondary_text, ColorBase.info_surface, ColorBase.info)
		ChatEntry.KIND_SKILL, ChatEntry.KIND_AGENT_PROMPT:
			rich_text = SkillBubble.append(
					chat_list,
					chat_entry,
					build_bubble_style(ColorBase.info_surface)
			)
		ChatEntry.KIND_USER:
			rich_text = UserBubble.append(
					chat_list,
					session_id,
					chat_entry,
					build_bubble_style(ColorBase.strong_info_surface, true),
					ColorBase.primary_text
			)
			queue_scroll_to_bottom()
		ChatEntry.KIND_THINKING:
			rich_text = ThinkingBubble.append(
					chat_list,
					chat_entry,
					build_bubble_style(ColorBase.purple_surface)
			)
			queue_scroll_to_bottom()
		ChatEntry.KIND_AGENT:
			rich_text = AgentBubble.append(
					chat_list,
					chat_entry,
					build_bubble_style(ColorBase.surface),
					ColorBase.primary_text
			)
			queue_scroll_to_bottom()
		ChatEntry.KIND_TOOL:
			rich_text = append_bubble(
					chat_list,
					chat_entry,
					ColorBase.success,
					ColorBase.success_surface,
					ColorBase.success
			)
		ChatEntry.KIND_FILE_TOOL:
			rich_text = FileBubble.append(
					chat_list,
					chat_entry,
					build_bubble_style(ColorBase.warning_surface)
			)
			queue_scroll_to_bottom()
		ChatEntry.KIND_GIT_DIFF:
			rich_text = GitDiffBubble.append(
					chat_list,
					chat_entry,
					build_bubble_style(ColorBase.surface)
			)
			queue_scroll_to_bottom()
		ChatEntry.KIND_RESULT:
			rich_text = ResultBubble.append(
					chat_list,
					chat_entry,
					build_bubble_style(ColorBase.neutral_surface)
			)
			queue_scroll_to_bottom()
		ChatEntry.KIND_ERROR:
			rich_text = ErrorBubble.append(
					chat_list,
					chat_entry,
					build_bubble_style(ColorBase.surface),
					session_id,
					RuntimeManager.is_running(session_id)
			)
			queue_scroll_to_bottom()
		_:
			rich_text = append_bubble(chat_list, chat_entry, ColorBase.secondary_text, ColorBase.surface)
	return rich_text


func append_bubble(chat_list: VBoxContainer, entry: ChatEntry, text_color: Color, bg_color: Color, title_color: Color = ColorBase.secondary_text) -> RichTextLabel:
	var wrapper: PanelContainer = PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", build_bubble_style(bg_color))

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
		MarkdownToggle.markdown_enabled_for_entry(entry)
	)
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	vbox.add_child(rich_text)
	wrapper.set_meta(META_BUBBLE_RICH_TEXT, rich_text)

	chat_list.add_child(wrapper)
	queue_scroll_to_bottom()
	return rich_text


func build_bubble_style(bg_color: Color, user_beam: bool = false) -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(bg_color, 8, Margin.ma_3, Margin.ma_3)
	if not user_beam and ThemeColor.is_light_theme():
		style.border_color = ColorBase.border
		style.set_border_width_all(ControlSize.border_xs)
		style.shadow_color = Color(0, 0, 0, 0.04)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 2)
	return style


## chat_entries index matches VBoxContainer child order; label lives on wrapper meta.
func get_bubble_rich_text(session_id: int, entry: ChatEntry) -> RichTextLabel:
	var session: AgentSession = AgentSessionStore.load_session(session_id)
	var list: VBoxContainer = chat_list_caches.get(session_id)
	if session == null or list == null:
		return null
	var index: int = session.chat_entries.find(entry)
	if index < 0 or index >= list.get_child_count():
		return null
	var wrapper: Node = list.get_child(index)
	return wrapper.get_meta(META_BUBBLE_RICH_TEXT) as RichTextLabel


func refresh_error_resume_buttons() -> void:
	var active_chat_list: VBoxContainer = get_active_chat_list()
	if active_chat_list == null:
		return
	ErrorBubble.refresh_resume_buttons(active_chat_list, RuntimeManager.is_running(AgentSessionManager.active_session_id))
	pass


# ---------------------------------------------------------------------------
# Scroll
# ---------------------------------------------------------------------------

func reset_stick_to_bottom() -> void:
	stick_to_bottom = true
	queue_scroll_to_bottom()
	pass


func cache_session_scroll(session_id: int) -> void:
	if not AgentSessionManager.has_index(session_id):
		return
	var vbar: VScrollBar = chat_scroll.get_v_scroll_bar()
	if vbar == null:
		return
	scroll_position_caches[session_id] = vbar.value
	pass


func on_chat_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if not mouse.pressed:
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			stick_to_bottom = false
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and is_scrolled_to_bottom():
			# Wheel scrolled all the way down — re-enable follow so new
			# content automatically keeps the transcript at the bottom.
			stick_to_bottom = true
	elif event is InputEventPanGesture:
		stick_to_bottom = is_scrolled_to_bottom()
	pass


## Dragging the scrollbar grabber (or wheeling over the bar itself) reads history
## instead of following the stream — follow resumes at the bottom edge.
func on_chat_scroll_bar_scrolling() -> void:
	stick_to_bottom = is_scrolled_to_bottom()
	pass


## Page keys belong to the focused TextEdit by default; route Godot's native page
## actions to the transcript so they work while composing a message.
func on_chat_window_input(event: InputEvent) -> void:
	# Window input can still arrive while the chat scene is being removed from the tree.
	if not is_instance_valid(chat_scroll) or not chat_scroll.is_inside_tree():
		return
	# Embedded windows do not clear the host window's focus flag, so check them explicitly.
	for window: Window in chat_scroll.get_tree().root.get_embedded_subwindows():
		if window.visible:
			return
	if not chat_scroll.get_window().has_focus():
		return
	if not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed:
		return
	var direction: int = 0
	if key.is_action_pressed(&"ui_page_up", true):
		direction = -1
		stick_to_bottom = false
	elif key.is_action_pressed(&"ui_page_down", true):
		direction = 1
	else:
		return
	var vbar: VScrollBar = chat_scroll.get_v_scroll_bar()
	if vbar == null or vbar.max_value <= vbar.page:
		return
	vbar.value = clampf(vbar.value + vbar.page * direction, vbar.min_value, vbar.max_value - vbar.page)
	if direction > 0:
		stick_to_bottom = is_scrolled_to_bottom()
	chat_scroll.get_viewport().set_input_as_handled()
	pass


## True when the transcript is already scrolled to (or within a pixel of) the bottom edge.
func is_scrolled_to_bottom() -> bool:
	var vbar: VScrollBar = chat_scroll.get_v_scroll_bar()
	if vbar == null:
		return true
	return vbar.value >= vbar.max_value - vbar.page - 1.0


func queue_scroll_to_bottom() -> void:
	if not stick_to_bottom or scroll_to_bottom_queued:
		return
	scroll_to_bottom_queued = true
	flush_scroll_to_bottom.call_deferred()
	pass


## The list lives inside ChatMargin, so the last bubble counts as "visible" while the
## bar still owes the bottom margin — ensure_control_visible() stops one margin short.
## Drive the bar to its own bottom edge so the transcript ends flush with the view.
func flush_scroll_to_bottom() -> void:
	scroll_to_bottom_queued = false
	if not stick_to_bottom:
		return
	var active_chat_list: VBoxContainer = get_active_chat_list()
	if active_chat_list == null or not active_chat_list.visible:
		return
	if active_chat_list.get_child_count() == 0:
		return
	var vbar: VScrollBar = chat_scroll.get_v_scroll_bar()
	if vbar == null:
		return
	vbar.value = vbar.max_value - vbar.page
	pass


## Wait one frame for the selected list to establish its scroll range, then restore it.
func queue_restore_session_scroll_after_layout(session_id: int, has_cached_scroll: bool) -> void:
	var tree: SceneTree = chat_scroll.get_tree()
	if tree == null:
		restore_session_scroll(session_id, has_cached_scroll)
		return
	tree.process_frame.connect(func() -> void:
		restore_session_scroll(session_id, has_cached_scroll)
	, CONNECT_ONE_SHOT)
	pass


func restore_session_scroll(session_id: int, has_cached_scroll: bool) -> void:
	if not AgentSessionManager.is_active(session_id):
		return
	if search_target_session_id == session_id:
		return
	if not has_cached_scroll:
		stick_to_bottom = true
		queue_scroll_to_bottom()
		return
	var vbar: VScrollBar = chat_scroll.get_v_scroll_bar()
	if vbar == null:
		return
	var cached_position: float = scroll_position_caches.get(session_id, 0.0)
	vbar.value = clampf(cached_position, vbar.min_value, vbar.max_value - vbar.page)
	pass
