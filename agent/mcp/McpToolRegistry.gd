class_name McpToolRegistry
extends Object

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
		if StringUtils.is_not_blank(tool.name):
			tools.append(tool)
	AgentEvents.events.mcp_tools_changed.emit()
	pass
