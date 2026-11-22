class_name BashTool
extends AgentTool

const NAME := "bash"
const ARG_COMMAND := "command"


func _init() -> void:
	name = NAME
	description = """
		Run a Bash command in the project root (Git Bash on Windows). Waits up to 30 seconds. If it is still running, returns a process_id without stopping it; use bash_process tool to poll or kill it.
	"""
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> ToolParameters.Parameters:
	return ToolParameters.Parameters.new().string_prop(ARG_COMMAND, "Shell command to execute", true)


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope) -> AgentToolResult:
	var command := str(args.get(ARG_COMMAND, "")).strip_edges()
	if command.is_empty():
		return AgentToolResult.error("error: command is required")
	var deny_reason := SandboxBashPolicy.check_bash(command)
	if not deny_reason.is_empty():
		return AgentToolResult.error(StringUtils.format("error: sandbox denied: {}", deny_reason))
	var process_id := BashProcessManager.start(command, cancel_scope)
	var process_result := await BashProcessManager.async_poll(process_id)
	return BashProcessTool.build_result(process_result)
# AgentTool-Interface-Implement-End
