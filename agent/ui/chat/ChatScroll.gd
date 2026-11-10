class_name ChatScroll
extends RefCounted

## Owns chat-history scrolling, per-session positions, search reveals, and bottom following.

var chat_scroll: ScrollContainer
var active_chat_list: VBoxContainer
var scroll_position_caches: Dictionary[int, float] = {}
## When true, new content keeps the chat history scrolled to the latest bubble.
var stick_to_bottom: bool = true
var scroll_to_bottom_queued: bool = false
var search_target_session_id: int = 0
var search_target_entry_index: int = -1
var middle_scroll_controller: MiddleScrollController


func setup(p_chat_scroll: ScrollContainer) -> void:
	chat_scroll = p_chat_scroll
	SchedulerBus.schedule_at_fixed_rate(queue_scroll_to_bottom, 1000, "agent_chat_stick_to_bottom")
	chat_scroll.gui_input.connect(on_chat_scroll_gui_input)
	# The bar swallows wheel/drag events before the container sees them.
	chat_scroll.get_v_scroll_bar().scrolling.connect(on_chat_scroll_bar_scrolling)
	chat_scroll.get_window().window_input.connect(on_chat_window_input)
	AgentEvents.events.chat_bubble_flushed.connect(on_chat_bubble_flushed)
	AgentEvents.events.chat_search_result_selected.connect(on_chat_search_result_selected)
	AgentEvents.events.middle_scroll_started.connect(func() -> void: stick_to_bottom = false)
	AgentEvents.events.middle_scroll_ended.connect(func(at_bottom: bool) -> void: stick_to_bottom = at_bottom)
	middle_scroll_controller = MiddleScrollController.new()
	chat_scroll.get_parent().add_child(middle_scroll_controller)
	middle_scroll_controller.setup(chat_scroll)
	pass


func on_chat_bubble_flushed() -> void:
	queue_scroll_to_bottom()
	pass


func on_chat_search_result_selected(session_id: int, entry_index: int) -> void:
	reveal_search_result(session_id, entry_index)
	pass


func set_active_chat_list(chat_list: VBoxContainer) -> void:
	middle_scroll_controller.cancel()
	active_chat_list = chat_list
	pass


func remove_session(session_id: int) -> void:
	scroll_position_caches.erase(session_id)
	pass


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


func has_cached_session_scroll(session_id: int) -> bool:
	return scroll_position_caches.has(session_id)


## Reveals the persisted entry selected by chat search after the target session is visible.
func reveal_search_result(session_id: int, entry_index: int) -> void:
	if not AgentSessionManager.is_active(session_id):
		return
	search_target_session_id = session_id
	search_target_entry_index = entry_index
	stick_to_bottom = false
	reveal_entry_after_layout(session_id, entry_index)
	pass


## A newly opened chat list needs two layout passes before RichTextLabel heights and the
## ScrollContainer range are final. Waiting here also lets any queued bottom-scroll abort.
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
	if not is_instance_valid(active_chat_list) or entry_index < 0 or entry_index >= active_chat_list.get_child_count():
		return
	var entry_control := active_chat_list.get_child(entry_index) as Control
	var vbar := chat_scroll.get_v_scroll_bar()
	if entry_control == null or vbar == null:
		return
	# The bar value is expressed in ChatListsContainer content coordinates. The list starts after
	# ChatListsContainer's top inset, and each entry position is local to the list.
	var entry_y := entry_y_for_control(entry_control)
	var max_scroll := maxf(vbar.min_value, vbar.max_value - vbar.page)
	vbar.value = clampf(entry_y - Margin.ma_5, vbar.min_value, max_scroll)
	if entry_control is BubbleContainer:
		(entry_control as BubbleContainer).flash_highlight()
	pass


func navigate_user_message(direction: int) -> bool:
	return navigate_entry_kind(ChatEntry.KIND_USER, direction)


func navigate_reply(direction: int) -> bool:
	return navigate_entry_kind(ChatEntry.KIND_AGENT, direction)


func navigate_entry_kind(entry_kind: String, direction: int) -> bool:
	if direction == 0 or not is_instance_valid(active_chat_list):
		return false
	var session: AgentSession = AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	if session == null:
		return false
	var entry_indices := collect_entry_indices(session, entry_kind)
	if entry_indices.is_empty():
		return false
	var target_index := find_entry_nav_index(entry_indices, direction)
	if target_index < 0:
		return false
	stick_to_bottom = false
	reveal_entry(target_index)
	cache_session_scroll(AgentSessionManager.active_session_id)
	return true


func collect_entry_indices(session: AgentSession, entry_kind: String) -> Array[int]:
	var indices: Array[int] = []
	for entry_index in range(session.chat_entries.size()):
		if session.chat_entries[entry_index].kind == entry_kind:
			indices.append(entry_index)
	return indices


func find_entry_nav_index(entry_indices: Array[int], direction: int) -> int:
	var vbar: VScrollBar = chat_scroll.get_v_scroll_bar()
	if vbar == null:
		return -1
	var anchor := vbar.value + Margin.ma_5
	var current_slot := -1
	for slot in range(entry_indices.size()):
		var entry_index: int = entry_indices[slot]
		if entry_y_for_index(entry_index) <= anchor + 1.0:
			current_slot = slot
	if direction > 0:
		var next_slot := current_slot + 1
		if next_slot >= entry_indices.size():
			next_slot = entry_indices.size() - 1
		return entry_indices[next_slot]
	if current_slot <= 0:
		return entry_indices[0]
	return entry_indices[current_slot - 1]


func entry_y_for_index(entry_index: int) -> float:
	if not is_instance_valid(active_chat_list) or entry_index < 0 or entry_index >= active_chat_list.get_child_count():
		return 0.0
	var entry_control := active_chat_list.get_child(entry_index) as Control
	if entry_control == null:
		return 0.0
	return entry_y_for_control(entry_control)


func entry_y_for_control(entry_control: Control) -> float:
	return active_chat_list.position.y + entry_control.position.y


func on_chat_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if try_wheel_entry_navigate(mouse):
			chat_scroll.accept_event()
			return
		if not mouse.pressed:
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			stick_to_bottom = false
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and is_scrolled_to_bottom():
			# Wheel scrolled all the way down — re-enable follow so new
			# content automatically keeps the chat history at the bottom.
			stick_to_bottom = true
	elif event is InputEventPanGesture:
		stick_to_bottom = is_scrolled_to_bottom()
	pass


func try_wheel_entry_navigate(mouse: InputEventMouseButton) -> bool:
	if not mouse.pressed or (not mouse.ctrl_pressed and not mouse.meta_pressed):
		return false
	var direction := wheel_direction(mouse)
	if direction == 0:
		return false
	if mouse.shift_pressed:
		return navigate_reply(direction)
	return navigate_user_message(direction)
	pass


static func wheel_direction(mouse: InputEventMouseButton) -> int:
	if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
		return -1
	if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		return 1
	return 0


## Dragging the scrollbar grabber (or wheeling over the bar itself) reads history
## instead of following the stream — follow resumes at the bottom edge.
func on_chat_scroll_bar_scrolling() -> void:
	stick_to_bottom = is_scrolled_to_bottom()
	pass


func can_route_window_input() -> bool:
	if not is_instance_valid(chat_scroll) or not chat_scroll.is_inside_tree():
		return false
	if has_visible_embedded_window():
		return false
	return chat_scroll.get_window().has_focus()


## Binding matched — consume the key even when there is nothing to jump to (avoids Page Up/Down fallthrough).
func try_entry_nav_shortcut(key: InputEventKey, binding: Key, entry_kind: String, direction: int) -> bool:
	if key.echo or key.get_keycode_with_modifiers() != binding:
		return false
	if navigate_entry_kind(entry_kind, direction):
		chat_scroll.get_viewport().set_input_as_handled()
	return true


func has_visible_embedded_window() -> bool:
	for window: Window in chat_scroll.get_tree().root.get_embedded_subwindows():
		if window.visible:
			return true
	return false


## Page keys belong to the focused TextEdit by default; route Godot's native page
## actions to the chat history so they work while composing a message.
func on_chat_window_input(event: InputEvent) -> void:
	if not can_route_window_input() or not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed:
		return
	if try_entry_nav_shortcut(key, ShortcutSetting.get_prev_user_message_shortcut(), ChatEntry.KIND_USER, -1):
		return
	if try_entry_nav_shortcut(key, ShortcutSetting.get_next_user_message_shortcut(), ChatEntry.KIND_USER, 1):
		return
	if try_entry_nav_shortcut(key, ShortcutSetting.get_prev_reply_shortcut(), ChatEntry.KIND_AGENT, -1):
		return
	if try_entry_nav_shortcut(key, ShortcutSetting.get_next_reply_shortcut(), ChatEntry.KIND_AGENT, 1):
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


## True when the chat history is already scrolled to (or within a pixel of) the bottom edge.
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


## The list lives inside ChatListsContainer, so the last bubble counts as "visible" while the
## bar still owes the bottom margin — ensure_control_visible() stops one margin short.
## Drive the bar to its own bottom edge so the chat history ends flush with the view.
func flush_scroll_to_bottom() -> void:
	scroll_to_bottom_queued = false
	if not stick_to_bottom:
		return
	if not is_instance_valid(active_chat_list) or not active_chat_list.visible:
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
