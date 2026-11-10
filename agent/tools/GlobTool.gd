class_name GlobTool
extends AgentTool

const NAME := "glob"
const ARG_PATTERN := "pattern"
const ARG_PATH := "path"


func _init() -> void:
	name = NAME
	description = "Find files under the workspace by glob pattern, e.g. **/*.gd or agent/tools/*.gd."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> ToolParameters.Parameters:
	var params := ToolParameters.Parameters.new()
	params.string_prop(ARG_PATTERN, "Glob pattern (*, ?, ** supported)", true)
	params.string_prop(ARG_PATH, "Directory to search from (default: workspace root)", false)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var pattern := str(args.get(ARG_PATTERN, "")).strip_edges()
	if pattern.is_empty():
		return AgentToolResult.error("error: pattern is required")
	var search_root := AgentWorkspace.resolve_path(str(args.get(ARG_PATH, "")))
	if not SandboxPolicy.check_path_access(search_root):
		return AgentToolResult.error(StringUtils.format("error: sandbox denied path outside workspace: {}", search_root))
	var all_files: Array[String] = await GlobUtils.async_glob(search_root, pattern, true, MAX_FILE_BYTES, GitIgnore.ignore_rules)
	if all_files.is_empty():
		return AgentToolResult.ok("No files matched")

	var truncated_files := all_files.size() > MAX_FILE_RESULTS
	var files := all_files.slice(0, MAX_FILE_RESULTS) if truncated_files else all_files
	var build := StringBuilder.new(files)
	
	var truncated := build.truncate_by_part(MAX_OUTPUT)
	if truncated_files || truncated:
		build.append(TRUNCATED_SUFFIX)
	var text := build.build_joined(FileUtils.NEWLINE_LF)
	return AgentToolResult.ok(text, AgentToolResult.ui_details(NAME, text))
# AgentTool-Interface-Implement-End
