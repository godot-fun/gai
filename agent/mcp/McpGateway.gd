class_name McpGateway
extends Object

static func async_list_tools() -> Array[Dictionary]:
	if await WebServer.async_ensure_server_running() != OK:
		return []
	var response := await HttpHelper.async_get(WebServer.server_url() + "/mcp/tools", WebServer.request_timeout_millis)
	if not response.success:
		Log.error("MCP tool listing failed code:[{}] error:[{}]", response.code, response.get_error_string())
		return []
	var body = response.get_body_json()
	if typeof(body) != TYPE_DICTIONARY or typeof(body.get("tools")) != TYPE_ARRAY:
		Log.error("MCP tool listing returned invalid JSON")
		return []
	var result: Array[Dictionary] = []
	result.assign(body.tools)
	return result


static func async_call_tool(server: String, tool_name: String, args: Dictionary[String, Variant], cancel_scope: CancelScope) -> AgentToolResult:
	var payload := {"server": server, "name": tool_name, "arguments": args}
	var response := await HttpHelper.async_post(WebServer.server_url() + "/mcp/call", JsonUtils.object_to_json(payload), PackedStringArray(), WebServer.request_timeout_millis, "", Callable(), cancel_scope)
	if not response.success:
		return AgentToolResult.error(response.get_error_string())
	var body = response.get_body_json()
	if typeof(body) != TYPE_DICTIONARY:
		return AgentToolResult.error("MCP tool returned invalid JSON")
	var parts: PackedStringArray = []
	for item: Variant in body.get("content", []):
		if typeof(item) == TYPE_DICTIONARY and item.get("type", "") == "text":
			parts.append(str(item.get("text", "")))
	var text := "\n".join(parts)
	if body.has("structuredContent"):
		text += ("\n" if StringUtils.is_not_blank(text) else "") + JSON.stringify(body.structuredContent)
	return AgentToolResult.error(text) if body.get("isError", false) else AgentToolResult.ok(text)
