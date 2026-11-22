class_name BashProcessTool
extends AgentTool

const NAME := "bash_process"
const ARG_PROCESS_ID := "process_id"
const ARG_ACTION := "action"
const ACTION_POLL := "poll"
const ACTION_KILL := "kill"


func _init() -> void:
	name = NAME
	description = "Poll incremental output from a running Bash process or kill it. Use the process_id returned by bash."
	pass


func get_parameters() -> ToolParameters.Parameters:
	var params := ToolParameters.Parameters.new()
	params.string_prop(ARG_PROCESS_ID, "Process ID returned by bash", true)
	params.enum_prop(ARG_ACTION, [ACTION_POLL, ACTION_KILL], "Action to perform", true)
	return params


func async_execute(args: Dictionary[String, Variant], _cancel_scope: CancelScope) -> AgentToolResult:
	var process_id := str(args.get(ARG_PROCESS_ID, "")).strip_edges()
	if process_id.is_empty():
		return AgentToolResult.error("error: process_id is required")
	var action := str(args.get(ARG_ACTION, "")).strip_edges()
	if action == ACTION_KILL:
		if not BashProcessManager.kill(process_id):
			return AgentToolResult.error("error: process not found: " + process_id)
		var result := await BashProcessManager.async_poll(process_id, TimeUtils.MILLIS_PER_SECOND)
		return build_result(result)
	if action != ACTION_POLL:
		return AgentToolResult.error("error: action must be poll or kill")
	return build_result(await BashProcessManager.async_poll(process_id))


static func build_result(result: BashProcessResult) -> AgentToolResult:
	var output := StringUtils.truncate_last(result.output, AgentTool.MAX_OUTPUT, AgentTool.TRUNCATED_SUFFIX + FileUtils.NEWLINE_LF)
	match result.status:
		BashProcessManager.STATUS_RUNNING:
			var build := StringBuilder.new()
			build.append_line("process is still running")
			build.append_line("process_id: " + result.process_id)
			build.append(output)
			return AgentToolResult.ok(build.build_string(), AgentToolResult.ui_details("running", output))
		BashProcessManager.STATUS_EXITED:
			var exit_code := StringUtils.format("exit_code: {}", result.exit_code)
			var build := StringBuilder.new()
			build.append_line(exit_code)
			build.append(output)
			return AgentToolResult.new(build.build_string(), result.exit_code != 0, AgentToolResult.ui_details(exit_code, output))
		BashProcessManager.STATUS_NOT_FOUND:
			return AgentToolResult.error("error: process not found: " + result.process_id)
		_:
			return AgentToolResult.error("error: unknown process status: " + result.status)
