class_name OSUtils
extends Object

## Subprocess execution. Sync `execute` uses OS.execute; async `async_execute`
## uses OS.execute_with_pipe on a worker thread and expects UTF-8 output.
## Output chunks append to ExecResult.output. Pass `log=false` to silence logs.
## `async_execute` accepts `timeout_millis`, defaulting to one hour; a process that exceeds it is
## killed, appends a `[timeout]` line to ExecResult.output and returns EXIT_CODE_TIMEOUT.

const EXIT_CODE_NOT_STARTED: int = -1
const EXIT_CODE_TIMEOUT: int = -2

static var process_pids: RingListInt = RingListInt.new(32)

# ----------------------------------------------------------------------------------------------------------------------
# Execution result
class ExecResult:
	var exit_code: int = -1
	var output: StringBuilder = StringBuilder.new()


# ----------------------------------------------------------------------------------------------------------------------
# Public execution API
static func execute(argv: PackedStringArray, log: bool = true) -> ExecResult:
	var result := ExecResult.new()
	if argv.is_empty():
		return result

	if log:
		Log.info("execute command:{}", JSON.stringify(argv))

	var lines: Array = []
	result.exit_code = OS.execute(argv[0], argv.slice(1), lines, true)
	var builder := StringBuilder.new()
	for line in lines:
		builder.append(str(line))
	append_output(result, builder.build_joined(FileUtils.NEWLINE_LF))
	log_result(argv, result, log)
	return result


static func async_execute(argv: PackedStringArray, log: bool = true, timeout_millis: int = TimeUtils.MILLIS_PER_HOUR) -> ExecResult:
	var result := ExecResult.new()
	if argv.is_empty():
		return result

	if log:
		Log.info("async_execute command:{}", JSON.stringify(argv))

	var thread := Thread.new()
	thread.start(_run_process_async.bind(argv, result, timeout_millis))
	while thread.is_alive():
		await Engine.get_main_loop().process_frame
	thread.wait_to_finish()
	log_result(argv, result, log)
	return result


# ----------------------------------------------------------------------------------------------------------------------
# Process lifecycle and async worker
static func stop_last() -> void:
	kill_process(process_pids.latest(), 0)
	pass


static func stop_all() -> void:
	for pid in process_pids.to_array():
		kill_process(pid, 0)
	process_pids.clear()
	pass


## Kills pid and returns the OS.kill error code, logged when the kill fails; a finished or unknown pid is a no-op.
## wait_millis is the grace period for the process to exit, so the pipe tail can still be read after the kill;
## pass 0 from the main thread (stop_last/stop_all) to stay non blocking. Returns FAILED when the process survives it.
static func kill_process(pid: int, wait_millis: int = 1000) -> int:
	if pid <= 0 or not OS.is_process_running(pid):
		return OK
	var err := OS.kill(pid)
	if err != OK:
		Log.error("kill process failed pid:[{}] err:[{}]", pid, err)
		return err
	if wait_millis <= 0:
		return OK
	var deadline := Time.get_ticks_msec() + wait_millis
	while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(16)
	if OS.is_process_running(pid):
		Log.error("kill process failed pid:[{}] err:[{}]", pid, FAILED)
		return FAILED
	return OK


static func _run_process_async(argv: PackedStringArray, result: ExecResult, timeout_millis: int = TimeUtils.MILLIS_PER_HOUR) -> void:
	var proc := OS.execute_with_pipe(argv[0], argv.slice(1), false)
	if proc.is_empty():
		result.exit_code = EXIT_CODE_NOT_STARTED
		return

	var pid: int = int(proc.get("pid", -1))
	if pid > 0:
		process_pids.add(pid)
	var stdio: FileAccess = proc.get("stdio")
	var stderr_pipe: FileAccess = proc.get("stderr")
	var stdout_decoder := Utf8StreamDecoder.new()
	var stderr_decoder := Utf8StreamDecoder.new()
	var deadline := Time.get_ticks_msec() + timeout_millis
	var timed_out := false

	while pid > 0 and OS.is_process_running(pid):
		drain_pipe(result, stdio, false, stdout_decoder)
		drain_pipe(result, stderr_pipe, false, stderr_decoder)
		if Time.get_ticks_msec() >= deadline:
			timed_out = true
			kill_process(pid)
			break
		OS.delay_msec(16)

	drain_pipe(result, stdio, true, stdout_decoder)
	drain_pipe(result, stderr_pipe, true, stderr_decoder)
	close_pipe(stdio)
	close_pipe(stderr_pipe)

	if timed_out:
		# Marks the timeout inside the captured output, on its own line when there is output already.
		var prefix := FileUtils.NEWLINE_LF if not result.output.is_empty() else StringUtils.EMPTY
		append_output(result, prefix + StringUtils.format("[timeout] process killed after {} ms", timeout_millis))
		result.exit_code = EXIT_CODE_TIMEOUT
	elif pid > 0:
		result.exit_code = OS.get_process_exit_code(pid)
	else:
		result.exit_code = EXIT_CODE_NOT_STARTED
	if pid > 0:
		process_pids.remove_value(pid)
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Pipe decoding and output collection
static func drain_pipe(result: ExecResult, pipe: FileAccess, final: bool, utf8_decoder: Utf8StreamDecoder) -> void:
	if pipe == null or not pipe.is_open():
		return

	while true:
		var chunk := pipe.get_buffer(4096)
		var err := pipe.get_error()
		if chunk.is_empty():
			if final or err != OK:
				break
			return

		append_output(result, utf8_decoder.push(chunk))
		if err != OK:
			break
	if final and utf8_decoder != null:
		append_output(result, utf8_decoder.flush())
	pass


static func append_output(result: ExecResult, text: String) -> void:
	if StringUtils.is_empty(text):
		return
	result.output.append(text)
	pass


static func close_pipe(pipe: FileAccess) -> void:
	if pipe != null and pipe.is_open():
		pipe.close()
	pass


# ----------------------------------------------------------------------------------------------------------------------
static func log_result(argv: PackedStringArray, result: ExecResult, log: bool) -> void:
	if not log or argv.is_empty():
		return
	var output := result.output.build_string()
	if not output.is_empty():
		Log.info("process output:[{}]", output)
	if result.exit_code == EXIT_CODE_TIMEOUT:
		Log.error("process timed out command:{}", JSON.stringify(argv))
		return
	if result.exit_code == 0:
		Log.info("process finished exit:[{}]", result.exit_code)
		return
	Log.error("process failed exit:[{}] command:{}", result.exit_code, JSON.stringify(argv))
	if result.exit_code < 0:
		Log.error("failed to start process; check runtime exists:[{}]", argv[0])
		return
	if output.is_empty():
		Log.error("no process output")
	pass

static func is_windows() -> bool:
	return OS.get_name().strip_edges().to_lower() == "windows"


static func is_mac() -> bool:
	return OS.get_name().strip_edges().to_lower() == "macos"


static func is_linux() -> bool:
	return OS.get_name().strip_edges().to_lower() == "linux"


static func godot_version() -> String:
	var version_info := Engine.get_version_info()
	var version_text := str(version_info.get("string", ""))
	if StringUtils.is_not_blank(version_text):
		return version_text
	return StringUtils.format("{}.{}.{}", version_info.get("major", 0), version_info.get("minor", 0), version_info.get("patch", 0))

static func build_shell_argv(command: String) -> PackedStringArray:
	if is_windows():
		return PackedStringArray(["cmd.exe", "/c", "chcp 65001 >nul && " + command])
	return PackedStringArray(["/bin/sh", "-c", command])


# ----------------------------------------------------------------------------------------------------------------------
## Splits a command line into argv without any shell: quotes group one argument and are dropped,
## spaces and tabs separate arguments. Empty quoted arguments are ignored.
## Example: split_command_line("git --git-dir \"C:/a b\" add -A") -> ["git", "--git-dir", "C:/a b", "add", "-A"]
static func split_command_line(command: String) -> PackedStringArray:
	const QUOTES: PackedStringArray = ["\"", "'"]

	var argv := PackedStringArray()
	var current := StringUtils.EMPTY
	var quote := StringUtils.EMPTY
	for index in command.length():
		var character := command[index]
		if quote.is_empty():
			if QUOTES.has(character):
				quote = character
				continue
			if character == StringUtils.SPACE or character == StringUtils.TAB_ASCII:
				if not current.is_empty():
					argv.append(current)
					current = StringUtils.EMPTY
				continue
		elif character == quote:
			quote = StringUtils.EMPTY
			continue
		current += character
	if not current.is_empty():
		argv.append(current)
	return argv
