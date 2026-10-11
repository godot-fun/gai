class_name OpenAiCompletion
extends RefCounted

## Result of a chat completion that may include tool calls.

var content: String = ""
## Thinking-mode output. Must be sent back with assistant tool-call messages.
var reasoning_content: String = ""
var tool_calls: Array[OpenAiToolCall] = []
## Why the model stopped (OpenAI `finish_reason`); empty when the provider never sent one. The client
## reports a value the loop cannot act on through [member error] (truncation, content filter, unknown).
var finish_reason: String = ""
var error: String = ""
var usage: OpenAiUsage = OpenAiUsage.new()


func has_error() -> bool:
	return StringUtils.is_not_blank(error)
