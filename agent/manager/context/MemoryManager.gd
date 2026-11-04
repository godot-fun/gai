class_name MemoryManager
extends RefCounted

## Maintains durable workspace memory during context compaction.
##
## The dedicated message copy keeps this agent's prompt, tool calls, tool results, and final
## confirmation out of the summary request and persisted chat history.

static func update_memory(session_id: int) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var client := ApiSetting.get_client()
	client.cancel_scope = CancelScope.new()
	var memory_messages := collect_memory_messages(session.messages)
	memory_messages.append(ChatMessage.user(MemoryPrompt.MEMORY_UPDATE_REQUEST))
	var completion := await MemoryAgent.run(client, memory_messages)
	if not completion.has_error():
		MemoryPrompt.reload_memory_context()
	pass


## Builds the memory-maintenance transcript from user messages and visible model replies only.
## Previous summaries are retained because they represent conversation removed by an earlier
## compaction. System context, model thinking, tool calls, and tool results are discarded.
static func collect_memory_messages(messages: Array[ChatMessage]) -> Array[ChatMessage]:
	var transcript: Array[ChatMessage] = []
	for message: ChatMessage in messages:
		if CompactionPrompt.is_compaction_message(message):
			var summary := CompactionPrompt.extract_summary((message as SystemChatMessage).text)
			transcript.append(ChatMessage.user(MemoryPrompt.build_memory_context(summary)))
		elif message is UserChatMessage:
			var user := message as UserChatMessage
			var user_text := StringUtils.EMPTY
			for part: ChatUserPart in user.parts:
				if part is UserTextPart:
					var slice := (part as UserTextPart).text
					if StringUtils.is_not_blank(slice):
						user_text += slice
			if StringUtils.is_not_blank(user_text):
				transcript.append(ChatMessage.user(user_text.strip_edges()))
		elif message is AssistantChatMessage:
			var assistant_text := (message as AssistantChatMessage).text
			if StringUtils.is_not_blank(assistant_text):
				transcript.append(ChatMessage.assistant(assistant_text.strip_edges()))
	return transcript
