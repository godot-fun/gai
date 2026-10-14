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

static func run(session_id: int) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var client := ApiSetting.get_client()
	client.cancel_scope = CancelScope.new()
	var messages: Array[ChatMessage] = []
	messages.assign(session.messages)
	messages.append(ChatMessage.user(PROMPT))
	var completion := await CompactionAgent.run(client, messages)
	if not completion.has_error():
		MemoryPrompt.reload_memory_context()
	pass


## Keeps system-level context while dropping user, assistant, tool, and previous summary turns.
static func collect_context_messages(messages: Array[ChatMessage]) -> Array[ChatMessage]:
	var context: Array[ChatMessage] = []
	for message: ChatMessage in messages:
		if message.role != ChatMessage.ROLE_SYSTEM:
			continue
		if message.content.begins_with(AgentCompactionManager.SUMMARY_PREFIX):
			continue
		context.append(message)
	return context
