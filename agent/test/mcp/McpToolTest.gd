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


static func mcp_content_block_keeps_non_text_entries_test() -> void:
	assert(McpGateway.describe_content_block({"type": "text", "text": "hello"}) == "hello")
	var image := McpGateway.describe_content_block({"type": "image", "mimeType": "image/png", "data": "AAAA"})
	assert(image.contains("image/png"))
	var link := McpGateway.describe_content_block({"type": "resource_link", "name": "demo", "uri": "demo://resource/dynamic/text/1"})
	assert(link.contains("demo://resource/dynamic/text/1"))
	var embedded := McpGateway.describe_content_block({"type": "resource", "resource": {"uri": "file://a.txt", "mimeType": "text/plain", "text": "body"}})
	assert(embedded.contains("body"))
	var blob := McpGateway.describe_content_block({"type": "resource", "resource": {"uri": "file://a.bin", "blob": "AAAA"}})
	assert(blob.contains("blob"))
	var other := McpGateway.describe_content_block({"type": "custom", "value": 1})
	assert(other.contains("custom"))
	assert(McpGateway.describe_content_block("raw") == "raw")
	pass


static func mcp_output_is_truncated_to_tool_budget_test() -> void:
	var huge := "x".repeat(AgentTool.MAX_OUTPUT + 100)
	var truncated := McpGateway.truncate_output(huge)
	assert(truncated.length() <= AgentTool.MAX_OUTPUT)
	assert(truncated.ends_with(AgentTool.TRUNCATED_SUFFIX))
	assert(McpGateway.truncate_output("short") == "short")
	pass


static func mcp_content_null_does_not_fail_test() -> void:
	assert(McpGateway.join_content_blocks(null) == StringUtils.EMPTY)
	assert(McpGateway.join_content_blocks({}) == StringUtils.EMPTY)
	assert(McpGateway.join_content_blocks([{"type": "text", "text": "a"}, {"type": "image", "mimeType": "image/png", "data": "AA"}]).contains("a"))
	pass


static func mcp_tool_registry_skips_over_long_name_test() -> void:
	assert(McpToolRegistry.is_tool_name_usable("mcp__demo__echo"))
	assert(McpToolRegistry.is_tool_name_usable("a".repeat(McpToolRegistry.MAX_TOOL_NAME_LENGTH)))
	assert(not McpToolRegistry.is_tool_name_usable("a".repeat(McpToolRegistry.MAX_TOOL_NAME_LENGTH + 1)))
	assert(not McpToolRegistry.is_tool_name_usable(StringUtils.EMPTY))
	pass


static func mcp_gateway_error_message_is_unwrapped_test() -> void:
	var response := HttpResponse.new()
	response.code = 502
	response.body = "{\"error\":{\"code\":\"MCP_CALL_FAILED\",\"message\":\"Unknown MCP server: demo\"}}".to_utf8_buffer()
	var text := McpGateway.describe_error(response)
	assert(text.contains("Unknown MCP server: demo"))
	assert(text.contains("MCP_CALL_FAILED"))
	assert(not text.contains("{\"error\""))
	var transport := HttpResponse.failure("Http connect error:[STATUS_CANT_CONNECT] url:[http://127.0.0.1:1]")
	assert(McpGateway.describe_error(transport) == transport.error)
	var plain := HttpResponse.new()
	plain.code = 500
	plain.body = "not json".to_utf8_buffer()
	assert(McpGateway.describe_error(plain) == "not json")
	pass


static func mcp_structured_content_is_labelled_and_escaped_test() -> void:
	var text := McpGateway.describe_result({
		"content": [{"type": "text", "text": "{\"a\":1}"}],
		"structuredContent": {"temperature": 36, "note": "a\u000bb"},
	})
	assert(text.begins_with("{\"a\":1}\n"))
	assert(text.contains("[structuredContent]"))
	assert(text.contains("\"temperature\": 36"))
	assert(not text.contains("\u000b"))
	assert(text.contains("\\u000b"))
	var structured_only := McpGateway.describe_result({"structuredContent": {"ok": true}})
	assert(structured_only.begins_with(McpGateway.STRUCTURED_CONTENT_LABEL))
	pass


static func mcp_empty_result_keeps_placeholder_test() -> void:
	assert(McpGateway.describe_result({}) == McpGateway.EMPTY_RESULT_TEXT)
	assert(McpGateway.describe_result({"content": null}) == McpGateway.EMPTY_RESULT_TEXT)
	assert(McpGateway.describe_result({"content": []}) == McpGateway.EMPTY_RESULT_TEXT)
	pass
