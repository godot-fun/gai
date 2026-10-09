class_name WriteTool
extends AgentTool

const NAME := "write"
const ARG_PATH := "path"
const ARG_CONTENT := "content"


func _init() -> void:
	name = NAME
	description = "Create or overwrite a text file in the project workspace."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	var params := OpenAiToolDef.Parameters.object()
	params.string_prop(ARG_PATH, "Absolute or project-relative file path", true)
	params.string_prop(ARG_CONTENT, "Full file content to write", true)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var path := AgentWorkspace.resolve_path(str(args.get(ARG_PATH, "")))
	if StringUtils.is_blank(path):
		return AgentToolResult.error("error: path is required", AgentToolResult.ui_file_details_message("", "path is required"))
	var content := str(args.get(ARG_CONTENT, ""))
	var previous_content := FileUtils.read_file_to_string(path)
	if not FileUtils.write_string_to_file(path, content):
		return AgentToolResult.error(StringUtils.format("error: failed to write file: {}", path)
				, AgentToolResult.ui_file_details_message(path, "failed to write file"))
	var message := StringUtils.format("wrote {} bytes to {}", content.length(), path)
	return AgentToolResult.ok(message, AgentToolResult.ui_file_details(FileUtils.count_lines(content), FileUtils.count_lines(previous_content), path))
# AgentTool-Interface-Implement-End
