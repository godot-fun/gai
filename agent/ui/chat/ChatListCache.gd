class_name ChatListCache
extends RefCounted

## Retains one transcript control tree per recently viewed session.

const MAX_SIZE: int = 18


var host: Control
var lists: LruCacheInt = LruCacheInt.new(MAX_SIZE)
var active_session_id: int = 0


func setup(p_host: Control) -> void:
	host = p_host
	pass


func has(session_id: int) -> bool:
	return lists.has(session_id)


func get_list(session_id: int) -> VBoxContainer:
	return lists.get_value(session_id) as VBoxContainer


func get_or_create(session_id: int) -> VBoxContainer:
	var list := get_list(session_id)
	if list != null:
		return list
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", Margin.ma_3)
	host.add_child(list)
	var evicted_entry := lists.put_if_absent(session_id, list)
	if evicted_entry != null:
		var evicted_list := evicted_entry.value as VBoxContainer
		dispose_list(evicted_entry.key, evicted_list)
	return list


func show_only(session_id: int) -> void:
	active_session_id = session_id
	for id: int in lists.cache_map:
		var list := lists.cache_map[id] as VBoxContainer
		list.visible = id == session_id
	pass


func remove(session_id: int) -> void:
	var list := lists.remove(session_id) as VBoxContainer
	if list != null:
		dispose_list(session_id, list)
	pass


func dispose_list(session_id: int, list: VBoxContainer) -> void:
	if active_session_id == session_id:
		active_session_id = 0
	AgentEvents.events.chat_list_removed.emit(list)
	list.queue_free()
	pass


func clear_inactive() -> void:
	var drop_ids: Array[int] = []
	for session_id: int in lists.cache_map:
		if session_id != active_session_id:
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


func get_active_list() -> VBoxContainer:
	return get_list(active_session_id)


func append_entry(session_id: int, entry: ChatEntry) -> RichTextLabel:
	var list := get_list(session_id)
	if list == null:
		return null
	return ChatBubbleFactory.append(list, session_id, entry)


## chat_entries index matches VBoxContainer child order; label lives on wrapper meta.
func get_rich_text(session_id: int, entry: ChatEntry) -> RichTextLabel:
	var session: AgentSession = AgentSessionStore.load_session(session_id)
	var list := get_list(session_id)
	if session == null or list == null:
		return null
	var index: int = session.chat_entries.find(entry)
	if index < 0 or index >= list.get_child_count():
		return null
	var wrapper: Node = list.get_child(index)
	return wrapper.get_meta(ChatBubbleFactory.META_BUBBLE_RICH_TEXT) as RichTextLabel
