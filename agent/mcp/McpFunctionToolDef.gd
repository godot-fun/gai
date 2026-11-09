class_name McpFunctionToolDef
extends ToolDef

## MCP tool schema (`tools[].type: function`) with provider `inputSchema` copied into [member FunctionDef.parameters].

var function: FunctionDef = FunctionDef.new()


class FunctionDef:
	var name: String = ""
	var description: String = ""
	var parameters: Dictionary = {}
