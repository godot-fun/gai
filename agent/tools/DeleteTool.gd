class_name DeleteTool
extends AgentTool

const NAME := "delete"
const ARG_PATH := "path"


func _init() -> void:
	name = NAME
	description = "Delete a file in the project workspace. Does not remove directories."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	return OpenAiToolDef.Parameters.object().string_prop(ARG_PATH, "Absolute or project-relative file path", true)


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var raw_path := str(args.get(ARG_PATH, ""))
	if StringUtils.is_blank(raw_path):
		return AgentToolResult.error("error: path is required", AgentToolResult.ui_file_details_message("", "path is required"))
	var path := AgentWorkspace.resolve_path(raw_path)
	if not SandboxPolicy.check_path_access(path):
		return AgentToolResult.error(StringUtils.format("error: sandbox denied path outside workspace: {}", path), AgentToolResult.ui_file_details_message(path, "path outside workspace"))
	if DirAccess.dir_exists_absolute(path):
		var error_message := StringUtils.format("error: path is a directory (not deleted): {}", path)
		return AgentToolResult.error(error_message, AgentToolResult.ui_file_details_message(path, "can not delete directory"))
	if not FileAccess.file_exists(path):
		var error_message := StringUtils.format("error: file not found: {}", path)
		return AgentToolResult.error(error_message, AgentToolResult.ui_file_details_message(path, "file not found"))
	var removed_lines := FileUtils.count_lines(FileUtils.read_file_to_string(path))
	var delete_error := FileUtils.delete_file_or_directory(path)
	if delete_error != OK:
		var error_message := StringUtils.format("error: failed to delete file: {} ({})", path, error_string(delete_error))
		return AgentToolResult.error(error_message, AgentToolResult.ui_file_details_message(path, "failed to delete file: " + error_string(delete_error)))
	var message := StringUtils.format("deleted {}", path)
	return AgentToolResult.ok(message, AgentToolResult.ui_file_details(0, removed_lines, path))
# AgentTool-Interface-Implement-End
