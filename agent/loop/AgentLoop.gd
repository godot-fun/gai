class_name AgentLoop
extends RefCounted

const MAX_TURNS := 64

## Core agent loop: LLM call → tool execution → repeat until done.
static func run(ai_client: OpenAiClient, session: AgentSession) -> void:
	var turn := 0
	AgentEvents.events.agent_start.emit(session.id)
	while turn < MAX_TURNS:
		turn += 1
		if RuntimeManager.is_stop_requested(session.id):
			AgentEvents.events.agent_end.emit(session.id, "Stop.")
			return
		
		AgentEvents.events.turn_start.emit(session.id)
		var on_chunk := func(chunk: String, stream_kind: String) -> void: AgentEvents.events.message_update.emit(session.id, chunk, stream_kind)
		var completion := await ai_client.async_chat_messages_stream(session.messages, AgentToolRegistry.schemas, ApiSetting.get_proxy_address(), on_chunk)
		AgentEvents.events.message_complete.emit(session.id, completion.usage)

		if RuntimeManager.is_stop_requested(session.id):
			AgentEvents.events.agent_end.emit(session.id, "Stop..")
			return
		if completion.has_error():
			AgentEvents.events.agent_end.emit(session.id, completion.error)
			return

		var content := completion.content
		var tool_calls := completion.tool_calls

		if tool_calls.is_empty() and StringUtils.is_not_blank(content):
			session.messages.append(ChatMessage.assistant(content, completion.reasoning_content))
			AgentEvents.events.agent_end.emit(session.id, StringUtils.EMPTY)
			return

		session.messages.append(ChatMessage.assistant_tool_calls(tool_calls, content, completion.reasoning_content))
		for tool_call: OpenAiToolCall in tool_calls:
			if RuntimeManager.is_stop_requested(session.id):
				AgentEvents.events.agent_end.emit(session.id, "Stop...")
				return
			var tool_name := tool_call.function.name
			var tool_call_id := tool_call.id if StringUtils.is_not_blank(tool_call.id) else tool_name
			var tool: AgentTool = AgentToolRegistry.tools.get(tool_name)
			if tool == null:
				var unknown_tool_result := AgentToolResult.error(StringUtils.format("unknown tool '{}'", tool_name))
				AgentEvents.events.tool_execution_start.emit(session.id, tool_call_id, tool_name, {})
				AgentEvents.events.tool_execution_end.emit(session.id, tool_call_id, tool_name, unknown_tool_result)
				session.messages.append(ChatMessage.tool_result(tool_call.id, unknown_tool_result.content))
				continue
			var args := tool.parse_args(tool_call.function.arguments)
			AgentEvents.events.tool_execution_start.emit(session.id, tool_call_id, tool_name, args)
			var agent_tool_result: AgentToolResult
			if args.has(AgentTool.ARG_PARSE_ERROR):
				agent_tool_result = AgentToolResult.error(str(args[AgentTool.ARG_PARSE_ERROR]))
			else:
				agent_tool_result = await tool.async_execute(args, ai_client.cancel_scope)
			AgentEvents.events.tool_execution_end.emit(session.id, tool_call_id, tool_name, agent_tool_result)
			session.messages.append(ChatMessage.tool_result(tool_call.id, agent_tool_result.content))
		AgentEvents.events.turn_end.emit(session.id)
	AgentEvents.events.agent_end.emit(session.id, "max turns exceeded")
	pass
