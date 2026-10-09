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
	var path := AgentWorkspace.resolve_path(str(args.get(ARG_PATH, "")))
	if StringUtils.is_blank(path):
		return AgentToolResult.error("error: path is required", AgentToolResult.ui_file_details_message("", "path is required"))
	if DirAccess.dir_exists_absolute(path):
		var error_message := StringUtils.format("error: path is a directory (not deleted): {}", path)
		return AgentToolResult.error(error_message, AgentToolResult.ui_file_details_message(path, "can not delete directory"))
	if not FileAccess.file_exists(path):
		var error_message := StringUtils.format("error: file not found: {}", path)
		return AgentToolResult.error(error_message, AgentToolResult.ui_file_details_message(path, "file not found"))
	var removed_lines := FileUtils.count_lines(FileUtils.read_file_to_string(path))
	FileUtils.delete_file_or_directory(path)
	var message := StringUtils.format("deleted {}", path)
	return AgentToolResult.ok(message, AgentToolResult.ui_file_details(0, removed_lines, path))
# AgentTool-Interface-Implement-End
