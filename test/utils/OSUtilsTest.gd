static func OSUtils_is_windows_test() -> void:
	assert(OSUtils.is_windows() == (OS.get_name().strip_edges().to_lower() == "windows"))
	pass


static func OSUtils_is_mac_test() -> void:
	assert(OSUtils.is_mac() == (OS.get_name().strip_edges().to_lower() == "macos"))
	pass


static func OSUtils_is_linux_test() -> void:
	assert(OSUtils.is_linux() == (OS.get_name().strip_edges().to_lower() == "linux"))
	pass


static func OSUtils_godot_version_test() -> void:
	assert(StringUtils.is_not_blank(OSUtils.godot_version()))
	pass


static func OSUtils_build_shell_argv_test() -> void:
	var argv := OSUtils.build_shell_argv("echo hello")
	if OSUtils.is_windows():
		assert(argv == PackedStringArray(["cmd.exe", "/c", "chcp 65001 >nul && echo hello"]))
	else:
		assert(argv == PackedStringArray(["/bin/sh", "-c", "echo hello"]))
	pass


static func OSUtils_split_command_line_test() -> void:
	assert(OSUtils.split_command_line("git add -A") == PackedStringArray(["git", "add", "-A"]))
	assert(OSUtils.split_command_line("  git   add -A  ") == PackedStringArray(["git", "add", "-A"]))
	assert(OSUtils.split_command_line("git\tadd\t-A") == PackedStringArray(["git", "add", "-A"]))
	assert(OSUtils.split_command_line("") == PackedStringArray())
	assert(OSUtils.split_command_line("   ") == PackedStringArray())
	pass


static func OSUtils_split_command_line_quotes_test() -> void:
	var argv := OSUtils.split_command_line("git --git-dir \"C:/has space/.gai/checkpoints\" add -A")
	assert(argv == PackedStringArray(["git", "--git-dir", "C:/has space/.gai/checkpoints", "add", "-A"]))
	assert(OSUtils.split_command_line("type \"C:/中文 目录/fixture.txt\"") == PackedStringArray(["type", "C:/中文 目录/fixture.txt"]))
	assert(OSUtils.split_command_line("git commit -m 'two words'") == PackedStringArray(["git", "commit", "-m", "two words"]))
	assert(OSUtils.split_command_line("git log \"a'b\"") == PackedStringArray(["git", "log", "a'b"]))
	# Quotes only group arguments; an empty quoted argument is dropped.
	assert(OSUtils.split_command_line("git log \"\"") == PackedStringArray(["git", "log"]))
	pass


static func OSUtils_split_command_line_execute_test() -> void:
	OSUtils.stop_all()
	var command := "cmd.exe /c echo OSUtilsSplitHello" if OSUtils.is_windows() else "/bin/sh -c 'echo OSUtilsSplitHello'"
	var result := await OSUtils.async_execute(OSUtils.split_command_line(command), false)
	assert(result.exit_code == 0)
	assert(result.output.build_string().contains("OSUtilsSplitHello"))
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_empty_argv_test() -> void:
	OSUtils.stop_all()
	var result := await OSUtils.async_execute(PackedStringArray(), false)
	assert(result.exit_code == -1)
	assert(result.output.is_empty())
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_execute_test() -> void:
	OSUtils.stop_all()
	var result := OSUtils.execute(echo_argv("OSUtilsSyncHello"), false)
	assert(result.exit_code == 0)
	assert(result.output.build_string().contains("OSUtilsSyncHello"))
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_echo_test() -> void:
	OSUtils.stop_all()
	var result := await OSUtils.async_execute(echo_argv("OSUtilsTestHello"), false)
	assert(result.exit_code == 0)
	assert(result.output.build_string().contains("OSUtilsTestHello"))
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_chinese_async_output_test() -> void:
	OSUtils.stop_all()
	var result := await OSUtils.async_execute(OSUtils.build_shell_argv(utf8_fixture_command()), false)
	assert(result.exit_code == 0)
	var output := result.output.build_string()
	assert(output.contains("OSUtils中文测试"))
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_chinese_folder_path_test() -> void:
	OSUtils.stop_all()
	var root := ProjectSettings.globalize_path("user://OSUtils_中文目录_" + str(TimeUtils.now()) + "_" + str(randi()))
	var file_path := root.path_join("fixture.txt")
	assert(DirAccess.make_dir_recursive_absolute(root) == OK)
	assert(FileUtils.write_string_to_file(file_path, "OSUtilsChinesePathHello"))
	var result := await OSUtils.async_execute(chinese_path_argv(file_path), false)
	var removed := FileUtils.delete_file_or_directory(root)
	assert(result.exit_code == 0)
	assert(removed)
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_multiline_output_test() -> void:
	OSUtils.stop_all()
	var result := await OSUtils.async_execute(multiline_argv(), false)
	assert(result.exit_code == 0)
	var text := FileUtils.normalize_line_endings_to_lf(result.output.build_string())
	var lines := text.split("\n", false)
	assert(lines.size() >= 3)
	assert(text.contains("OSUtilsLine1"))
	assert(text.contains("OSUtilsLine2"))
	assert(text.contains("OSUtilsLine3"))
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_command_not_found_test() -> void:
	OSUtils.stop_all()
	var result := await OSUtils.async_execute(command_not_found_argv(), false)
	assert(result.exit_code != 0)
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_timeout_test() -> void:
	OSUtils.stop_all()
	var start := Time.get_ticks_msec()
	var result := await OSUtils.async_execute(sleep_argv(15), false, 500)
	assert(result.exit_code == OSUtils.EXIT_CODE_TIMEOUT)
	assert(result.output.build_string().contains("[timeout]"))
	assert(Time.get_ticks_msec() - start < 10000)
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_timeout_not_reached_test() -> void:
	OSUtils.stop_all()
	var result := await OSUtils.async_execute(echo_argv("OSUtilsTimeoutHello"), false, 10000)
	assert(result.exit_code == 0)
	var output := result.output.build_string()
	assert(output.contains("OSUtilsTimeoutHello"))
	assert(not output.contains("[timeout]"))
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_stop_all_empty_test() -> void:
	OSUtils.stop_all()
	assert(OSUtils.process_pids.is_empty())
	OSUtils.stop_all()
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_stop_current_test() -> void:
	OSUtils.stop_all()
	gdf.callable_deferred(func() -> void: await OSUtils.async_execute(sleep_argv(15), false))
	await ThreadUtils.async_sleep(800)
	assert(OSUtils.process_pids.size() > 0)
	OSUtils.stop_last()
	await ThreadUtils.async_sleep(1500)
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_concurrent_pid_tracking_test() -> void:
	OSUtils.stop_all()
	gdf.callable_deferred(func() -> void: await OSUtils.async_execute(sleep_argv(15), false))
	await ThreadUtils.async_sleep(800)
	assert(OSUtils.process_pids.size() == 1)
	var result := await OSUtils.async_execute(echo_argv("OSUtilsConcurrentEcho"), false)
	assert(result.exit_code == 0)
	assert(result.output.build_string().contains("OSUtilsConcurrentEcho"))
	assert(OSUtils.process_pids.size() == 1)
	OSUtils.stop_all()
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_stop_all_test() -> void:
	OSUtils.stop_all()
	gdf.callable_deferred(func() -> void: await OSUtils.async_execute(sleep_argv(15), false))
	await ThreadUtils.async_sleep(800)
	assert(OSUtils.process_pids.size() > 0)
	OSUtils.stop_all()
	assert(OSUtils.process_pids.is_empty())
	await ThreadUtils.async_sleep(500)
	pass


static func OSUtils_kill_process_no_process_test() -> void:
	OSUtils.stop_all()
	# An unknown pid is a no-op, so the OS.kill error code path is not reached.
	assert(OSUtils.kill_process(-1, 0) == OK)
	assert(OSUtils.kill_process(0, 0) == OK)
	assert(OSUtils.kill_process(0) == OK)
	pass


static func OSUtils_kill_process_running_test() -> void:
	OSUtils.stop_all()
	gdf.callable_deferred(func() -> void: await OSUtils.async_execute(sleep_argv(15), false))
	await ThreadUtils.async_sleep(800)
	var pid := OSUtils.process_pids.latest()
	assert(pid > 0)
	assert(OSUtils.kill_process(pid) == OK)
	await ThreadUtils.async_sleep(500)
	assert(not OS.is_process_running(pid))
	OSUtils.stop_all()
	pass


static func OSUtils_cancel_scope_stops_its_process_test() -> void:
	OSUtils.stop_all()
	var scope := CancelScope.new()
	gdf.callable_deferred(func() -> void: await OSUtils.async_execute(sleep_argv(15), false, TimeUtils.MILLIS_PER_HOUR, scope))
	await await_pid_count(1)
	assert(OSUtils.process_pids.size() == 1)
	scope.cancel()
	await await_pid_count(0)
	assert(OSUtils.process_pids.is_empty())
	pass


static func OSUtils_cancel_scope_leaves_other_process_test() -> void:
	# Cancelling an unrelated scope must not touch a process registered in another scope — this is
	# the multi-session bug where stop_last() killed whichever process had started most recently.
	OSUtils.stop_all()
	var scope_a := CancelScope.new()
	var scope_b := CancelScope.new()
	gdf.callable_deferred(func() -> void: await OSUtils.async_execute(sleep_argv(15), false, TimeUtils.MILLIS_PER_HOUR, scope_a))
	await await_pid_count(1)
	var survived_unrelated_cancel := false
	if OSUtils.process_pids.size() == 1:
		scope_b.cancel()
		await ThreadUtils.async_sleep(800)
		survived_unrelated_cancel = OSUtils.process_pids.size() == 1
	scope_a.cancel()
	await await_pid_count(0)
	OSUtils.stop_all()
	assert(survived_unrelated_cancel)
	assert(OSUtils.process_pids.is_empty())
	pass


## Polls until the tracked pid count reaches [param expected], or a 5s deadline passes.
static func await_pid_count(expected: int) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while OSUtils.process_pids.size() != expected and Time.get_ticks_msec() < deadline:
		await ThreadUtils.async_sleep(50)
	pass


static func utf8_fixture_command() -> String:
	if OSUtils.is_windows():
		return "type test\\asset\\Utf8OutputFixture.txt"
	return "cat test/asset/Utf8OutputFixture.txt"


static func command_not_found_argv() -> PackedStringArray:
	if OSUtils.is_windows():
		return PackedStringArray(["cmd", "/c", "__godot_osutils_missing_executable__"])
	return PackedStringArray(["sh", "-c", "__godot_osutils_missing_executable__"])


static func chinese_path_argv(file_path: String) -> PackedStringArray:
	if OSUtils.is_windows():
		var escaped_path := file_path.replace("'", "''")
		var script := "$content = Get-Content -LiteralPath '" + escaped_path + "' -Raw; if ($content -ceq 'OSUtilsChinesePathHello') { exit 0 } else { exit 1 }"
		return PackedStringArray(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script])
	return PackedStringArray(["grep", "-F", "OSUtilsChinesePathHello", file_path])


static func multiline_argv() -> PackedStringArray:
	if OSUtils.is_windows():
		return PackedStringArray(["cmd", "/c", "echo OSUtilsLine1& echo OSUtilsLine2& echo OSUtilsLine3"])
	return PackedStringArray(["sh", "-c", "echo OSUtilsLine1; echo OSUtilsLine2; echo OSUtilsLine3"])


static func echo_argv(text: String) -> PackedStringArray:
	if OSUtils.is_windows():
		return PackedStringArray(["cmd", "/c", "echo " + text])
	return PackedStringArray(["sh", "-c", "echo " + text])


static func sleep_argv(seconds: int) -> PackedStringArray:
	if OSUtils.is_windows():
		return PackedStringArray(["cmd", "/c", "ping -n " + str(seconds + 1) + " 127.0.0.1 > nul"])
	return PackedStringArray(["sleep", str(seconds)])
