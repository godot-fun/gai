class_name AgentToolRegistry
extends RefCounted

## Maps tool names to AgentTool instances and builds OpenAI tool schemas.

static var tools: Dictionary[String, AgentTool] = {}
static var schemas: Array[OpenAiToolDef] = []

static func _static_init() -> void:
	reload_tools()
	AgentEvents.events.proxy_address_changed.connect(on_proxy_address_changed)
	pass


static func on_proxy_address_changed() -> void:
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
	pass


static func register(tool: AgentTool) -> void:
	tools[tool.name] = tool
	schemas.append(tool.get_schema())
	pass
