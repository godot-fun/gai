class_name MemoryManager
extends RefCounted

## Maintains durable workspace memory during context compaction.
##
## The dedicated message copy keeps this agent's prompt, tool calls, tool results, and final
## confirmation out of the summary request and persisted chat history.

const PROMPT := """Update the workspace memory when the conversation contains information worth retaining.

- Read `.memory/README.md` first and follow its operating rules.
- Read only the memory files relevant to this conversation.
- Use the available file tools to update the appropriate files under `.memory/`.
- Update existing entries instead of creating duplicates.
- Keep `focus.md` short and current.
- Store durable, reusable information only; do not store a conversation transcript.
- Never store passwords, access tokens, private keys, or other secrets.
- Do not edit files outside `.memory/` during this task.

After all useful memory updates are complete, return a brief confirmation."""

static func update_memory(session_id: int) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var client := ApiSetting.get_client()
	client.cancel_scope = CancelScope.new()
	var memory_messages := collect_memory_messages(session.messages)
	memory_messages.append(ChatMessage.user(PROMPT))
	var completion := await CompactionAgent.run(client, memory_messages)
	if not completion.has_error():
		MemoryPrompt.reload_memory_context()
	pass


## Builds the memory-maintenance transcript from user messages and visible model replies only.
## Previous summaries are retained because they represent conversation removed by an earlier
## compaction. System context, model thinking, tool calls, and tool results are discarded.
static func collect_memory_messages(messages: Array[ChatMessage]) -> Array[ChatMessage]:
	var transcript: Array[ChatMessage] = []
	for message: ChatMessage in messages:
		if (message.role == ChatMessage.ROLE_SYSTEM and message.content.begins_with(CompactionManager.SUMMARY_PREFIX)):
			transcript.append(ChatMessage.user("Previous compacted context:\n" + message.content))
		elif message.role == ChatMessage.ROLE_USER and StringUtils.is_not_blank(message.content):
			transcript.append(ChatMessage.user(message.content.strip_edges()))
		elif message.role == ChatMessage.ROLE_ASSISTANT and StringUtils.is_not_blank(message.content):
			transcript.append(ChatMessage.assistant(message.content.strip_edges()))
	return transcript
