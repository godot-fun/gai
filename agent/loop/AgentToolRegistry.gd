class_name AgentToolRegistry
extends RefCounted

## Maps tool names to AgentTool instances and builds OpenAI tool schemas.

static var tools: Dictionary[String, AgentTool] = {}
static var schemas: Array[OpenAiToolDef] = []

static func _static_init() -> void:
	# core tools
	register(BashTool.new())
	register(ReadTool.new())
	register(WriteTool.new())
	register(EditTool.new())
	register(ImageToTextTool.new())
	register(AudioToTextTool.new())
	
	# enhance tools
	register(DeleteTool.new())
	register(GrepTool.new())
	register(GlobTool.new())
	register(ListDirTool.new())

	# web tools
	var detection := await ProxyUtils.async_detect_proxy()
	var proxy_address := detection.address if detection != null else ""
	register(WebFetchTool.new(proxy_address))
	if detection != null:
		register(WebSearchToolProxy.new(detection.address))
	else:
		register(WebSearchToolBing.new())
	pass


static func register(tool: AgentTool) -> void:
	tools[tool.name] = tool
	schemas.append(tool.get_schema())
	pass
