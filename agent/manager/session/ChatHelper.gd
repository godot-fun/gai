class_name ChatHelper
extends Object

## OpenAI-compatible histories require every assistant `tool_calls[]` entry to be answered by a
## `tool` message right after it, so a run stopped or killed in the middle of a tool batch leaves a
## history the API rejects with 400. [method sanitize] repairs it.
##
## A valid history is only scanned, never rebuilt: the allocation happens when something is broken.

## Repairs the history in place, touching nothing before the first unpaired turn. A valid history
## is left alone.
static func sanitize(messages: Array[ChatMessage]) -> void:
	var start := broken_from(messages)
	if start < 0:
		return
	var repaired := rebuild_suffix(messages, start)
	messages.resize(start)
	messages.append_array(repaired)
	pass


## Index of the first message that is not part of a valid turn pairing, or -1 when the whole history
## pairs up. An assistant turn counts as valid only when exactly one result per tool call follows it,
## in tool_calls order.
static func broken_from(messages: Array[ChatMessage]) -> int:
	var index := 0
	while index < messages.size():
		var message: ChatMessage = messages[index]
		if message is ToolResultChatMessage:
			# A result is only valid right after its assistant turn.
			return index
		if not message is AssistantChatMessage:
			index += 1
			continue
		var turn := index
		index += 1
		for tool_call: ToolCall in (message as AssistantChatMessage).tool_calls:
			if index >= messages.size():
				return turn
			var answer: ChatMessage = messages[index]
			if not answer is ToolResultChatMessage:
				return turn
			if (answer as ToolResultChatMessage).tool_call_id != ToolHelper.resolve_tool_call_id(tool_call):
				return turn
			index += 1
	return -1


## Rebuilds the pairing from [param start]: one result per tool call in order, missing ones filled
## with a pi-style error result, orphan and duplicate results dropped.
static func rebuild_suffix(messages: Array[ChatMessage], start: int) -> Array[ChatMessage]:
	var repaired: Array[ChatMessage] = []
	var index := start
	while index < messages.size():
		var message: ChatMessage = messages[index]
		index += 1
		if message is ToolResultChatMessage:
			# Orphan result — its assistant turn is gone.
			continue
		repaired.append(message)
		if not message is AssistantChatMessage:
			continue
		var tool_calls := (message as AssistantChatMessage).tool_calls
		if tool_calls.is_empty():
			continue
		var answers: Dictionary[String, ToolResultChatMessage] = {}
		while index < messages.size() and messages[index] is ToolResultChatMessage:
			var answer := messages[index] as ToolResultChatMessage
			index += 1
			if not answers.has(answer.tool_call_id):
				answers[answer.tool_call_id] = answer
		for tool_call: ToolCall in tool_calls:
			var call_id := ToolHelper.resolve_tool_call_id(tool_call)
			var answer: ToolResultChatMessage = answers.get(call_id)
			if answer == null:
				# pi-style error result: name the call, state the reason, and say what to do next.
				var missing := 'Tool call "{}" did not complete: no result was recorded. Re-issue it only if its output is still needed.'
				repaired.append(ChatMessage.tool_result(call_id, StringUtils.format(missing, tool_call.function.name)))
				continue
			answers.erase(call_id)
			repaired.append(answer)
	return repaired
