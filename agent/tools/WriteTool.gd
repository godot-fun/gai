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
	var raw_path := str(args.get(ARG_PATH, ""))
	if StringUtils.is_blank(raw_path):
		return AgentToolResult.error("error: path is required", AgentToolResult.ui_file_details("", "path is required"))
	var path := AgentWorkspace.resolve_path(raw_path)
	if not SandboxPolicy.check_path_access(path):
		return AgentToolResult.error(StringUtils.format("error: sandbox denied path outside workspace: {}", path), AgentToolResult.ui_file_details(path, "path outside workspace"))
	var content := str(args.get(ARG_CONTENT, ""))
	var previous_content := FileUtils.read_file_to_string(path)
	var write_error := FileUtils.write_string_to_file(path, content)
	if write_error != OK:
		return AgentToolResult.error(StringUtils.format("error: failed to write file: {}", path)
				, AgentToolResult.ui_file_details(path, "failed to write file: " + error_string(write_error)))
	var message := StringUtils.format("wrote {} bytes to {}", content.length(), path)
	return AgentToolResult.ok(message, AgentToolResult.ui_file_change_details(FileUtils.count_lines(content), FileUtils.count_lines(previous_content), path))
# AgentTool-Interface-Implement-End
