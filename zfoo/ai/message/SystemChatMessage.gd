class_name SystemChatMessage
extends ChatMessage

var text: String = ""


func _init(_text: String = "") -> void:
	role = ROLE_SYSTEM
	text = _text
	pass


func validate() -> String:
	return StringUtils.EMPTY


func to_api_dict() -> Dictionary:
	return {"role": role, "content": text}


func deep_clone() -> ChatMessage:
	return SystemChatMessage.new(text)


static func from_dict(data: Dictionary) -> SystemChatMessage:
	return SystemChatMessage.new(str(data.get("text", "")))
