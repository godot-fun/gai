class_name AgentToolRegistry
extends RefCounted

## Maps tool names to [AgentTool] instances and builds chat API [ToolDef] schemas for the model.

static var tools: Dictionary[String, AgentTool] = {}
static var schemas: Array[ToolDef] = []

static func _static_init() -> void:
	reload_tools()
	AgentEvents.events.proxy_address_changed.connect(on_proxy_address_changed)
	AgentEvents.events.mcp_tools_changed.connect(on_mcp_tools_changed)
	pass


static func on_proxy_address_changed() -> void:
	reload_tools()
	pass


static func on_mcp_tools_changed() -> void:
	reload_tools()
	pass


static func reload_tools() -> void:
	tools.clear()
	schemas.clear()
	# core tools
	register(BashTool.new())
	register(ReadTool.new())
	register(WriteTool.new())
	register(EditTool.new())
	register(AudioToTextTool.new())
	
	# image tools
	if AgentSetting.get_read_image_with_api():
		register(ReadImageRemoteTool.new())
	else:
		register(ReadImageLocalTool.new())

	# enhance tools
	register(DeleteTool.new())
	register(GrepTool.new())
	register(GlobTool.new())
	register(ListDirTool.new())

	# web tools
	register(WebFetchTool.new())
	register(WebSearchTool.new())
	for tool: McpTool in McpToolRegistry.tools:
		register(tool)
	pass


## The chat API requires unique tool names, so a duplicate is skipped instead of
## overwriting the name map while leaving a second schema behind (which makes the
## request invalid). First registration wins: builtin tools are registered before MCP ones.
static func register(tool: AgentTool) -> void:
	if StringUtils.is_blank(tool.name):
		Log.error("skip tool with blank name class:[{}]", tool.get_script().get_global_name())
		return
	var existing: AgentTool = tools.get(tool.name)
	if existing != null:
		Log.error("skip duplicate tool name:[{}] existing:[{}] duplicate:[{}]", tool.name, existing.get_script().get_global_name(), tool.get_script().get_global_name())
		return
	tools[tool.name] = tool
	schemas.append(tool.get_schema())
	pass
