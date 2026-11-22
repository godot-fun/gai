extends RefCounted


static func tool_catalog_covers_registered_builtin_tools_test() -> void:
	var catalog_names := catalog_tool_names()
	for tool_name: String in AgentToolRegistry.tools:
		var tool: AgentTool = AgentToolRegistry.tools[tool_name]
		if tool is McpTool:
			continue
		assert(catalog_names.has(tool_name), "Visual tool catalog is missing builtin tool: " + tool_name)
	assert(catalog_names.has(SimulateAgent.MCP_FIXTURE_NAME), "Visual tool catalog needs an MCP-shaped fixture")
	pass


static func large_payload_covers_entire_catalog_in_one_session_test() -> void:
	for catalog_offset in [0, 1]:
		var seen: Dictionary[String, bool] = {}
		for turn_index in range(SimulateAgent.LARGE_TURNS):
			for call: Dictionary in SimulateAgent.build_tool_calls(turn_index, SimulateAgent.LARGE_TURNS, true, catalog_offset):
				seen[str(call["name"])] = true
		assert(seen.size() == SimulateAgent.TOOL_CATALOG.size(), "Large payload did not cover the entire tool catalog")
	pass


static func catalog_tool_names() -> Dictionary[String, bool]:
	var names: Dictionary[String, bool] = {}
	for tool: Dictionary in SimulateAgent.TOOL_CATALOG:
		var tool_name := str(tool.get("name", ""))
		assert(StringUtils.is_not_blank(tool_name))
		assert(not names.has(tool_name), "Duplicate visual tool fixture: " + tool_name)
		names[tool_name] = true
	return names
