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
var tools: Array[OpenAiToolDef] = []
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
	return JsonUtils.object_to_json(to_api_dict())


## OpenAI wire shape — only include optional fields when they are used.
func to_api_dict() -> Dictionary:
	var wire_messages: Array = []
	for message: ChatMessage in messages:
		wire_messages.append(message.to_api_dict())
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
	return body
