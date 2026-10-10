class_name AgentSessionIndexes
extends RefCounted

## Persists the session list as `index.gai` under the workspace `.agent/sessions/` folder.

const INDEX_FILE := "index.gai"

var pinned_indexes: Array[SessionIndex] = []
var indexes: Array[SessionIndex] = []

class RunState:
	var stop_requested: bool = false
	var step_thinking_entry: ChatEntry = null
	var step_agent_entry: ChatEntry = null
	pass


class SessionIndex:
	var id: int = -1
	var title: String = ""
	## Active run state; null when idle.
	var run: RunState = null


	func is_running() -> bool:
		return run != null


	func stop_running() -> void:
		run = null
		pass


	func clear_run_state() -> void:
		if run == null:
			return
		run.step_thinking_entry = null
		run.step_agent_entry = null
		pass


	func is_stop_requested() -> bool:
		return run != null and run.stop_requested


static func get_index_path() -> String:
	return AgentSessionStore.get_sessions_dir().path_join(INDEX_FILE)


static func load_index() -> AgentSessionIndexes:
	var text := FileUtils.read_file_to_string(get_index_path())
	if StringUtils.is_not_blank(text):
		var session_indexes: AgentSessionIndexes = JsonUtils.json_to_object(text, AgentSessionIndexes)
		if session_indexes != null:
			for list: Array[SessionIndex] in [session_indexes.pinned_indexes, session_indexes.indexes]:
				for session_index: SessionIndex in list:
					session_index.run = null
			return session_indexes
	return AgentSessionIndexes.new()


static func save_index(session_indexes: AgentSessionIndexes) -> void:
	var json := JsonUtils.object_to_json(session_indexes)
	FileUtils.write_string_to_file(get_index_path(), json)
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
