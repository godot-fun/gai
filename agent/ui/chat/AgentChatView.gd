class_name AgentChatView
extends RefCounted

## Chat transcript area — bubbles, streaming, and error resume.
## One bubble list per session; switching shows the cached list.

var chat_scroll_node: ScrollContainer
var chat_lists_container: MarginContainer

var chat_list_cache: ChatListCache = ChatListCache.new()
var chat_bubble_flusher: ChatBubbleFlusher = ChatBubbleFlusher.new()
var chat_scroll: ChatScroll = ChatScroll.new()


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(
	p_chat_scroll_node: ScrollContainer,
	p_chat_lists_container: MarginContainer
) -> void:
	chat_scroll_node = p_chat_scroll_node
	chat_lists_container = p_chat_lists_container
	chat_scroll_node.clip_contents = true
	chat_lists_container.clip_contents = true
	ScrollBarStyle.apply(chat_scroll_node.get_v_scroll_bar())
	chat_bubble_flusher.setup()
	chat_scroll.setup(chat_scroll_node)
	gdf.events.theme_changed.connect(on_theme_changed)
	gdf.events.theme_color_changed.connect(on_theme_color_changed)
	gdf.events.locale_changed.connect(on_locale_changed)
	AgentEvents.events.markdown_changed.connect(on_markdown_changed)
	AgentEvents.events.skill_context_changed.connect(on_agent_context_changed)
	AgentEvents.events.memory_context_changed.connect(on_agent_context_changed)
	AgentEvents.events.agent_context_changed.connect(on_agent_context_changed)
	AgentEvents.events.session_selected.connect(on_session_selected)
	AgentEvents.events.session_removed.connect(on_session_removed)
	AgentEvents.events.agent_start.connect(on_agent_start)
	AgentEvents.events.session_stop.connect(on_session_stop)
	AgentEvents.events.compaction_end.connect(on_compaction_end)
	AgentEvents.events.chat_entry_add.connect(on_chat_entry_add)
	AgentEvents.events.chat_entry_update.connect(on_chat_entry_update)
	AgentEvents.events.chat_entry_delete.connect(on_chat_entry_delete)
	pass


# ---------------------------------------------------------------------------
# AgentEvents — session lifecycle
# ---------------------------------------------------------------------------

func on_session_selected(session_id: int, previous_session_id: int) -> void:
	chat_scroll.cache_session_scroll(previous_session_id)
	show_selected_session(session_id)
	refresh_error_resume_buttons()
	pass


func on_session_removed(session_id: int) -> void:
	chat_list_cache.remove(session_id)
	chat_scroll.remove_session(session_id)
	pass


func on_session_stop(session_id: int, _error_message: String) -> void:
	if AgentSessionManager.is_active(session_id):
		refresh_error_resume_buttons()
	chat_bubble_flusher.flush()
	pass


func on_agent_start(session_id: int) -> void:
	if not AgentSessionManager.is_active(session_id):
		return
	chat_scroll.reset_stick_to_bottom()
	refresh_error_resume_buttons()
	pass


func on_compaction_end(session_id: int, success: bool, _error_code: String) -> void:
	if not success:
		return
	var is_active := AgentSessionManager.is_active(session_id)
	if is_active:
		chat_scroll.reset_stick_to_bottom()
	chat_list_cache.remove(session_id)
	if is_active:
		show_session(session_id)
	pass


# ---------------------------------------------------------------------------
# AgentEvents — chat entries & streaming
# ---------------------------------------------------------------------------

func on_chat_entry_add(session_id: int, entry: ChatEntry) -> void:
	if not chat_list_cache.has(session_id):
		return
	if chat_list_cache.get_bubble(session_id, entry) != null:
		return
	chat_list_cache.append_entry(session_id, entry)
	if AgentSessionManager.is_active(session_id):
		chat_scroll.queue_scroll_to_bottom()
	pass


## Streaming token — resolve bubble from list cache, then queue UI refresh.
func on_chat_entry_update(session_id: int, entry: ChatEntry, _channel: String) -> void:
	if not chat_list_cache.has(session_id):
		return
	var bubble: BubbleContainer = chat_list_cache.get_bubble(session_id, entry)
	if bubble == null:
		bubble = chat_list_cache.append_entry(session_id, entry)
	if bubble != null:
		chat_bubble_flusher.enqueue(bubble, entry)
	pass


func on_chat_entry_delete(session_id: int, entry_idx: int, delete_from_here: bool) -> void:
	chat_list_cache.remove_entries(session_id, entry_idx, delete_from_here)
	pass


# ---------------------------------------------------------------------------
# AgentEvents — appearance
# ---------------------------------------------------------------------------

## Re-render the transcript after a context prompt (skills / memory / AGENTS.md) is added or removed.
func on_agent_context_changed(session_id: int) -> void:
	invalidate_session(session_id)
	pass


func on_markdown_changed(_enabled: bool) -> void:
	var session: AgentSession = AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	if session == null:
		return
	for entry: ChatEntry in session.chat_entries:
		var bubble: BubbleContainer = chat_list_cache.get_bubble(session.id, entry)
		if bubble == null:
			continue
		bubble.refresh(entry)
	chat_list_cache.remove_all_except(AgentSessionManager.active_session_id)
	pass


func on_theme_changed() -> void:
	ScrollBarStyle.apply(chat_scroll_node.get_v_scroll_bar())
	rebuild(AgentSessionManager.active_session_id)
	pass


func on_locale_changed() -> void:
	rebuild(AgentSessionManager.active_session_id)
	pass


## Markdown colors are derived from the theme color, so a color pick has to re-render the
## transcript — but only once per window: the picker emits on every drag step.
func on_theme_color_changed() -> void:
	ScrollBarStyle.apply(chat_scroll_node.get_v_scroll_bar())
	if RateLimitUtils.limit_millis_100():
		return
	SchedulerBus.schedule(on_theme_color_rebuild, 100)
	pass


func on_theme_color_rebuild() -> void:
	rebuild(AgentSessionManager.active_session_id)
	pass


# ---------------------------------------------------------------------------
# Session bubble lists (cache)
# ---------------------------------------------------------------------------

func show_session(session_id: int) -> void:
	var session: AgentSession = AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var has_cached_scroll: bool = chat_scroll.has_cached_session_scroll(session_id)

	# One bubble list per session — create on first open, reuse on later switches.
	var chat_list := chat_list_cache.show(session_id, chat_lists_container)
	chat_scroll.set_active_chat_list(chat_list)

	if chat_list.get_child_count() == 0:
		for entry: ChatEntry in session.chat_entries:
			chat_list_cache.append_entry(session.id, entry)

	chat_scroll.queue_restore_session_scroll_after_layout(session_id, has_cached_scroll)
	pass


## Session selection favors the latest message and fills older bubbles one per frame.
func show_selected_session(session_id: int) -> void:
	var session: AgentSession = AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var has_cached_scroll: bool = chat_scroll.has_cached_session_scroll(session_id)
	var chat_list := chat_list_cache.show(session_id, chat_lists_container)
	chat_scroll.set_active_chat_list(chat_list)
	if chat_list.get_child_count() > 0:
		chat_scroll.queue_restore_session_scroll_after_layout(session_id, has_cached_scroll)
		return

	var bubbles_per_frame := 32
	var vbar: VScrollBar = chat_scroll_node.get_v_scroll_bar()
	var batch_created_count := 0
	var keep_scroll_at_bottom := func() -> void:
		if AgentSessionManager.is_active(session.id):
			vbar.value = vbar.max_value - vbar.page
	vbar.changed.connect(keep_scroll_at_bottom)
	for index: int in range(session.chat_entries.size() - 1, -1, -1):
		if chat_list_cache.get_list(session.id) != chat_list:
			vbar.changed.disconnect(keep_scroll_at_bottom)
			return
		var bubble := ChatBubbleFactory.append(chat_list, session.id, session.chat_entries[index])
		chat_list.move_child(bubble, 0)
		batch_created_count += 1
		if batch_created_count < bubbles_per_frame:
			continue
		await RenderingServer.frame_post_draw
		keep_scroll_at_bottom.call()
		batch_created_count = 0
		bubbles_per_frame = 128
	if batch_created_count > 0:
		await RenderingServer.frame_post_draw
		keep_scroll_at_bottom.call()
	vbar.changed.disconnect(keep_scroll_at_bottom)
	if has_cached_scroll and AgentSessionManager.is_active(session_id):
		chat_scroll.queue_restore_session_scroll_after_layout(session_id, true)
	pass


func rebuild(session_id: int) -> void:
	chat_scroll.cache_session_scroll(session_id)
	chat_list_cache.clear_all()
	show_session(session_id)
	pass


func invalidate_session(session_id: int) -> void:
	var is_active: bool = AgentSessionManager.is_active(session_id)
	if is_active:
		chat_scroll.cache_session_scroll(session_id)
	chat_list_cache.remove(session_id)
	if is_active:
		show_session(session_id)
	pass


func refresh_error_resume_buttons() -> void:
	var active_chat_list := chat_list_cache.get_list(AgentSessionManager.active_session_id)
	if active_chat_list == null:
		return
	ErrorBubble.refresh_resume_buttons(active_chat_list, RuntimeManager.is_running(AgentSessionManager.active_session_id))
	pass
