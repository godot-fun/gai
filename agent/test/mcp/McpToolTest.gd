static func mcp_tool_preserves_raw_json_schema_test() -> void:
	var tool := McpTool.new()
	tool.name = "mcp__demo__dynamic"
	tool.description = "Dynamic MCP tool"
	tool.parameters = {
		"type": "object",
		"properties": {"value": {"oneOf": [{"type": "string"}, {"type": "integer"}]}},
		"additionalProperties": false,
	}
	var request := OpenAiRequest.new("test-model", [ChatMessage.user("hello")], false)
	request.tools.append(tool.get_schema())
	var body: Dictionary = JSON.parse_string(request.to_json())
	var parameters: Dictionary = body.tools[0].function.parameters
	assert(parameters.properties.value.oneOf.size() == 2)
	assert(parameters.additionalProperties == false)
	pass


static func agent_registry_appends_mcp_registry_tools_test() -> void:
	var tool := McpTool.new()
	tool.name = "mcp__demo__echo"
	McpToolRegistry.tools = [tool]
	AgentEvents.events.mcp_tools_changed.emit()
	assert(AgentToolRegistry.tools.get(tool.name) == tool)
	McpToolRegistry.tools.clear()
	AgentEvents.events.mcp_tools_changed.emit()
	pass
