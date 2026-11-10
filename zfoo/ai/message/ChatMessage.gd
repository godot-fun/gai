class_name ChatMessage
extends IJsonSerializable

const ROLE_SYSTEM := "system"
const ROLE_USER := "user"
const ROLE_ASSISTANT := "assistant"
const ROLE_TOOL := "tool"

## Set by subclasses in _init; persisted in session JSON.
var role: String = ""


func deep_clone() -> ChatMessage:
	return null


# ---------------------------------------------------------------------------
# JSON — [method serialize] is Chat Completions wire (also persisted via [method JsonUtils.object_to_json])
# ---------------------------------------------------------------------------

## Deserializes session or wire-shaped JSON into the subclass selected by [member role].
func deserialize(data: Dictionary) -> Variant:
	match str(data.get("role", "")):
		ROLE_SYSTEM:
			return SystemChatMessage.from_dict(data)
		ROLE_USER:
			return UserChatMessage.from_dict(data)
		ROLE_ASSISTANT:
			return AssistantChatMessage.from_dict(data)
		ROLE_TOOL:
			return ToolResultChatMessage.from_dict(data)
		_:
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


static func assistant_tool_calls(calls: Array[ToolCall], text: String = "", reasoning: String = "") -> AssistantChatMessage:
	var msg := AssistantChatMessage.new(text, reasoning)
	msg.tool_calls = calls
	return msg


static func tool_result(call_id: String, text: String) -> ToolResultChatMessage:
	return ToolResultChatMessage.new(call_id, text)
