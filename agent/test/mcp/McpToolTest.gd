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


static func agent_registry_skips_duplicate_tool_name_test() -> void:
	var first := McpTool.new()
	first.name = "mcp__demo__duplicated"
	var second := McpTool.new()
	second.name = "mcp__demo__duplicated"
	var tool_count := AgentToolRegistry.tools.size()
	var schema_count := AgentToolRegistry.schemas.size()
	AgentToolRegistry.register(first)
	AgentToolRegistry.register(second)
	assert(AgentToolRegistry.tools.get(first.name) == first)
	assert(AgentToolRegistry.tools.size() == tool_count + 1)
	assert(AgentToolRegistry.schemas.size() == schema_count + 1)
	AgentToolRegistry.reload_tools()
	pass


static func agent_registry_skips_blank_tool_name_test() -> void:
	var tool := McpTool.new()
	var tool_count := AgentToolRegistry.tools.size()
	var schema_count := AgentToolRegistry.schemas.size()
	AgentToolRegistry.register(tool)
	assert(AgentToolRegistry.tools.size() == tool_count)
	assert(AgentToolRegistry.schemas.size() == schema_count)
	pass
