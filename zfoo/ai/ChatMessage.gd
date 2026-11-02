class_name ChatMessage
extends RefCounted

const ROLE_SYSTEM := "system"
const ROLE_USER := "user"
const ROLE_ASSISTANT := "assistant"
const ROLE_TOOL := "tool"
const REMOTE_IMAGE_MAX_SIZE := Vector2i(1300, 1300)

var role: String = ""
var content: String = ""
var tool_call_id: String = ""
var tool_calls: Array[OpenAiToolCall] = []
## Thinking-mode output. Thinking models reject a tool-call turn that drops it.
var reasoning_content: String = ""
## Base64 data URL used by model-readable image context. Images are only valid in user messages.
var image_data_url: String = ""


func _init(_role: String = "", _content: String = "") -> void:
	role = _role
	content = _content
	pass


# ---------------------------------------------------------------------------
# Factories
# ---------------------------------------------------------------------------

static func system(text: String) -> ChatMessage:
	return ChatMessage.new(ROLE_SYSTEM, text)


static func user(text: String) -> ChatMessage:
	return ChatMessage.new(ROLE_USER, text)


static func user_image(text: String, image_path: String) -> ChatMessage:
	var msg := ChatMessage.new(ROLE_USER, text)
	var image_bytes := FileUtils.read_file_to_byte_array(image_path)
	if image_bytes.is_empty():
		Log.info("ChatMessage user_image read failed or file is empty path:[{}]", image_path)
		return msg
	var decoded_image := ImageHelper.decode_image(image_bytes)
	if decoded_image == null:
		Log.info("ChatMessage user_image decode failed path:[{}]", image_path)
		return msg
	var image_format := decoded_image.format
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
		mime_subtype = "jpeg"
	if encoded_bytes.is_empty():
		Log.info("ChatMessage user_image encode failed path:[{}] format:[{}]", image_path, image_format)
		return msg
	if StringUtils.is_blank(text):
		msg.content = StringUtils.format("Image read: {}", image_path)
	msg.image_data_url = StringUtils.format("data:image/{};base64,{}", mime_subtype, Marshalls.raw_to_base64(encoded_bytes))
	return msg


static func assistant(text: String, reasoning: String = "") -> ChatMessage:
	var msg := ChatMessage.new(ROLE_ASSISTANT, text)
	msg.reasoning_content = reasoning
	return msg


static func tool_result(call_id: String, text: String) -> ChatMessage:
	var msg := ChatMessage.new(ROLE_TOOL, text)
	msg.tool_call_id = call_id
	return msg


static func assistant_tool_calls(calls: Array[OpenAiToolCall], text: String = "", reasoning: String = "") -> ChatMessage:
	var msg := ChatMessage.new(ROLE_ASSISTANT, text)
	msg.tool_calls = calls
	msg.reasoning_content = reasoning
	return msg


## Empty when valid; otherwise a short reason the message cannot be sent to the API.
func validate() -> String:
	if StringUtils.is_blank(role):
		return "ChatMessage role is empty"
	match role:
		ROLE_SYSTEM:
			if StringUtils.is_not_blank(tool_call_id):
				return "system message must not set tool_call_id"
			if not tool_calls.is_empty():
				return "system message must not set tool_calls"
			if StringUtils.is_not_blank(reasoning_content):
				return "system message must not set reasoning_content"
			if StringUtils.is_not_blank(image_data_url):
				return "system message must not set image_data_url"
			return StringUtils.EMPTY
		ROLE_USER:
			if StringUtils.is_not_blank(tool_call_id):
				return "user message must not set tool_call_id"
			if not tool_calls.is_empty():
				return "user message must not set tool_calls"
			if StringUtils.is_not_blank(reasoning_content):
				return "user message must not set reasoning_content"
			return StringUtils.EMPTY
		ROLE_ASSISTANT:
			if StringUtils.is_not_blank(tool_call_id):
				return "assistant message must not set tool_call_id"
			if StringUtils.is_not_blank(image_data_url):
				return "assistant message must not set image_data_url"
			return StringUtils.EMPTY
		ROLE_TOOL:
			if StringUtils.is_not_blank(reasoning_content):
				return "tool message must not set reasoning_content"
			if StringUtils.is_not_blank(image_data_url):
				return "tool message must not set image_data_url"
			if not tool_calls.is_empty():
				return "tool message must not set tool_calls"
			if StringUtils.is_blank(tool_call_id):
				return "tool message requires tool_call_id"
			return StringUtils.EMPTY
		_:
			return StringUtils.format("ChatMessage has unknown role:[{}]", role)


## OpenAI wire shape
func to_api_dict() -> Dictionary:
	match role:
		ROLE_TOOL:
			return {
				"role": role,
				"content": content,
				"tool_call_id": tool_call_id,
			}
		ROLE_USER:
			if StringUtils.is_not_blank(image_data_url):
				return {
					"role": role,
					"content": [
						{"type": "text", "text": content},
						{"type": "image_url", "image_url": {"url": image_data_url}},
					],
				}
			return {"role": role, "content": content}
		ROLE_ASSISTANT:
			if not tool_calls.is_empty():
				var tool_wire := {
					"role": role,
					"content": StringUtils.trim(content),
					"tool_calls": tool_calls,
				}
				if StringUtils.is_not_blank(reasoning_content):
					tool_wire["reasoning_content"] = StringUtils.trim(reasoning_content)
				return tool_wire
			var assistant_wire := {"role": role, "content": content}
			if StringUtils.is_not_blank(reasoning_content):
				assistant_wire["reasoning_content"] = StringUtils.trim(reasoning_content)
			return assistant_wire
		_:
			return {"role": role, "content": content}


# ---------------------------------------------------------------------------
# Deep clone
# ---------------------------------------------------------------------------

func deep_clone() -> ChatMessage:
	var cloned := ChatMessage.new(role, content)
	cloned.tool_call_id = tool_call_id
	cloned.reasoning_content = reasoning_content
	cloned.image_data_url = image_data_url
	cloned.tool_calls.resize(tool_calls.size())
	for index in tool_calls.size():
		if tool_calls[index] == null:
			continue
		cloned.tool_calls[index] = tool_calls[index].deep_clone()
	return cloned
