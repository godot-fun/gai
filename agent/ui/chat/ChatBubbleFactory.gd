class_name ChatBubbleFactory
extends Object

## Creates the transcript bubble matching a chat entry kind.

static var bubble_types: Dictionary[String, Script] = {
	ChatEntry.KIND_SYSTEM: ContextBubble,
	ChatEntry.KIND_SKILL: ContextBubble,
	ChatEntry.KIND_MEMORY: ContextBubble,
	ChatEntry.KIND_AGENT_PROMPT: ContextBubble,
	ChatEntry.KIND_COMPACTION: ContextBubble,
	ChatEntry.KIND_USER: UserBubble,
	ChatEntry.KIND_THINKING: ThinkingBubble,
	ChatEntry.KIND_AGENT: AgentBubble,
	ChatEntry.KIND_TOOL: ToolBubble,
	ChatEntry.KIND_WEB_TOOL: WebToolBubble,
	ChatEntry.KIND_FILE_TOOL: FileBubble,
	ChatEntry.KIND_EXPLORER_TOOL: ExplorerBubble,
	ChatEntry.KIND_GIT_DIFF: GitDiffBubble,
	ChatEntry.KIND_RESULT: ResultBubble,
	ChatEntry.KIND_WEB: WebResultBubble,
	ChatEntry.KIND_ERROR: ErrorBubble,
}


static func _static_init() -> void:
	gdf.events.theme_changed.connect(refresh_panel_colors)
	gdf.events.theme_color_changed.connect(refresh_panel_colors)
	refresh_panel_colors()
	pass


static func append(chat_list: VBoxContainer, session_id: int, entry: ChatEntry) -> BubbleContainer:
	var bubble_script: Script = bubble_types.get(entry.kind, DefaultBubble)
	var bubble := bubble_script.new() as BubbleContainer
	bubble.apply(session_id, entry)
	chat_list.add_child(bubble)
	return bubble


# ---------------------------------------------------------------------------
# Bubble panel color cache
# ---------------------------------------------------------------------------

static var panel_colors: Dictionary[String, Color] = {}


## Resolves the same base color used by the chat bubble for an entry kind.
## Effects can pass the result through [VisualColor] for their own contrast treatment.
static func panel_color_for_entry(entry: ChatEntry) -> Color:
	return panel_color_for_kind(entry.kind)


static func panel_color_for_kind(entry_kind: String) -> Color:
	var color: Color = panel_colors.get(entry_kind, Colors.surface)
	return color


## Rebuild cached bubble panel colors whenever the active theme or accent changes.
## Calling each script's panel_color keeps this cache aligned with the bubble implementation.
static func refresh_panel_colors() -> void:
	panel_colors.clear()
	for entry_kind: String in bubble_types:
		var bubble_script: Script = bubble_types[entry_kind]
		var bubble := bubble_script.new() as BubbleContainer
		panel_colors[entry_kind] = bubble.panel_color()
		bubble.free()
	pass
