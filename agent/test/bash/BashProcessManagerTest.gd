extends RefCounted


static func bash_tools_are_bash_tools_test() -> void:
	assert(ToolHelper.is_bash_tool(BashTool.NAME))
	assert(ToolHelper.is_bash_tool(BashProcessTool.NAME))
	assert(not ToolHelper.is_bash_tool(ReadTool.NAME))
	pass


static func poll_completed_process_test() -> void:
	var process_id := BashProcessManager.start("printf process-ok")
	assert(process_id.begins_with("bash_"))
	assert(process_id.trim_prefix("bash_").is_valid_int())
	var result := await BashProcessManager.async_poll(process_id, TimeUtils.MILLIS_PER_SECOND * 5)
	assert(result.status == BashProcessResult.STATUS_EXITED)
	assert(result.exit_code == 0)
	assert(result.output == "process-ok")
	pass


static func poll_and_kill_running_process_test() -> void:
	var os_utils_process_pids := OSUtils.process_pids.to_array()
	var process_id := BashProcessManager.start("sleep 10")
	var running := await BashProcessManager.async_poll(process_id, 100)
	assert(running.status == BashProcessResult.STATUS_RUNNING)
	assert(OSUtils.process_pids.to_array() == os_utils_process_pids)
	assert(BashProcessManager.kill(process_id))
	var killed := await BashProcessManager.async_poll(process_id, TimeUtils.MILLIS_PER_SECOND * 5)
	assert(killed.status == BashProcessResult.STATUS_EXITED)
	pass


static func unread_output_is_bounded_test() -> void:
	var command := "head -c 200000 /dev/zero | tr '\\0' x"
	var process_id := BashProcessManager.start(command)
	var result := await BashProcessManager.async_poll(process_id, TimeUtils.MILLIS_PER_SECOND * 5)
	assert(result.status == BashProcessResult.STATUS_EXITED)
	assert(result.output.to_utf8_buffer().size() <= BashProcessManager.MAX_BUFFERED_OUTPUT_BYTES)
	pass


static func exited_tool_result_omits_process_metadata_test() -> void:
	var result := BashProcessResult.new(BashProcessResult.STATUS_EXITED, "bash_1", 0, "done")
	var tool_result := BashProcessTool.build_result(result)
	assert(tool_result.content == "exit_code: 0\ndone")
	assert(not tool_result.content.contains("status:"))
	assert(not tool_result.content.contains("process_id:"))
	assert(not tool_result.is_error)
	pass


static func running_tool_result_includes_process_id_test() -> void:
	var result := BashProcessResult.new(BashProcessResult.STATUS_RUNNING, "bash_2", OSUtils.EXIT_CODE_NOT_STARTED, "working")
	var tool_result := BashProcessTool.build_result(result)
	assert(tool_result.content == "process is still running\nprocess_id: bash_2\nworking")
	assert(not tool_result.is_error)
	pass


static func bash_process_bubble_uses_compact_title_test() -> void:
	var entry := ChatEntry.new(ChatEntry.KIND_BASH_TOOL, BashProcessTool.NAME, "poll bash_26")
	assert(BashToolBubble.compact_title(entry) == "bash_process  poll bash_26")
	pass
