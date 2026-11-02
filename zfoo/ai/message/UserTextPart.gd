class_name UserTextPart
extends ChatUserPart

var text: String = ""


func _init(_text: String = "") -> void:
	part_type = TYPE_TEXT
	text = _text
	pass


func to_api_dict() -> Dictionary:
	return {"type": part_type, "text": text}


func deep_clone() -> ChatUserPart:
	return UserTextPart.new(text)


static func from_dict(data: Dictionary) -> UserTextPart:
	return UserTextPart.new(str(data.get("text", "")))
