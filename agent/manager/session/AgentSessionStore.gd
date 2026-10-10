class_name AgentSessionStore
extends RefCounted

## Persists agent chat sessions as JSON files under the workspace `.agent/sessions/` folder.

const SESSIONS_SUBDIR := ".gai/sessions"
const FILE_SUFFIX := ".gai"

# Dictionary[int, AgentSession]
static var sessions: ConcurrentMapInt = ConcurrentMapInt.new()


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

static func get_sessions_dir() -> String:
	return AgentWorkspace.get_root().path_join(SESSIONS_SUBDIR)


static func get_session_path(session_id: int) -> String:
	return get_sessions_dir().path_join(str(session_id) + FILE_SUFFIX)


static func ensure_sessions_dir() -> bool:
	var dir_path := get_sessions_dir()
	if DirAccess.dir_exists_absolute(dir_path):
		return true
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	return err == OK


# ---------------------------------------------------------------------------
# Create
# ---------------------------------------------------------------------------

static func create_session() -> AgentSession:
	var session_id := IdUtils.short_uuid()
	var session := AgentSession.new(session_id)
	sessions.put(session.id, session)
	return session

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

static func save_session(session_id: int) -> void:
	var session: AgentSession = load_session(session_id)
	if session == null:
		return
	if not ensure_sessions_dir():
		Log.error("agent chat save failed, cannot create dir:[{}]", get_sessions_dir())
		return
	var json := JsonUtils.object_to_json(session)
	FileUtils.write_string_to_file(get_session_path(session.id), json)
	pass


static func delete_session(session_id: int) -> void:
	if session_id < 0:
		return
	sessions.remove(session_id)
	FileUtils.delete_file_or_directory(get_session_path(session_id))
	pass


# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------



static func load_session(session_id: int) -> AgentSession:
	var session := sessions.get_value(session_id) as AgentSession
	if session != null:
		return session
	session = load_session_file(get_session_path(session_id))
	if session != null:
		var existing := sessions.put_if_absent(session_id, session) as AgentSession
		if existing != null:
			return existing
	return session


## Warm-up loader — loads the leading [param max_count] sessions of the sidebar index on a worker
## thread, so file IO and JSON parsing stay off the main thread. [param max_count] of 0 (the default)
## loads every indexed session. [method load_session] returns sessions already in memory as-is, so
## repeating the call is cheap. Returns once the worker has finished.
static func async_load_sessions(max_count: int = 0) -> void:
	var session_indexes := AgentSessionManager.session_indexes
	# Cache holds as many sessions as the index — everything is loaded, so no worker is needed.
	if session_indexes.size() == sessions.size():
		return
	var session_ids := session_indexes.collect_session_ids(max_count)
	if session_ids.is_empty():
		return
	var task_id := WorkerThreadPool.add_task(func() -> void: load_sessions(session_ids))
	while not WorkerThreadPool.is_task_completed(task_id):
		await Engine.get_main_loop().process_frame
	WorkerThreadPool.wait_for_task_completion(task_id)
	pass


## Worker body — loads [param session_ids] one after another on the calling thread.
static func load_sessions(session_ids: Array[int]) -> void:
	for session_id: int in session_ids:
		load_session(session_id)
	pass


static func load_session_file(file_path: String) -> AgentSession:
	var text := FileUtils.read_file_to_string(file_path)
	if StringUtils.is_blank(text):
		return null
	var session: AgentSession = JsonUtils.json_to_object(text, AgentSession)
	if session == null:
		Log.error("agent chat load failed, invalid json:[{}]", file_path)
		return null
	session.id = int(file_path.get_file().trim_suffix(FILE_SUFFIX))
	return session
