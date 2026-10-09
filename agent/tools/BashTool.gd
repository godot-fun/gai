class_name BashTool
extends AgentTool

const NAME := "bash"
const ARG_COMMAND := "command"


func _init() -> void:
	name = NAME
	description = """
		Run a Bash command in the project root (Git Bash on Windows). Returns stdout/stderr and exit code. 
		When using the timeout command the time limit should generally be set to 30 seconds."
	"""
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	return OpenAiToolDef.Parameters.object().string_prop(ARG_COMMAND, "Shell command to execute", true)


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var command := str(args.get(ARG_COMMAND, "")).strip_edges()
	if command.is_empty():
		return AgentToolResult.error("error: command is required")
	var timeout := TimeUtils.MILLIS_PER_MINUTE * 3 if command.contains("timeout") else TimeUtils.MILLIS_PER_SECOND * 30
	var argv := build_argv_from_command(command)
	var exec_result := await OSUtils.async_execute(argv, false, timeout, cancel_scope)
	var exit_code := StringUtils.format("exit_code: {}", exec_result.exit_code)
	var exec_output := exec_result.output.build_string()
	var result := StringUtils.truncate_last(exec_output, MAX_OUTPUT, TRUNCATED_SUFFIX + FileUtils.NEWLINE_LF)
	
	var build := StringBuilder.new()
	build.append_line(exit_code)
	build.append(result)
	
	var text := build.build_string()
	var is_error := exec_result.exit_code != 0
	return AgentToolResult.new(text, is_error,  AgentToolResult.ui_details(exit_code, result))
# AgentTool-Interface-Implement-End

static func build_argv_from_command(command: String) -> PackedStringArray:
	var bash := "/bin/bash"
	if OSUtils.is_windows():
		bash = GitUtils.find_windows_git_bash()
	var working_directory := AgentWorkspace.get_root()
	var bash_command := StringUtils.format("cd -- '{}' && {}", working_directory, command)
	if OSUtils.is_windows():
		var encoded_command := Marshalls.raw_to_base64(command.to_utf8_buffer())
		bash_command = StringUtils.format("cd -- '{}' && /bin/bash --noprofile --norc <(printf %s {} | /usr/bin/base64 --decode)", working_directory, encoded_command)
	return PackedStringArray([bash, "--noprofile", "--norc", "-c", bash_command])

