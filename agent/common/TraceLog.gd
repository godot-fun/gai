class_name TraceLog
extends RefCounted

## Logs agent runtime events that are useful for diagnosing tool execution.

func setup() -> void:
	AgentEvents.events.tool_execution_start.connect(on_tool_execution_start)
	AgentEvents.events.tool_execution_end.connect(on_tool_execution_end)
	pass


func on_tool_execution_start(session_id: int, tool_call_id: String, tool_name: String, args: Dictionary[String, Variant]) -> void:
	Log.info("tool execution start session_id:[{}] tool_call_id:[{}] tool_name:[{}] args:[{}]", session_id, tool_call_id, tool_name, JSON.stringify(args))
	pass


func on_tool_execution_end(session_id: int, tool_call_id: String, tool_name: String, agent_tool_result: AgentToolResult) -> void:
	var content := StringUtils.truncate(agent_tool_result.content)
	Log.info("tool execution end session_id:[{}] tool_call_id:[{}] tool_name:[{}] is_error:[{}] content:[{}]", session_id, tool_call_id, tool_name, agent_tool_result.is_error, content)
	pass
