class_name AgentSession
extends RefCounted

## Single conversation session — LLM history and UI transcript.

var id: int = -1
var messages: Array[ChatMessage] = []
var chat_entries: Array[ChatEntry] = []
## Per-session composer text, restored when the user switches back to this chat.
var draft_text: String = ""
## User messages waiting for their turn. Only the active item enters model history.
var pending_messages: Array[String] = []
## Latest LLM request usage; prompt_tokens is the current context length.
var usage: OpenAiUsage = OpenAiUsage.new()


func _init(_id: int = -1) -> void:
	id = _id
	pass
