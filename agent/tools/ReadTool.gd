class_name ReadTool
extends AgentTool

const NAME := "read"
const ARG_PATH := "path"


func _init() -> void:
	name = NAME
	description = "Read a text file from the project workspace. Returns file contents or an error."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	return OpenAiToolDef.Parameters.object().string_prop(ARG_PATH, "Absolute or project-relative file path", true)


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var path := AgentWorkspace.resolve_path(str(args.get(ARG_PATH, "")))
	if StringUtils.is_blank(path):
		return AgentToolResult.error("error: path is required", AgentToolResult.ui_file_details_message("", "path is required"))
	if not FileAccess.file_exists(path):
		var error_message := StringUtils.format("error: file not found: {}", path)
		return AgentToolResult.error(error_message, AgentToolResult.ui_file_details_message(path, "file not found"))
	var content := FileUtils.read_file_to_string(path)
	return AgentToolResult.ok(StringUtils.truncate(content, MAX_OUTPUT, TRUNCATED_SUFFIX), AgentToolResult.ui_file_details(-1, -1, path))
# AgentTool-Interface-Implement-End
