class_name VisualChatSentenceCursor
extends RefCounted

## Incrementally reads complete sentences from live session transcripts. Each session
## owns a shared cursor, so concurrent effects continue from the correct transcript.


# ---------------------------------------------------------------------------
# Value objects
# ---------------------------------------------------------------------------

class VisualChatSentence:
	extends RefCounted

	var text: String
	var next_index: int


	func _init(sentence_text: String = "", sentence_next_index: int = 0) -> void:
		text = sentence_text
		next_index = sentence_next_index
		pass


# ---------------------------------------------------------------------------
# Instance state
# ---------------------------------------------------------------------------

var chat_entry_index: int = 0
var entry_char_index: int = 0


# ---------------------------------------------------------------------------
# Instance cursor operations
# ---------------------------------------------------------------------------


func reset(entries: Array[ChatEntry]) -> void:
	chat_entry_index = find_latest_user_entry(entries)
	entry_char_index = 0
	pass


## Returns the next complete sentence, or an empty string while the current entry
## still has an unfinished tail. Later calls continue from the same two indices.
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


# ---------------------------------------------------------------------------
# Shared session cursor cache
# ---------------------------------------------------------------------------

static var session_cursors: Dictionary[int, VisualChatSentenceCursor] = {}


static func take_next_from_session(session_id: int) -> String:
	var session: AgentSession = AgentSessionStore.load_session(session_id)
	if session == null:
		remove_session(session_id)
		return ""
	var has_cursor := session_cursors.has(session_id)
	var cursor := get_or_create_cursor(session_id)
	if not has_cursor:
		cursor.reset(session.chat_entries)
	return cursor.take_next(session.chat_entries)


static func remove_session(session_id: int) -> void:
	session_cursors.erase(session_id)
	pass


static func get_or_create_cursor(session_id: int) -> VisualChatSentenceCursor:
	var cursor: VisualChatSentenceCursor = session_cursors.get(session_id)
	if cursor == null:
		cursor = VisualChatSentenceCursor.new()
		session_cursors[session_id] = cursor
	return cursor


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
