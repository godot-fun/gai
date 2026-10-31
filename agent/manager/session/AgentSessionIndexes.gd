class_name AgentSessionIndexes
extends RefCounted

## Persists the session list as `index.gai` under the workspace `.agent/sessions/` folder.

const INDEX_FILE := "index.gai"

var pinned_indexes: Array[SessionIndex] = []
var indexes: Array[SessionIndex] = []

class SessionIndex:
	var id: int = -1
	var title: String = ""

	# -----------------------------------------------------------------------
	# Deep clone
	# -----------------------------------------------------------------------

	func deep_clone() -> SessionIndex:
		var cloned := SessionIndex.new()
		cloned.id = id
		cloned.title = title
		return cloned

	pass


# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

## Indexed session count — pinned entries plus the normal list.
func size() -> int:
	return pinned_indexes.size() + indexes.size()


## Session ids in sidebar order — pinned entries first, then the normal list.
## [param max_count] of 0 (the default) returns every id, otherwise the leading [param max_count] ids.
func collect_session_ids(max_count: int = 0) -> Array[int]:
	var session_ids: Array[int] = []
	for list: Array[SessionIndex] in [pinned_indexes, indexes]:
		for session_index: SessionIndex in list:
			if max_count > 0 and session_ids.size() >= max_count:
				return session_ids
			session_ids.append(session_index.id)
	return session_ids


# ---------------------------------------------------------------------------
# Deep clone
# ---------------------------------------------------------------------------

func deep_clone() -> AgentSessionIndexes:
	var cloned := AgentSessionIndexes.new()
	cloned.pinned_indexes.resize(pinned_indexes.size())
	for index in pinned_indexes.size():
		if pinned_indexes[index] == null:
			continue
		cloned.pinned_indexes[index] = pinned_indexes[index].deep_clone()
	cloned.indexes.resize(indexes.size())
	for index in indexes.size():
		if indexes[index] == null:
			continue
		cloned.indexes[index] = indexes[index].deep_clone()
	return cloned


# ---------------------------------------------------------------------------
# Static methods
# ---------------------------------------------------------------------------

static func get_index_path() -> String:
	return AgentSessionStore.get_sessions_dir().path_join(INDEX_FILE)


static func load_index() -> AgentSessionIndexes:
	var text := FileUtils.read_file_to_string(get_index_path())
	if StringUtils.is_not_blank(text):
		var session_indexes: AgentSessionIndexes = JsonUtils.json_to_object(text, AgentSessionIndexes)
		if session_indexes != null:
			return session_indexes
	return AgentSessionIndexes.new()


static func save_index(session_indexes: AgentSessionIndexes) -> void:
	var snapshot := session_indexes.deep_clone()
	var index_path := get_index_path()
	ExecutorHelper.execute(func() -> void:
		var json := JsonUtils.object_to_json(snapshot)
		var write_error := FileUtils.write_string_to_file(index_path, json)
		if write_error != OK:
			Log.error("agent session index save failed error:[{}]", error_string(write_error))
	)
	pass
