class_name EditTool
extends AgentTool

const NAME := "edit"
const ARG_FILE_PATH := "file_path"
const ARG_OLD_STRING := "old_string"
const ARG_NEW_STRING := "new_string"
const ARG_REPLACE_ALL := "replace_all"


func _init() -> void:
	name = NAME
	description = "Edit a single file using exact text replacement."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	var params := OpenAiToolDef.Parameters.object()
	params.string_prop(ARG_FILE_PATH, "Path to the file to edit (relative or absolute).", true)
	params.string_prop(ARG_OLD_STRING, "Exact text to replace. Must appear exactly once unless replace_all is true.", true)
	params.string_prop(ARG_NEW_STRING, "Text to replace old_string with. Use an empty string to delete it.", true)
	params.boolean_prop(ARG_REPLACE_ALL, "Replace every occurrence of old_string. Defaults to false.", false)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var file_path := str(args.get(ARG_FILE_PATH, ""))
	if StringUtils.is_blank(file_path):
		return AgentToolResult.error("error: file_path is required", AgentToolResult.ui_file_details_message("", "file_path is required"))
	file_path = AgentWorkspace.resolve_path(file_path)
	if not SandboxPolicy.check_path_access(file_path):
		return AgentToolResult.error(StringUtils.format("error: sandbox denied file path outside workspace: {}", file_path), AgentToolResult.ui_file_details_message(file_path, "file path outside workspace"))
	if not FileAccess.file_exists(file_path):
		var error_message := StringUtils.format("error: file not found: {}", file_path)
		return AgentToolResult.error(error_message, AgentToolResult.ui_file_details_message(file_path, "file not found"))
	var old_string := str(args.get(ARG_OLD_STRING, ""))
	var new_string := str(args.get(ARG_NEW_STRING, ""))
	var replace_all := NumberUtils.parse_bool(args.get(ARG_REPLACE_ALL, false))
	if old_string.is_empty():
		return AgentToolResult.error("error: old_string must not be empty", AgentToolResult.ui_file_details_message(file_path, "old_string must not be empty"))
	var content := FileUtils.read_file_to_string(file_path)
	var count := content.count(old_string)
	if count == 0:
		return AgentToolResult.error("error: old_string not found", AgentToolResult.ui_file_details_message(file_path, "old string not found"))
	if count > 1 && not replace_all:
		return AgentToolResult.error(StringUtils.format("error: old_string found {} times; must be unique (use replace_all to replace all occurrences)", count)
				, AgentToolResult.ui_file_details_message(file_path, "old_string is not unique"))
	var updated := content.replace(old_string, new_string)
	if not FileUtils.write_string_to_file(file_path, updated):
		return AgentToolResult.error(StringUtils.format("error: failed to write file: {}", file_path), AgentToolResult.ui_file_details_message(file_path, "failed to write file"))
	var message := StringUtils.format("edited {}", file_path)
	var lines_added := FileUtils.count_lines(new_string)
	var lines_removed := FileUtils.count_lines(old_string)
	return AgentToolResult.ok(message, AgentToolResult.ui_file_details(lines_added, lines_removed, file_path))
# AgentTool-Interface-Implement-End
