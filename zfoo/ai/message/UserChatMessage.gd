class_name UserChatMessage
extends ChatMessage

const REMOTE_IMAGE_MAX_SIZE := Vector2i(1300, 1300)

var parts: Array[ChatUserPart] = []


func _init(_parts: Array[ChatUserPart] = []) -> void:
	role = ROLE_USER
	parts = _parts
	pass


func first_image_data_url() -> String:
	for part: ChatUserPart in parts:
		if part is UserImageUrlPart:
			return (part as UserImageUrlPart).image_url
	return StringUtils.EMPTY


func to_api_dict() -> Dictionary:
	if parts.size() == 1 and parts[0] is UserTextPart:
		return {"role": role, "content": (parts[0] as UserTextPart).text}
	var wire: Array = []
	for part: ChatUserPart in parts:
		if part != null:
			wire.append(part.to_api_dict())
	return {"role": role, "content": wire}


func deep_clone() -> ChatMessage:
	var cloned := UserChatMessage.new()
	cloned.parts.resize(parts.size())
	for index in parts.size():
		cloned.parts[index] = parts[index].deep_clone() if parts[index] != null else null
	return cloned


static func with_text(body: String) -> UserChatMessage:
	return UserChatMessage.new([ChatUserPart.text_part(body)])


static func with_text_and_data_url(body: String, data_url: String) -> UserChatMessage:
	var list: Array[ChatUserPart] = []
	if StringUtils.is_not_blank(body):
		list.append(ChatUserPart.text_part(body))
	list.append(ChatUserPart.image_url_part(data_url))
	return UserChatMessage.new(list)


## Builds a caption + image message from [param image_path], or a text-only message when encoding fails.
## The read / decode / downscale / re-encode pass runs on the worker pool: a multi-megapixel image costs
## seconds of CPU, so the main thread keeps rendering while it waits.
static func async_from_image_path(caption: String, image_path: String) -> UserChatMessage:
	var data_url := StringUtils.EMPTY
	var encoded: Variant = await ExecutorHelper.async_execute_pooled(encode_image_path_to_data_url.bind(image_path))
	if encoded is String:
		data_url = encoded
	if StringUtils.is_blank(data_url):
		return with_text(caption)
	var body := caption
	if StringUtils.is_blank(body):
		body = StringUtils.format("Image read: {}", image_path)
	return with_text_and_data_url(body, data_url)


## Reads, decodes, downscales, and re-encodes [param image_path] into a base64 data URL.
## Only touches thread-safe Godot APIs, so [method async_from_image_path] may run it on the worker pool.
static func encode_image_path_to_data_url(image_path: String) -> String:
	var image_bytes := FileUtils.read_file_to_byte_array(image_path)
	if image_bytes.is_empty():
		Log.info("UserChatMessage encode_image_path read failed or empty path:[{}]", image_path)
		return StringUtils.EMPTY
	# Signature sniffing picks the encoder without a full decode; exotic containers fall back to decoding.
	var image_format := ImageHelper.detect_image_format(image_bytes)
	if image_format.is_empty():
		var decoded_image := ImageHelper.decode_image(image_bytes)
		if decoded_image == null:
			Log.info("UserChatMessage encode_image_path decode failed path:[{}]", image_path)
			return StringUtils.EMPTY
		image_format = decoded_image.format
	var encoded_bytes: PackedByteArray
	var mime_subtype: String
	if image_format == ImageHelper.png or image_format == ImageHelper.svg:
		encoded_bytes = ImageHelper.convert_to_png_with_max_size(image_bytes, REMOTE_IMAGE_MAX_SIZE)
		mime_subtype = ImageHelper.png
	elif image_format == ImageHelper.webp:
		encoded_bytes = ImageHelper.convert_to_webp_with_max_size(image_bytes, REMOTE_IMAGE_MAX_SIZE)
		mime_subtype = ImageHelper.webp
	else:
		encoded_bytes = ImageHelper.convert_to_jpg_with_max_size(image_bytes, REMOTE_IMAGE_MAX_SIZE)
		mime_subtype = ImageHelper.jpeg
	if encoded_bytes.is_empty():
		Log.info("UserChatMessage encode_image_path encode failed path:[{}] format:[{}]", image_path, image_format)
		return StringUtils.EMPTY
	return StringUtils.format("data:image/{};base64,{}", mime_subtype, Marshalls.raw_to_base64(encoded_bytes))


static func from_dict(data: Dictionary) -> UserChatMessage:
	var parsed: Array[ChatUserPart] = []
	for item: Variant in data.get("parts", []):
		if item is ChatUserPart:
			parsed.append(item)
		elif typeof(item) == TYPE_DICTIONARY:
			var part := ChatUserPart.from_dict(item)
			if part != null:
				parsed.append(part)
	return UserChatMessage.new(parsed)
