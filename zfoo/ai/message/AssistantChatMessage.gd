class_name AssistantChatMessage
extends ChatMessage

var text: String = ""
var reasoning_content: String = ""
var tool_calls: Array[ToolCall] = []


func _init(_text: String = "", _reasoning: String = "") -> void:
	role = ROLE_ASSISTANT
	text = _text
	reasoning_content = _reasoning
	pass


func to_api_dict() -> Dictionary:
	var wire := {"role": role, "content": StringUtils.trim(text)}
	if StringUtils.is_not_blank(reasoning_content):
		wire["reasoning_content"] = StringUtils.trim(reasoning_content)
	if not tool_calls.is_empty():
		wire["tool_calls"] = tool_calls
	return wire


func deep_clone() -> ChatMessage:
	var cloned := AssistantChatMessage.new(text, reasoning_content)
	cloned.tool_calls.resize(tool_calls.size())
	for index in tool_calls.size():
		if tool_calls[index] != null:
			cloned.tool_calls[index] = tool_calls[index].deep_clone()
	return cloned


static func from_dict(data: Dictionary) -> AssistantChatMessage:
	var msg := AssistantChatMessage.new(str(data.get("text", "")), str(data.get("reasoning_content", "")))
	msg.tool_calls = ToolCall.parse_list(data.get("tool_calls", []))
	return msg
