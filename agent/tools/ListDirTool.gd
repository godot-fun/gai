class_name ListDirTool
extends AgentTool

const NAME := "list_dir"
const ARG_PATH := "path"
const ARG_RECURSIVE := "recursive"

const MAX_ENTRIES := 500


func _init() -> void:
	name = NAME
	description = "List files under a workspace directory (optional recursive listing)."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	var params := OpenAiToolDef.Parameters.object()
	params.string_prop(ARG_PATH, "Directory path (default: workspace root)", false)
	params.boolean_prop(ARG_RECURSIVE, "Whether to list subdirectories recursively (default false)", false)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var search_root := AgentWorkspace.resolve_path(str(args.get(ARG_PATH, "")))
	if not DirAccess.dir_exists_absolute(search_root):
		return AgentToolResult.error("error: directory not found", AgentToolResult.ui_file_details_message(search_root, "directory not found"))
	var recursive := NumberUtils.parse_bool(args.get(ARG_RECURSIVE, false))
	var dirs := FileUtils.get_all_directories_in_folder(search_root, recursive)
	var files := FileUtils.get_all_files_in_folder(search_root, recursive)
	dirs.sort()
	files.sort()
	for i in dirs.size():
		dirs[i] += "/"
	var entries: Array[String] = []
	entries.append_array(dirs)
	entries.append_array(files)
	var truncated_files := entries.size() > MAX_ENTRIES
	entries = entries.slice(0, MAX_ENTRIES)
	var build := StringBuilder.new(entries)
	
	var truncated := build.truncate_by_part(MAX_OUTPUT)
	if truncated_files || truncated:
		build.append(TRUNCATED_SUFFIX)
	var text := build.build_joined(FileUtils.NEWLINE_LF)
	return AgentToolResult.ok(text, AgentToolResult.ui_details(NAME, text))
# AgentTool-Interface-Implement-End
