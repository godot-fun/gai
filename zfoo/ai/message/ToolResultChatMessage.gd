class_name ToolResultChatMessage
extends ChatMessage

var tool_call_id: String = ""
var text: String = ""


func _init(_tool_call_id: String = "", _text: String = "") -> void:
	role = ROLE_TOOL
	tool_call_id = _tool_call_id
	text = _text
	pass


func to_api_dict() -> Dictionary:
	return {"role": role, "content": text, "tool_call_id": tool_call_id}


func deep_clone() -> ChatMessage:
	return ToolResultChatMessage.new(tool_call_id, text)


static func from_dict(data: Dictionary) -> ToolResultChatMessage:
	return ToolResultChatMessage.new(str(data.get("tool_call_id", "")), str(data.get("text", "")))
