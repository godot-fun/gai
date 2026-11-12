class_name McpToolRegistry
extends Object

## Chat Completions `tools[].function.name` limit (`^[a-zA-Z0-9_-]{1,64}$`); a longer name rejects
## the whole request, so such a tool is skipped instead of registered.
const MAX_TOOL_NAME_LENGTH := 64

static var tools: Array[McpTool] = []


static func _static_init() -> void:
	AgentEvents.events.web_server_started.connect(on_web_server_started)
	async_reload_tools.call_deferred()
	pass


static func on_web_server_started() -> void:
	await async_reload_tools()
	pass


static func async_reload_tools() -> void:
	tools.clear()
	for data: Dictionary in await McpGateway.async_list_tools():
		var tool := McpTool.new()
		tool.server = str(data.get("server", ""))
		tool.remote_name = str(data.get("name", ""))
		tool.name = str(data.get("qualifiedName", ""))
		tool.description = str(data.get("description", ""))
		tool.parameters.assign(data.get("inputSchema", {}))
		if not is_tool_name_usable(tool.name):
			continue
		tools.append(tool)
	AgentEvents.events.mcp_tools_changed.emit()
	pass


## The chat API rejects the whole request when one `tools[].function.name` is blank or longer than
## [constant MAX_TOOL_NAME_LENGTH], so such a tool is skipped instead of registered.
static func is_tool_name_usable(tool_name: String) -> bool:
	if StringUtils.is_blank(tool_name):
		Log.error("skip MCP tool with blank name")
		return false
	if tool_name.length() > MAX_TOOL_NAME_LENGTH:
		Log.error("skip MCP tool with over-long name length:[{}] limit:[{}] name:[{}]", tool_name.length(), MAX_TOOL_NAME_LENGTH, tool_name)
		return false
	return true
