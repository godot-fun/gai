class_name BashProcessManager
extends RefCounted

## Owns Bash processes that may outlive one tool call.
## The worker thread continuously drains stdout/stderr to prevent pipe backpressure, while
## [method async_poll] returns and clears only the output accumulated since the previous poll.

static var processes: Dictionary[String, BashProcess] = {}


static func _static_init() -> void:
	gdf.events.application_end.connect(stop_all)
	pass

static func build_argv(command: String) -> PackedStringArray:
	var bash := "/bin/bash"
	if OSUtils.is_windows():
		bash = GitHelper.find_windows_git_bash()
	var working_directory := AgentWorkspace.get_root()
	var bash_command := StringUtils.format("cd -- '{}' && {}", working_directory, command)
	if OSUtils.is_windows():
		var encoded_command := Marshalls.raw_to_base64(command.to_utf8_buffer())
		bash_command = StringUtils.format("cd -- '{}' && /bin/bash --noprofile --norc <(printf %s {} | /usr/bin/base64 --decode)", working_directory, encoded_command)
	return PackedStringArray([bash, "--noprofile", "--norc", "-c", bash_command])


static func start(command: String, cancel_scope: CancelScope = null) -> String:
	var process := BashProcess.new()
	process.id = StringUtils.format("bash_{}", IdUtils.local_id())
	process.argv = build_argv(command)
	processes[process.id] = process
	if cancel_scope != null:
		cancel_scope.track(kill.bind(process.id))
	var err := process.thread.start(run_process.bind(process))
	if err != OK:
		append_output(process, StringUtils.format("failed to start Bash process thread: {}", err))
		finish(process, OSUtils.EXIT_CODE_NOT_STARTED)
	return process.id


static func stop_all() -> void:
	var active := processes.values()
	for process: BashProcess in active:
		kill(process.id)
	for process: BashProcess in active:
		if process.thread.is_started():
			process.thread.wait_to_finish()
	processes.clear()
	pass


static func async_poll(process_id: String, wait_millis: int = TimeUtils.MILLIS_PER_SECOND * 30) -> BashProcessResult:
	# Wait only for the requested duration. A poll timeout does not stop the background process.
	var deadline := Time.get_ticks_msec() + wait_millis
	while is_running(process_id) and Time.get_ticks_msec() < deadline:
		await Engine.get_main_loop().process_frame
	var process: BashProcess = processes.get(process_id)
	if process == null:
		return BashProcessResult.new(BashProcessResult.STATUS_NOT_FOUND, process_id, OSUtils.EXIT_CODE_NOT_STARTED, "")
	# Join a finished worker so its thread handle is released before returning the final result.
	if process.thread.is_started() and not is_running(process_id):
		process.thread.wait_to_finish()
	# The worker drains pipes into this buffer; poll takes it under the lock and returns only new output.
	process.mutex.lock()
	var chunks := process.output_chunks.duplicate()
	process.output_chunks.clear()
	process.output_chars = 0
	var running := process.running
	var exit_code := process.exit_code
	process.mutex.unlock()
	var output := "".join(chunks)
	# Keep a running process for later polls; remove a finished one after returning its final output.
	if not running:
		processes.erase(process_id)
	return BashProcessResult.new(BashProcessResult.STATUS_RUNNING if running else BashProcessResult.STATUS_EXITED, process_id, exit_code, output)


static func kill(process_id: String) -> bool:
	var process: BashProcess = processes.get(process_id)
	if process == null:
		return false
	process.mutex.lock()
	process.stop_requested = true
	var pid := process.pid
	process.mutex.unlock()
	if pid > 0:
		OSUtils.kill_process(pid)
	return true


static func is_running(process_id: String) -> bool:
	var process: BashProcess = processes.get(process_id)
	if process == null:
		return false
	process.mutex.lock()
	var running := process.running
	process.mutex.unlock()
	return running


static func run_process(process: BashProcess) -> void:
	if process.argv.is_empty():
		finish(process, OSUtils.EXIT_CODE_NOT_STARTED)
		return
	var proc := OS.execute_with_pipe(process.argv[0], process.argv.slice(1), false)
	if proc.is_empty():
		finish(process, OSUtils.EXIT_CODE_NOT_STARTED)
		return
	var pid: int = int(proc.get("pid", -1))
	var stdio: FileAccess = proc.get("stdio")
	var stderr_pipe: FileAccess = proc.get("stderr")
	var stdout_decoder := Utf8StreamDecoder.new()
	var stderr_decoder := Utf8StreamDecoder.new()
	process.mutex.lock()
	process.pid = pid
	var stop_requested := process.stop_requested
	process.mutex.unlock()
	if pid > 0:
		OSUtils.process_pids.add(pid)
	if stop_requested:
		OSUtils.kill_process(pid)

	# Pipes must be drained independently of tool polling. Otherwise a child producing enough
	# output can fill the OS pipe buffer and block before the model polls it again.
	while pid > 0 and OS.is_process_running(pid):
		drain_pipe(process, stdio, false, stdout_decoder)
		drain_pipe(process, stderr_pipe, false, stderr_decoder)
		OS.delay_msec(16)
	drain_pipe(process, stdio, true, stdout_decoder)
	drain_pipe(process, stderr_pipe, true, stderr_decoder)
	OSUtils.close_pipe(stdio)
	OSUtils.close_pipe(stderr_pipe)
	var exit_code := OS.get_process_exit_code(pid) if pid > 0 else OSUtils.EXIT_CODE_NOT_STARTED
	if pid > 0:
		OSUtils.process_pids.remove_value(pid)
	finish(process, exit_code)
	pass


static func drain_pipe(process: BashProcess, pipe: FileAccess, final: bool, decoder: Utf8StreamDecoder) -> void:
	if pipe == null or not pipe.is_open():
		return
	while true:
		var chunk := pipe.get_buffer(4096)
		var err := pipe.get_error()
		if chunk.is_empty():
			if final or err != OK:
				break
			return
		append_output(process, decoder.push(chunk))
		if err != OK:
			break
	if final:
		append_output(process, decoder.flush())
	pass


static func append_output(process: BashProcess, text: String) -> void:
	if text.is_empty():
		return
	process.mutex.lock()
	process.output_chunks.append(text)
	process.output_chars += text.length()
	while process.output_chars > FileUtils.BYTES_PER_MB and process.output_chunks.size() > 1:
		var removed: String = process.output_chunks.pop_front()
		process.output_chars -= removed.length()
	process.mutex.unlock()
	pass


static func finish(process: BashProcess, exit_code: int) -> void:
	process.mutex.lock()
	process.exit_code = exit_code
	process.running = false
	process.mutex.unlock()
	pass
