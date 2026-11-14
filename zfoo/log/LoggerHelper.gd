class_name LoggerHelper
extends Object

static var LOG_FILE_PATH: String = OS.get_user_data_dir() + "/logs/godot.log"

static func init() -> void:
	if OS.is_debug_build():
		OS.add_logger(ConsoleLogger.new())
	else:
		OS.add_logger(FileLogger.new())
	# Reported in both builds so the resolved location is visible at startup.
	Log.info("log file:[{}]", LOG_FILE_PATH)
	pass


@warning_ignore("unused_parameter")
static func log_format_error_message(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> String:
	# Match Godot console-like format as much as possible.
	var first_line := ""
	if !StringUtils.is_blank(code):
		first_line = StringUtils.format("{} [ERROR] - Caused by: {}", TimeUtils.date(), code)
	elif !StringUtils.is_blank(rationale):
		first_line = StringUtils.format("{} [ERROR] - Caused by: {}", TimeUtils.date(), rationale)
	else:
		first_line = StringUtils.format("{} [ERROR] - (no details)", TimeUtils.date())

	var builder := StringBuilder.new()
	builder.append(first_line)
	if script_backtraces != null and script_backtraces.size() > 0:
		for bt in script_backtraces:
			var part := str(bt)
			if StringUtils.is_blank(part):
				continue
			builder.append(StringUtils.format("at {}", part))
	gdf.events.log_error.emit()
	return builder.build_joined(FileUtils.NEWLINE_LF)



static func tail_log(line_count: int = 128) -> String:
	const CHUNK_SIZE := 4096

	if not FileAccess.file_exists(LOG_FILE_PATH):
		return StringUtils.format("Log file not found:[{}]", LOG_FILE_PATH)

	var file := FileAccess.open(LOG_FILE_PATH, FileAccess.READ)
	if file == null:
		return StringUtils.format("Failed to open log file:[{}]", LOG_FILE_PATH)

	var file_len := file.get_length()
	var pos := file_len
	var chunks: Array[String] = []
	var newlines := 0

	while pos > 0 and newlines <= line_count:
		var start := maxi(0, pos - CHUNK_SIZE)
		var read_len := pos - start
		file.seek(start)
		var bytes := file.get_buffer(read_len)
		var chunk := bytes.get_string_from_utf8()
		chunks.append(chunk)
		newlines += chunk.count(FileUtils.NEWLINE_LF) + chunk.count(FileUtils.NEWLINE_CR)
		pos = start

	file.close()

	chunks.reverse()
	var builder := StringBuilder.new()
	for chunk: String in chunks:
		builder.append(chunk)
	var collected := FileUtils.normalize_line_endings_to_lf(builder.build_string())
	var lines := collected.split(FileUtils.NEWLINE_LF, false)
	if lines.size() > line_count:
		lines = lines.slice(lines.size() - line_count, lines.size())

	var tail_text := FileUtils.NEWLINE_LF.join(lines)
	return tail_text
