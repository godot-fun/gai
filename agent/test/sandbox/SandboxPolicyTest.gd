extends RefCounted


static func path_boundary_test() -> void:
	var workspace_root := AgentWorkspace.get_root()
	assert(SandboxPolicy.check_path_access(workspace_root))
	assert(SandboxPolicy.check_path_access(workspace_root.path_join("agent/tools/ReadTool.gd")))
	assert(not SandboxPolicy.check_path_access(workspace_root.get_base_dir()))
	assert(not SandboxPolicy.check_path_access(workspace_root.path_join("../outside.txt")))
	pass


static func file_tools_reject_outside_workspace_test() -> void:
	var outside_path := AgentWorkspace.get_root().path_join("../sandbox-outside.txt").simplify_path()
	var tool_args: Array[Array] = [
		[ReadTool.new(), {ReadTool.ARG_PATH: outside_path}],
		[WriteTool.new(), {WriteTool.ARG_PATH: outside_path, WriteTool.ARG_CONTENT: "blocked"}],
		[EditTool.new(), {EditTool.ARG_PATH: outside_path, EditTool.ARG_OLD_STRING: "old", EditTool.ARG_NEW_STRING: "new"}],
		[DeleteTool.new(), {DeleteTool.ARG_PATH: outside_path}],
		[ListDirTool.new(), {ListDirTool.ARG_PATH: outside_path}],
		[GlobTool.new(), {GlobTool.ARG_PATTERN: "*", GlobTool.ARG_PATH: outside_path}],
		[GrepTool.new(), {GrepTool.ARG_PATTERN: ".", GrepTool.ARG_PATH: outside_path}],
		[ImageToTextTool.new(), {ImageToTextTool.ARG_PATH: outside_path, ImageToTextTool.ARG_PROMPT: "describe"}],
		[AudioToTextTool.new(), {AudioToTextTool.ARG_PATH: outside_path}],
	]
	for entry: Array in tool_args:
		var tool: AgentTool = entry[0]
		var args: Dictionary[String, Variant] = {}
		args.assign(entry[1])
		var result := await tool.async_execute(args)
		assert(result.is_error)
		assert(result.content.contains("sandbox denied path outside workspace"))
	pass
