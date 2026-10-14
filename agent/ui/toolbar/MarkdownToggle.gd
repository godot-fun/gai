class_name MarkdownToggle
extends RefCounted

## Shared Markdown rendering policy for chat bubbles.

## Conversation bubbles respect the toolbar setting; tool output stays plain text.
static func markdown_enabled_for_entry(entry: ChatEntry) -> bool:
	if entry.kind == ChatEntry.KIND_TOOL:
		return false
	return AgentSetting.get_markdown_enabled()
