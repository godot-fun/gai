class_name EditTool
extends AgentTool

const NAME := "edit"
const ARG_PATH := "path"
const ARG_OLD_STRING := "old_string"
const ARG_NEW_STRING := "new_string"


func _init() -> void:
	name = NAME
	description = "Replace an exact string in a file. old_string must match exactly once."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	var params := OpenAiToolDef.Parameters.object()
	params.string_prop(ARG_PATH, "Absolute or project-relative file path", true)
	params.string_prop(ARG_OLD_STRING, "Exact text to find (must be unique in file)", true)
	params.string_prop(ARG_NEW_STRING, "Replacement text", true)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var path := AgentWorkspace.resolve_path(str(args.get(ARG_PATH, "")))
	if StringUtils.is_blank(path):
		return AgentToolResult.error("error: path is required", AgentToolResult.ui_file_details_message("", "path is required"))
	if not FileAccess.file_exists(path):
		var error_message := StringUtils.format("error: file not found: {}", path)
		return AgentToolResult.error(error_message, AgentToolResult.ui_file_details_message(path, "file not found"))
	var old_string := str(args.get(ARG_OLD_STRING, ""))
	var new_string := str(args.get(ARG_NEW_STRING, ""))
	var content := FileUtils.read_file_to_string(path)
	var count := content.count(old_string)
	if count == 0:
		return AgentToolResult.error("error: old_string not found", AgentToolResult.ui_file_details_message(path, "old string not found"))
	if count > 1:
		return AgentToolResult.error(StringUtils.format("error: old_string found {} times; must be unique", count)
				, AgentToolResult.ui_file_details_message(path, "not unique old string not found"))
	var updated := content.replace(old_string, new_string)
	if not FileUtils.write_string_to_file(path, updated):
		return AgentToolResult.error(StringUtils.format("error: failed to write file: {}", path), AgentToolResult.ui_file_details_message(path, "failed to write file"))
	var message := StringUtils.format("edited {}", path)
	var lines_added := FileUtils.count_lines(new_string)
	var lines_removed := FileUtils.count_lines(old_string)
	return AgentToolResult.ok(message, AgentToolResult.ui_file_details(lines_added, lines_removed, path))
# AgentTool-Interface-Implement-End
