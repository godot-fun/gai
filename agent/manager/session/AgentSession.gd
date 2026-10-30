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


# ---------------------------------------------------------------------------
# Deep clone
# ---------------------------------------------------------------------------

## Creates a structurally independent snapshot without JSON/reflection overhead.
## Strings are immutable copy-on-write values, so assigning them is both safe and cheap.
func deep_clone() -> AgentSession:
	var cloned := AgentSession.new(id)
	cloned.messages.resize(messages.size())
	for index in messages.size():
		if messages[index] == null:
			continue
		cloned.messages[index] = messages[index].deep_clone()
	cloned.chat_entries.resize(chat_entries.size())
	for index in chat_entries.size():
		if chat_entries[index] == null:
			continue
		cloned.chat_entries[index] = chat_entries[index].deep_clone()
	cloned.draft_text = draft_text
	cloned.pending_messages.assign(pending_messages)
	cloned.usage.copy_from(usage)
	return cloned
