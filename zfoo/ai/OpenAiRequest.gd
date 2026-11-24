class_name OpenAiRequest
extends RefCounted

## Chat completion request body for OpenAI-compatible APIs.

## DeepSeek V4 OpenAI-format thinking toggle (`thinking.type`). Empty omits the field (API default = enabled).
const THINKING_ENABLED := "enabled"
const THINKING_DISABLED := "disabled"
## Chat Completions `response_format.type`. Empty omits the field (API default = text).
const RESPONSE_FORMAT_JSON_OBJECT := "json_object"

var model: String = ""
var messages: Array[ChatMessage] = []
var stream: bool = false
var tools: Array[ToolDef] = []
var max_tokens: int = 0
## `enabled` / `disabled`, or empty to omit (provider default).
var thinking: String = ""
## `json_object`, or empty to omit (provider default text).
var response_format: String = ""


func _init(_model: String = "", _messages: Array[ChatMessage] = [], _stream: bool = false) -> void:
	model = _model
	messages = _messages
	stream = _stream
	pass


func to_json() -> String:
	var wire_messages := build_wire_messages()
	var body := {
		"model": model,
		"messages": wire_messages,
		"stream": stream,
	}
	if max_tokens > 0:
		body["max_tokens"] = max_tokens
	if not tools.is_empty():
		body["tools"] = tools
		body["tool_choice"] = "auto"
	if StringUtils.is_not_blank(thinking):
		body["thinking"] = {"type": thinking}
	if StringUtils.is_not_blank(response_format):
		body["response_format"] = {"type": response_format}
	return JsonUtils.object_to_json(body)


## Converts messages to their API shape. Qwen chat templates reject multiple system messages or
## a system message after a conversation turn, so their system messages become one leading entry.
func build_wire_messages() -> Array:
	if model.to_lower().contains("deepseek") || model.to_lower().contains("openai"):
		return messages.map(func(message: ChatMessage) -> Dictionary: return message.to_api_dict())
	var wire_messages: Array = []
	var system_parts := PackedStringArray()
	for message: ChatMessage in messages:
		if message is SystemChatMessage:
			var text := (message as SystemChatMessage).text.strip_edges()
			if StringUtils.is_not_blank(text):
				system_parts.append(text)
			continue
		wire_messages.append(message.to_api_dict())
	if not system_parts.is_empty():
		wire_messages.push_front({"role": ChatMessage.ROLE_SYSTEM, "content": "\n\n".join(system_parts)})
	return wire_messages
