class_name ChatBubbleFactory
extends Object

## Creates the transcript bubble matching a chat entry kind.

static var bubbles: Dictionary[String, Script] = {
	ChatEntry.KIND_SYSTEM: DefaultBubble,
	ChatEntry.KIND_SKILL: ContextBubble,
	ChatEntry.KIND_MEMORY: ContextBubble,
	ChatEntry.KIND_AGENT_PROMPT: ContextBubble,
	ChatEntry.KIND_USER: UserBubble,
	ChatEntry.KIND_THINKING: ThinkingBubble,
	ChatEntry.KIND_AGENT: AgentBubble,
	ChatEntry.KIND_TOOL: ToolBubble,
	ChatEntry.KIND_WEB_TOOL: WebToolBubble,
	ChatEntry.KIND_FILE_TOOL: FileBubble,
	ChatEntry.KIND_GIT_DIFF: GitDiffBubble,
	ChatEntry.KIND_RESULT: ResultBubble,
	ChatEntry.KIND_WEB: WebResultBubble,
	ChatEntry.KIND_ERROR: ErrorBubble,
	ChatEntry.KIND_COMPACTION: CompactionBubble,
}


static func append(chat_list: VBoxContainer, session_id: int, entry: ChatEntry) -> BubbleContainer:
	var bubble_script: Script = bubbles.get(entry.kind, DefaultBubble)
	var bubble := bubble_script.new() as BubbleContainer
	bubble.apply(session_id, entry)
	chat_list.add_child(bubble)
	return bubble
