## Unit coverage for sanitizing tool_call / tool message pairing in chat history.

static func missing_tool_result_is_filled_test() -> void:
	var read_call := ToolCall.new()
	read_call.id = "call-1"
	read_call.function.name = "read"
	var grep_call := ToolCall.new()
	grep_call.id = "call-2"
	grep_call.function.name = "grep"
	var messages: Array[ChatMessage] = [
		ChatMessage.system("system"),
		ChatMessage.user("question"),
		ChatMessage.assistant_tool_calls([read_call, grep_call], ""),
		ChatMessage.tool_result("call-1", "ok"),
	]
	ChatHelper.sanitize(messages)
	assert(messages.size() == 5)
	assert((messages[3] as ToolResultChatMessage).tool_call_id == "call-1")
	assert((messages[3] as ToolResultChatMessage).text == "ok")
	assert((messages[4] as ToolResultChatMessage).tool_call_id == "call-2")
	assert((messages[4] as ToolResultChatMessage).text == 'Tool call "grep" did not complete: no result was recorded. Re-issue it only if its output is still needed.')
	# A repaired history is stable.
	ChatHelper.sanitize(messages)
	assert(messages.size() == 5)
	pass


static func orphan_duplicate_and_unmatched_results_are_dropped_test() -> void:
	var read_call := ToolCall.new()
	read_call.id = "call-1"
	read_call.function.name = "read"
	var messages: Array[ChatMessage] = [
		ChatMessage.tool_result("call-9", "orphan before any tool_calls"),
		ChatMessage.assistant_tool_calls([read_call], ""),
		ChatMessage.tool_result("call-1", "ok"),
		ChatMessage.tool_result("call-1", "duplicate"),
		ChatMessage.tool_result("call-7", "no matching tool_call"),
	]
	ChatHelper.sanitize(messages)
	assert(messages.size() == 2)
	assert(messages[0] is AssistantChatMessage)
	assert((messages[1] as ToolResultChatMessage).tool_call_id == "call-1")
	assert((messages[1] as ToolResultChatMessage).text == "ok")
	pass


static func blank_tool_call_id_falls_back_to_function_name_test() -> void:
	var nameless_call := ToolCall.new()
	nameless_call.function.name = "bash"
	var messages: Array[ChatMessage] = [
		ChatMessage.assistant_tool_calls([nameless_call], ""),
		ChatMessage.tool_result("bash", "done"),
	]
	assert(ToolHelper.resolve_tool_call_id(nameless_call) == "bash")
	ChatHelper.sanitize(messages)
	assert(messages.size() == 2)
	pass


static func valid_history_is_scanned_not_rebuilt_test() -> void:
	var read_call := ToolCall.new()
	read_call.id = "call-1"
	read_call.function.name = "read"
	var messages: Array[ChatMessage] = [
		ChatMessage.system("system"),
		ChatMessage.user("question"),
		ChatMessage.assistant_tool_calls([read_call], ""),
		ChatMessage.tool_result("call-1", "ok"),
	]
	var before := messages.duplicate()
	assert(ChatHelper.broken_from(messages) == -1)
	ChatHelper.sanitize(messages)
	assert(messages == before)
	pass


static func only_the_broken_tail_is_rebuilt_test() -> void:
	var first_call := ToolCall.new()
	first_call.id = "call-1"
	first_call.function.name = "read"
	var second_call := ToolCall.new()
	second_call.id = "call-2"
	second_call.function.name = "grep"
	var system_message := ChatMessage.system("system")
	var user_message := ChatMessage.user("question")
	var first_assistant := ChatMessage.assistant_tool_calls([first_call], "")
	var first_result := ChatMessage.tool_result("call-1", "ok")
	var second_assistant := ChatMessage.assistant_tool_calls([second_call], "")
	var messages: Array[ChatMessage] = [system_message, user_message, first_assistant, first_result, second_assistant]
	assert(ChatHelper.broken_from(messages) == 4)
	ChatHelper.sanitize(messages)
	assert(messages.size() == 6)
	assert(messages[0] == system_message)
	assert(messages[1] == user_message)
	assert(messages[2] == first_assistant)
	assert(messages[3] == first_result)
	assert((messages[5] as ToolResultChatMessage).tool_call_id == "call-2")
	assert(messages[4] == second_assistant)
	pass
