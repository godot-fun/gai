class_name FileLogger
extends Logger

var mutex: Mutex = Mutex.new()
var log_file: FileAccess = FileAccess.open(LoggerHelper.LOG_FILE_PATH, FileAccess.WRITE_READ)

func _init() -> void:
	log_file.seek_end()
	gdf.events.application_exit.connect(flush)
	pass

func append_line(line: String, flush_immediately: bool = false) -> void:
	mutex.lock()

	log_file.store_string(line)
	if flush_immediately:
		log_file.flush()

	mutex.unlock()
	pass

func flush() -> void:
	mutex.lock()
	log_file.flush()
	mutex.unlock()
	pass

# Logger-Interface-Implement-Start
func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	append_line(LoggerHelper.log_format_error_message(function, file, line, code, rationale, editor_notify, error_type, script_backtraces), true)
	pass


func _log_message(message: String, error: bool) -> void:
	append_line(message, error)
	pass
# Logger-Interface-Implement-End
