class_name ChatMessage
extends RefCounted

const ROLE_SYSTEM := "system"
const ROLE_USER := "user"
const ROLE_ASSISTANT := "assistant"
const ROLE_TOOL := "tool"

## Set by subclasses in _init; shared with get_role() and session JSON.
var role: String = ""


func get_role() -> String:
	return role


func validate() -> String:
	if StringUtils.is_blank(role):
		return "ChatMessage role is empty"
	return "ChatMessage base cannot be sent"


func to_api_dict() -> Dictionary:
	return {}


func deep_clone() -> ChatMessage:
	return null


# ---------------------------------------------------------------------------
# Factories
# ---------------------------------------------------------------------------

static func system(text: String) -> SystemChatMessage:
	return SystemChatMessage.new(text)


static func user(text: String) -> UserChatMessage:
	return UserChatMessage.with_text(text)


static func user_image(text: String, image_path: String) -> UserChatMessage:
	return UserChatMessage.from_image_path(text, image_path)


static func assistant(text: String, reasoning: String = "") -> AssistantChatMessage:
	return AssistantChatMessage.new(text, reasoning)


static func assistant_tool_calls(calls: Array[OpenAiToolCall], text: String = "", reasoning: String = "") -> AssistantChatMessage:
	var msg := AssistantChatMessage.new(text, reasoning)
	msg.tool_calls = calls
	return msg


static func tool_result(call_id: String, text: String) -> ToolResultChatMessage:
	return ToolResultChatMessage.new(call_id, text)

