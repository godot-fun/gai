class_name CompactionAgent
extends RefCounted

## Event-free agent loop used by context compaction. It shares the normal agent's tool
## registry and sandboxed tool implementations, but keeps its internal turns out of chat UI.
##
## Unlike [AgentLoop], this class emits no lifecycle, streaming, or tool events and does not
## persist messages. The caller owns the temporary message array and consumes only the final
## completion; file changes made by registered tools remain normal workspace changes.

static func run(ai_client: OpenAiClient, messages: Array[ChatMessage]) -> OpenAiCompletion:
	for _turn in range(32): # Stop after 32 turns.
		var completion := await ai_client.async_chat_messages_stream(messages, AgentToolRegistry.schemas, ApiSetting.get_proxy_address(), func(_chunk: String, _stream_kind: String) -> void: pass)
		if completion.has_error() or completion.tool_calls.is_empty():
			return completion

		# Preserve the full turn because some providers validate tool-result messages against it.
		messages.append(ChatMessage.assistant_tool_calls(completion.tool_calls, completion.content, completion.reasoning_content))
		for tool_call: OpenAiToolCall in completion.tool_calls:
			var tool_name := tool_call.function.name
			var tool: AgentTool = AgentToolRegistry.tools.get(tool_name)
			var result: AgentToolResult
			if tool == null:
				result = AgentToolResult.error(StringUtils.format("unknown tool '{}'", tool_name))
			else:
				# Parse failures are returned to the model as tool errors so it can correct and retry.
				var args := tool.parse_args(tool_call.function.arguments)
				if args.has(AgentTool.ARG_PARSE_ERROR):
					result = AgentToolResult.error(str(args[AgentTool.ARG_PARSE_ERROR]))
				else:
					result = await tool.async_execute(args, ai_client.cancel_scope)
			messages.append(ChatMessage.tool_result(tool_call.id, result.content))

	var exhausted := OpenAiCompletion.new()
	exhausted.error = "compaction agent max turns exceeded"
	return exhausted
