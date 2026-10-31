class_name ChatListCache
extends RefCounted

## Retains one transcript control tree per recently viewed session.

const MAX_SIZE: int = 18


var chat_lists: LruCacheInt = LruCacheInt.new(MAX_SIZE)


func has(session_id: int) -> bool:
	return chat_lists.has(session_id)


func get_list(session_id: int) -> VBoxContainer:
	return chat_lists.get_value(session_id) as VBoxContainer


## Returns the session transcript and makes it the only visible cached list.
func show(session_id: int, chat_lists_container: MarginContainer) -> VBoxContainer:
	var chat_list := get_list(session_id)
	if chat_list == null:
		chat_list = VBoxContainer.new()
		chat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chat_list.add_theme_constant_override("separation", Margin.ma_3)
		chat_lists_container.add_child(chat_list)
		var evicted_entry := chat_lists.put_if_absent(session_id, chat_list)
		if evicted_entry != null:
			var evicted_chat_list := evicted_entry.value as VBoxContainer
			dispose_chat_list(evicted_chat_list)
	for id: int in chat_lists.cache_map:
		var cached_chat_list := chat_lists.cache_map[id] as VBoxContainer
		cached_chat_list.visible = id == session_id
	return chat_list


func remove(session_id: int) -> void:
	var chat_list := chat_lists.remove(session_id) as VBoxContainer
	if chat_list != null:
		dispose_chat_list(chat_list)
	pass


func dispose_chat_list(chat_list: VBoxContainer) -> void:
	chat_list.hide()
	chat_list.queue_free()
	pass


func remove_all_except(session_id_to_keep: int) -> void:
	var drop_ids: Array[int] = []
	for session_id: int in chat_lists.cache_map:
		if session_id != session_id_to_keep:
			drop_ids.append(session_id)
	for session_id: int in drop_ids:
		remove(session_id)
	pass


func clear_all() -> void:
	var drop_ids: Array[int] = []
	drop_ids.assign(chat_lists.cache_map.keys())
	for session_id: int in drop_ids:
		remove(session_id)
	pass


func append_entry(session_id: int, entry: ChatEntry) -> BubbleContainer:
	var chat_list := get_list(session_id)
	if chat_list == null:
		return null
	return ChatBubbleFactory.append(chat_list, session_id, entry)


## Removes only the affected bubbles so long transcripts do not need to be rebuilt.
func remove_entries(session_id: int, entry_idx: int, delete_from_here: bool) -> void:
	var chat_list := get_list(session_id)
	if chat_list == null or entry_idx < 0 or entry_idx >= chat_list.get_child_count():
		return
	var last_idx := chat_list.get_child_count() - 1 if delete_from_here else entry_idx
	for index in range(last_idx, entry_idx - 1, -1):
		var bubble := chat_list.get_child(index)
		chat_list.remove_child(bubble)
		bubble.queue_free()
	pass


## chat_entries index matches VBoxContainer child order.
func get_bubble(session_id: int, entry: ChatEntry) -> BubbleContainer:
	var session: AgentSession = AgentSessionStore.load_session(session_id)
	var chat_list := get_list(session_id)
	if session == null or chat_list == null:
		return null
	var index: int = session.chat_entries.find(entry)
	if index < 0 or index >= chat_list.get_child_count():
		return null
	return chat_list.get_child(index) as BubbleContainer
