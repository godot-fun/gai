class_name UserImageUrlPart
extends ChatUserPart

var image_url: String = ""


func _init(_url: String = "") -> void:
	part_type = TYPE_IMAGE_URL
	image_url = _url
	pass


func validate() -> String:
	if StringUtils.is_blank(image_url):
		return "user image part requires image_url"
	return StringUtils.EMPTY


func to_api_dict() -> Dictionary:
	return {"type": part_type, "image_url": {"url": image_url}}


func deep_clone() -> ChatUserPart:
	return UserImageUrlPart.new(image_url)


static func from_dict(data: Dictionary) -> UserImageUrlPart:
	return UserImageUrlPart.new(str(data.get("image_url", "")))
