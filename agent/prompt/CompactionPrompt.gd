class_name CompactionPrompt
extends RefCounted

## Text protocol and model instructions for conversation compaction.


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

const SUMMARY_PREFIX := "# Compacted conversation context"

const SUMMARY_REQUEST := """Create a compact continuation summary of the conversation above.

Preserve every detail needed to continue the work correctly, especially:
- the user's goals, constraints, and explicit preferences;
- decisions already made and their reasons;
- files changed and important implementation details;
- commands and tests run, including failures;
- unfinished work, blockers, and concrete next steps.

Do not address the user. Do not call tools. Return only the continuation summary."""

## Wraps a summary as the system context persisted after compaction.
static func build_summary_context(summary: String) -> String:
	return SUMMARY_PREFIX + FileUtils.NEWLINE_LF + summary

## Returns whether [param message] is the system message persisted for a prior compaction.
static func is_compaction_message(message: ChatMessage) -> bool:
	return message is SystemChatMessage and (message as SystemChatMessage).text.begins_with(SUMMARY_PREFIX)


## Strips [method build_summary_context] wrapping so the caller receives plain summary text.
## Call only for content that already passed [method is_compaction_message].
static func extract_summary(compaction_content: String) -> String:
	return StringUtils.substring_after(compaction_content, SUMMARY_PREFIX).strip_edges()
