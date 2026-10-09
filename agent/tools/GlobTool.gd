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
func get_parameters() -> OpenAiToolDef.Parameters:
	var params := OpenAiToolDef.Parameters.object()
	params.string_prop(ARG_PATTERN, "Glob pattern (*, ?, ** supported)", true)
	params.string_prop(ARG_PATH, "Directory to search from (default: workspace root)", false)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var pattern := str(args.get(ARG_PATTERN, "")).strip_edges()
	if pattern.is_empty():
		return AgentToolResult.error("error: pattern is required")
	var search_root := AgentWorkspace.resolve_path(str(args.get(ARG_PATH, "")))
	var all_files := GlobUtils.glob(search_root, pattern, true, MAX_FILE_BYTES, workspace_skip_glob_rules)
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


# ---------------------------------------------------------------------------
# Workspace file collection — shared by glob / grep (FileUtils.glob)
# ---------------------------------------------------------------------------

## Always applied as skip globs during agent workspace search.
static var SKIP_DIR_NAMES: PackedStringArray = PackedStringArray([
	".git",
	"node_modules",
	".godot",
])

static var WORKSPACE_IGNORE_FILES: PackedStringArray = PackedStringArray([
	".gitignore",
	".cursorignore",
	".agentignore",
	".aiignore",
])

## Literal ignore lines (no [code]*[/code] / [code]?[/code] / [code][[/code]) from [constant WORKSPACE_IGNORE_FILES], plus [constant SKIP_DIR_NAMES].
static var workspace_skip_glob_rules: Array[String] = []


static func _static_init() -> void:
	for dir_name in SKIP_DIR_NAMES:
		workspace_skip_glob_rules.append(dir_name)
	for file_name in WORKSPACE_IGNORE_FILES:
		var path := AgentWorkspace.resolve_path(file_name)
		if not FileAccess.file_exists(path):
			continue
		for line in FileUtils.read_file_to_lines(path):
			var trimmed := line.strip_edges()
			if trimmed.is_empty() or trimmed.begins_with("#"):
				continue
			if trimmed.begins_with("!"):
				continue
			if trimmed.contains("*") or trimmed.contains("?") or trimmed.contains("["):
				continue
			workspace_skip_glob_rules.append(line)
	pass
