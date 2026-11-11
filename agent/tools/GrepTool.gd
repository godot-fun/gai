class_name GrepTool
extends AgentTool

const NAME := "grep"
const ARG_PATTERN := "pattern"
const ARG_PATH := "path"
const ARG_GLOB := "glob"

const HEAD_LIMIT := 200


func _init() -> void:
	name = NAME
	description = "Search file contents in the workspace using a regular expression (case-sensitive; use (?i) in the pattern if needed). Returns up to 200 matching lines (path:line:content); use read for surrounding code."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> ToolParameters.Parameters:
	var params := ToolParameters.Parameters.new()
	params.string_prop(ARG_PATTERN, "Regular expression pattern to search for", true)
	params.string_prop(ARG_PATH, "File or directory to search (default: workspace root)", false)
	params.string_prop(ARG_GLOB, "Optional glob filter, e.g. *.gd or **/*.gd", false)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var pattern := str(args.get(ARG_PATTERN, "")).strip_edges()
	if pattern.is_empty():
		return AgentToolResult.error("error: pattern is required")
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return AgentToolResult.error(StringUtils.format("error: invalid regex: {}", pattern))
	var search_root := AgentWorkspace.resolve_path(str(args.get(ARG_PATH, "")))
	if not SandboxPolicy.check_path_access(search_root):
		return AgentToolResult.error(StringUtils.format("error: sandbox denied path outside workspace: {}", search_root))
	var glob_filter := str(args.get(ARG_GLOB, "")).strip_edges()
	var all_files: Array[String] = await GlobUtils.async_glob(search_root, glob_filter, true, MAX_FILE_BYTES, GitIgnore.ignore_rules)
	if all_files.is_empty():
		return AgentToolResult.ok("No files to search")

	var files := all_files.slice(0, MAX_FILE_RESULTS) if all_files.size() > MAX_FILE_RESULTS else all_files
	var build: StringBuilder = await ExecutorHelper.async_execute_pooled(build_match_lines.bind(pattern, files))

	var truncated := build.truncate_by_part(MAX_OUTPUT)
	if truncated:
		build.append(TRUNCATED_SUFFIX)
	var text := build.build_joined(FileUtils.NEWLINE_LF)
	return AgentToolResult.ok(text, AgentToolResult.ui_details(NAME, text))
# AgentTool-Interface-Implement-End


## Builds the `path:line:content` report lines of every [param pattern] match in [param files],
## stopping at [constant HEAD_LIMIT] lines. [param pattern] is already validated by the caller.
## Runs off the main thread through [method ExecutorHelper.async_execute_pooled] so file reads never block it.
static func build_match_lines(pattern: String, files: Array[String]) -> StringBuilder:
	var build := StringBuilder.new()
	var regex := RegEx.new()
	regex.compile(pattern)
	var match_count := 0
	for file_path in files:
		if match_count >= HEAD_LIMIT:
			break
		var lines := FileUtils.read_file_to_lines(file_path)
		for i in lines.size():
			if match_count >= HEAD_LIMIT:
				break
			if regex.search(lines[i]) == null:
				continue
			build.append_line(StringUtils.format("{}:{}:{}", file_path, i + 1, lines[i]))
			match_count += 1
	return build
