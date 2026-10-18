class_name AgentChatView
extends RefCounted

## Chat transcript area — bubbles, streaming, and error resume.
## One bubble list per session; switching shows the cached list.

## The color picker emits on every drag step; the transcript re-renders once the theme color settles.
const THEME_COLOR_REBUILD_DELAY_MS: int = 250
## Retain the most recently used transcript control trees; scroll positions remain cached separately.
const CHAT_LIST_CACHE_MAX_SIZE: int = 18


var chat_scroll: ScrollContainer
var chat_host: Control

var chat_list_caches: LruCacheInt = LruCacheInt.new(CHAT_LIST_CACHE_MAX_SIZE)
var chat_bubble_flusher: ChatBubbleFlusher = ChatBubbleFlusher.new()
var chat_scroll_controller: AgentChatScroll = AgentChatScroll.new()
var theme_color_rebuild_scheduled: bool = false


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
	chat_scroll_controller.setup(chat_scroll)
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
	AgentEvents.events.chat_entry_delete.connect(on_chat_truncated)
	pass


# ---------------------------------------------------------------------------
# AgentEvents — session lifecycle
# ---------------------------------------------------------------------------

func on_session_selected(session_id: int, previous_session_id: int) -> void:
	chat_scroll_controller.cache_session_scroll(previous_session_id)
	show_session(session_id)
	refresh_error_resume_buttons()
	pass


func on_session_removed(session_id: int) -> void:
	clear_bubble_list(session_id)
	chat_scroll_controller.remove_session(session_id)
	pass


func on_session_stop(session_id: int, _error_message: String) -> void:
	if AgentSessionManager.is_active(session_id):
		refresh_error_resume_buttons()
	chat_bubble_flusher.flush_now()
	pass


func on_agent_start(session_id: int) -> void:
	if not AgentSessionManager.is_active(session_id):
		return
	chat_scroll_controller.reset_stick_to_bottom()
	refresh_error_resume_buttons()
	pass


func on_compaction_end(session_id: int, success: bool, _error_code: String) -> void:
	if not success:
		return
	var is_active := AgentSessionManager.is_active(session_id)
	if is_active:
		chat_scroll_controller.reset_stick_to_bottom()
	clear_bubble_list(session_id)
	if is_active:
		show_session(session_id)
	pass


# ---------------------------------------------------------------------------
# AgentEvents — chat entries & streaming
# ---------------------------------------------------------------------------

func on_chat_entry_add(session_id: int, entry: ChatEntry) -> void:
	if get_bubble_rich_text(session_id, entry) != null:
		return
	if chat_list_caches.get_value(session_id) == null:
		return
	append_entry_bubble(entry, session_id)
	if AgentSessionManager.is_active(session_id):
		chat_scroll_controller.queue_scroll_to_bottom()
	pass


## Streaming token — resolve bubble from list cache, then queue UI refresh.
func on_chat_entry_update(session_id: int, entry: ChatEntry, _channel: String) -> void:
	if chat_list_caches.get_value(session_id) == null:
		return
	var rich_text: RichTextLabel = get_bubble_rich_text(session_id, entry)
	if rich_text == null:
		rich_text = append_entry_bubble(entry, session_id)
	if rich_text != null:
		chat_bubble_flusher.enqueue(rich_text, entry)
	pass


func on_chat_truncated(session_id: int) -> void:
	var is_active: bool = AgentSessionManager.is_active(session_id)
	if is_active:
		chat_scroll_controller.cache_session_scroll(session_id)
	clear_bubble_list(session_id)
	if is_active:
		show_session(session_id)
	pass


# ---------------------------------------------------------------------------
# AgentEvents — appearance
# ---------------------------------------------------------------------------

## Re-render the transcript after a context prompt (skills / memory / AGENTS.md) is added or removed.
func on_agent_context_changed(session_id: int) -> void:
	var is_active: bool = AgentSessionManager.is_active(session_id)
	if is_active:
		chat_scroll_controller.cache_session_scroll(session_id)
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
		ChatBubbleFlusher.refresh_rich_text(rich_text, entry)
	clear_inactive_bubble_lists()
	pass


func on_theme_changed() -> void:
	ScrollBarStyle.apply(chat_scroll.get_v_scroll_bar())
	rebuild(AgentSessionManager.active_session_id)
	pass


func on_locale_changed() -> void:
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
	var has_cached_scroll: bool = chat_scroll_controller.has_cached_session_scroll(session_id)

	# One bubble list per session — create on first open, reuse on later switches.
	var list := chat_list_caches.get_value(session_id) as VBoxContainer
	if list == null:
		list = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", Margin.ma_3)
		chat_host.add_child(list)
		var old_entry := chat_list_caches.put_if_absent(session_id, list)
		if old_entry != null:
			var old_list := old_entry.value as VBoxContainer
			old_list.queue_free()

	for id: int in chat_list_caches.cache_map:
		var cached_list := chat_list_caches.cache_map[id] as VBoxContainer
		cached_list.visible = id == session_id
	chat_scroll_controller.set_active_chat_list(list)

	if list.get_child_count() == 0:
		fill_list(session)

	chat_scroll_controller.queue_restore_session_scroll_after_layout(session_id, has_cached_scroll)
	pass


func rebuild(session_id: int) -> void:
	chat_scroll_controller.cache_session_scroll(session_id)
	clear_all_bubble_lists()
	show_session(session_id)
	pass


func fill_list(session: AgentSession) -> void:
	for entry: ChatEntry in session.chat_entries:
		append_entry_bubble(entry, session.id)
	pass


func clear_bubble_list(session_id: int) -> void:
	var list := chat_list_caches.remove(session_id) as VBoxContainer
	if list == null:
		return
	chat_scroll_controller.clear_active_chat_list(list)
	list.queue_free()
	pass


func clear_inactive_bubble_lists() -> void:
	var drop_ids: Array[int] = []
	for session_id: int in chat_list_caches.cache_map:
		if session_id != AgentSessionManager.active_session_id:
			drop_ids.append(session_id)
	for session_id: int in drop_ids:
		clear_bubble_list(session_id)
	pass


func clear_all_bubble_lists() -> void:
	var drop_ids: Array[int] = []
	drop_ids.assign(chat_list_caches.cache_map.keys())
	for session_id: int in drop_ids:
		clear_bubble_list(session_id)
	pass


func get_active_chat_list() -> VBoxContainer:
	return chat_list_caches.get_value(AgentSessionManager.active_session_id) as VBoxContainer


# ---------------------------------------------------------------------------
# Bubbles
# ---------------------------------------------------------------------------

func append_entry_bubble(chat_entry: ChatEntry, session_id: int) -> RichTextLabel:
	var chat_list := chat_list_caches.get_value(session_id) as VBoxContainer
	if chat_list == null:
		return null
	return ChatBubbleFactory.append(chat_list, session_id, chat_entry)


## chat_entries index matches VBoxContainer child order; label lives on wrapper meta.
func get_bubble_rich_text(session_id: int, entry: ChatEntry) -> RichTextLabel:
	var session: AgentSession = AgentSessionStore.load_session(session_id)
	var list := chat_list_caches.get_value(session_id) as VBoxContainer
	if session == null or list == null:
		return null
	var index: int = session.chat_entries.find(entry)
	if index < 0 or index >= list.get_child_count():
		return null
	var wrapper: Node = list.get_child(index)
	return wrapper.get_meta(ChatBubbleFactory.META_BUBBLE_RICH_TEXT) as RichTextLabel


func refresh_error_resume_buttons() -> void:
	var active_chat_list: VBoxContainer = get_active_chat_list()
	if active_chat_list == null:
		return
	ErrorBubble.refresh_resume_buttons(active_chat_list, RuntimeManager.is_running(AgentSessionManager.active_session_id))
	pass
