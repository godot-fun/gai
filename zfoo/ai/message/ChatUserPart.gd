class_name ChatUserPart
extends RefCounted

const TYPE_TEXT := "text"
const TYPE_IMAGE_URL := "image_url"

var part_type: String = ""


func get_part_type() -> String:
	return part_type


func validate() -> String:
	return "ChatUserPart base is invalid"


func to_api_dict() -> Dictionary:
	return {}


func deep_clone() -> ChatUserPart:
	return null


static func text_part(body: String) -> ChatUserPart:
	return UserTextPart.new(body)


static func image_url_part(url: String) -> ChatUserPart:
	return UserImageUrlPart.new(url)


static func from_dict(data: Dictionary) -> ChatUserPart:
	var type_id := str(data.get("part_type", data.get("type", "")))
	match type_id:
		TYPE_TEXT:
			return UserTextPart.from_dict(data)
		TYPE_IMAGE_URL:
			return UserImageUrlPart.from_dict(data)
		_:
			return null
