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


static func system(text: String) -> ChatMessage:
	return ChatMessage.new(ROLE_SYSTEM, text)


static func user(text: String) -> ChatMessage:
	return ChatMessage.new(ROLE_USER, text)


static func user_image(text: String, image_path: String) -> ChatMessage:
	var msg := ChatMessage.new(ROLE_USER, text)
	var image_bytes := FileUtils.read_file_to_byte_array(image_path)
	var image_format := ImageHelper.detect_image_format(image_bytes)
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
		return msg
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


## OpenAI wire shape
func to_api_dict() -> Dictionary:
	if role == ROLE_TOOL:
		return {
			"role": role,
			"content": content,
			"tool_call_id": tool_call_id,
		}
	if not tool_calls.is_empty():
		var wire := {
			"role": role,
			"content": StringUtils.trim(content),
			"reasoning_content": StringUtils.trim(reasoning_content),
			"tool_calls": tool_calls,
		}
		return wire
	if role == ROLE_USER and StringUtils.is_not_blank(image_data_url):
		return {
			"role": role,
			"content": [
				{"type": "text", "text": content},
				{"type": "image_url", "image_url": {"url": image_data_url}},
			],
		}
	var wire := {
		"role": role,
		"content": content,
	}
	if role == ROLE_ASSISTANT and StringUtils.is_not_blank(reasoning_content):
		wire["reasoning_content"] = StringUtils.trim(reasoning_content)
	return wire
