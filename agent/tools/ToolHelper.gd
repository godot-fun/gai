class_name ToolHelper
extends Object


static func is_file_tool(tool_name: String) -> bool:
	return (
		tool_name == ReadTool.NAME
		or tool_name == WriteTool.NAME
		or tool_name == EditTool.NAME
		or tool_name == DeleteTool.NAME
	)
