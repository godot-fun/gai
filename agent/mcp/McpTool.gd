class_name McpTool
extends AgentTool

var server: String = ""
var remote_name: String = ""
var parameters: Dictionary = {}


func get_schema() -> ToolDef:
	var definition := McpFunctionToolDef.new()
	definition.function.name = name
	definition.function.description = description
	definition.function.parameters = parameters
	return definition


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	return await McpGateway.async_call_tool(server, remote_name, args, cancel_scope)
