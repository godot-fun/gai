class_name VisualChatSentenceCursor
extends RefCounted

## Incrementally reads complete sentences from a live session transcript. The two
## indices remain stable while the final ChatEntry grows during streaming.

class VisualChatSentence:
	extends RefCounted

	var text: String
	var next_index: int


	func _init(sentence_text: String = "", sentence_next_index: int = 0) -> void:
		text = sentence_text
		next_index = sentence_next_index
		pass

var chat_entry_index: int = 0
var entry_char_index: int = 0


func reset_for_session(session_id: int) -> void:
	var session: AgentSession = AgentSessionStore.load_session(session_id)
	if session == null:
		clear()
		return
	chat_entry_index = find_latest_user_entry(session.chat_entries)
	entry_char_index = 0
	pass


func clear() -> void:
	chat_entry_index = 0
	entry_char_index = 0
	pass


## Returns the next complete sentence, or an empty string while the current entry
## still has an unfinished tail. Later calls continue from the same two indices.
func take_next_from_session(session_id: int) -> String:
	var session: AgentSession = AgentSessionStore.load_session(session_id)
	if session == null:
		return ""
	return take_next(session.chat_entries)


func take_next(entries: Array[ChatEntry]) -> String:
	while chat_entry_index < entries.size():
		var entry: ChatEntry = entries[chat_entry_index]
		var sentence: VisualChatSentence = take_sentence(entry.body, entry_char_index)
		var text := sentence.text
		entry_char_index = sentence.next_index
		if not text.is_empty():
			return text
		if chat_entry_index == entries.size() - 1:
			return ""
		chat_entry_index += 1
		entry_char_index = 0
	return ""


static func find_latest_user_entry(entries: Array[ChatEntry]) -> int:
	for index in range(entries.size() - 1, -1, -1):
		if entries[index].kind == ChatEntry.KIND_USER:
			return index
	return entries.size()


## Returns one complete sentence at [param start_index]. An unfinished tail is
## intentionally left unconsumed so a streaming ChatEntry can complete it later.
static func take_sentence(text: String, start_index: int) -> VisualChatSentence:
	var start := clampi(start_index, 0, text.length())
	while start < text.length() and text.substr(start, 1).strip_edges().is_empty():
		start += 1
	for index in range(start, text.length()):
		if not StringUtils.is_sentence_end(text.substr(start, index - start + 1)):
			continue
		return VisualChatSentence.new(text.substr(start, index - start + 1).strip_edges(), index + 1)
	return VisualChatSentence.new("", start)
