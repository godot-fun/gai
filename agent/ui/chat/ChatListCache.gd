class_name ChatListCache
extends RefCounted

## Retains one transcript control tree per recently viewed session.

const MAX_SIZE: int = 18


var lists: LruCacheInt = LruCacheInt.new(MAX_SIZE)


func has(session_id: int) -> bool:
	return lists.has(session_id)


func get_list(session_id: int) -> VBoxContainer:
	return lists.get_value(session_id) as VBoxContainer


## Returns the session transcript and makes it the only visible cached list.
func show(session_id: int, chat_list: MarginContainer) -> VBoxContainer:
	var list := get_list(session_id)
	if list == null:
		list = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", Margin.ma_3)
		chat_list.add_child(list)
		var evicted_entry := lists.put_if_absent(session_id, list)
		if evicted_entry != null:
			var evicted_list := evicted_entry.value as VBoxContainer
			dispose_list(evicted_list)
	for id: int in lists.cache_map:
		var cached_list := lists.cache_map[id] as VBoxContainer
		cached_list.visible = id == session_id
	return list


func remove(session_id: int) -> void:
	var list := lists.remove(session_id) as VBoxContainer
	if list != null:
		dispose_list(list)
	pass


func dispose_list(list: VBoxContainer) -> void:
	list.hide()
	list.queue_free()
	pass


func remove_all_except(session_id_to_keep: int) -> void:
	var drop_ids: Array[int] = []
	for session_id: int in lists.cache_map:
		if session_id != session_id_to_keep:
			drop_ids.append(session_id)
	for session_id: int in drop_ids:
		remove(session_id)
	pass


func clear_all() -> void:
	var drop_ids: Array[int] = []
	drop_ids.assign(lists.cache_map.keys())
	for session_id: int in drop_ids:
		remove(session_id)
	pass


func append_entry(session_id: int, entry: ChatEntry) -> BubbleContainer:
	var list := get_list(session_id)
	if list == null:
		return null
	return ChatBubbleFactory.append(list, session_id, entry)


## chat_entries index matches VBoxContainer child order.
func get_bubble(session_id: int, entry: ChatEntry) -> BubbleContainer:
	var session: AgentSession = AgentSessionStore.load_session(session_id)
	var list := get_list(session_id)
	if session == null or list == null:
		return null
	var index: int = session.chat_entries.find(entry)
	if index < 0 or index >= list.get_child_count():
		return null
	return list.get_child(index) as BubbleContainer
