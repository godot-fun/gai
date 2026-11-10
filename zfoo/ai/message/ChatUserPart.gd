class_name ChatUserPart
extends IJsonSerializable

const TYPE_TEXT := "text"
const TYPE_IMAGE_URL := "image_url"

var part_type: String = ""


func deep_clone() -> ChatUserPart:
	return null


static func text_part(body: String) -> ChatUserPart:
	return UserTextPart.new(body)


static func image_url_part(url: String) -> ChatUserPart:
	return UserImageUrlPart.new(url)


static func from_dict(data: Dictionary) -> ChatUserPart:
	match str(data.get("part_type", "")):
		TYPE_TEXT:
			return UserTextPart.from_dict(data)
		TYPE_IMAGE_URL:
			return UserImageUrlPart.from_dict(data)
		_:
			return null
