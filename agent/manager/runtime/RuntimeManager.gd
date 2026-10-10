class_name RuntimeManager
extends Object

## Owns transient per-session state. Runtime data must never be persisted with session indexes.

static var runtimes: Dictionary[int, RuntimeState] = {}


static func start(session_id: int) -> RuntimeState:
	var runtime := RuntimeState.new()
	runtimes[session_id] = runtime
	return runtime


static func get_runtime(session_id: int) -> RuntimeState:
	return runtimes.get(session_id)


static func get_or_start(session_id: int) -> RuntimeState:
	var runtime := get_runtime(session_id)
	if runtime == null:
		runtime = start(session_id)
	return runtime


static func is_running(session_id: int) -> bool:
	return runtimes.has(session_id)


static func request_stop(session_id: int) -> void:
	var runtime := get_runtime(session_id)
	if runtime == null or runtime.stop_requested:
		return
	runtime.stop_requested = true
	runtime.cancel_scope.cancel()
	pass


static func is_stop_requested(session_id: int) -> bool:
	var runtime := get_runtime(session_id)
	return runtime == null or runtime.stop_requested


static func clear_step_entries(session_id: int) -> void:
	var runtime := get_runtime(session_id)
	if runtime == null:
		return
	runtime.step_thinking_entry = null
	runtime.step_agent_entry = null
	pass


static func stop(session_id: int) -> void:
	runtimes.erase(session_id)
	pass


static func clear() -> void:
	for runtime: RuntimeState in runtimes.values():
		runtime.cancel_scope.cancel()
	runtimes.clear()
	pass
