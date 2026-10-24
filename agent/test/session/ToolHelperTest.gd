extends RefCounted

## Unit coverage for tool categories used by chat-bubble dispatch.


static func explorer_tool_classification_test() -> void:
	assert(ToolHelper.is_explorer_tool(GlobTool.NAME))
	assert(ToolHelper.is_explorer_tool(GrepTool.NAME))
	assert(ToolHelper.is_explorer_tool(ListDirTool.NAME))
	assert(not ToolHelper.is_explorer_tool(ReadTool.NAME))
	assert(not ToolHelper.is_explorer_tool(WebSearchTool.NAME))
	pass


static func image_tool_is_a_file_tool_test() -> void:
	assert(ToolHelper.is_file_tool(ReadImageTool.NAME))
	pass
