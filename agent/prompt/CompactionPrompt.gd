class_name CompactionPrompt
extends RefCounted

## Model instructions used by conversation compaction and durable memory maintenance.


const SUMMARY_PREFIX := "# Compacted conversation context"

const SUMMARY_REQUEST := """Create a compact continuation summary of the conversation above.

Preserve every detail needed to continue the work correctly, especially:
- the user's goals, constraints, and explicit preferences;
- decisions already made and their reasons;
- files changed and important implementation details;
- commands and tests run, including failures;
- unfinished work, blockers, and concrete next steps.

Do not address the user. Do not call tools. Return only the continuation summary."""

const MEMORY_UPDATE_REQUEST := """Update `.memory/` with durable, reusable information from this conversation.

Work immediately without explaining or planning:
1. Read `.memory/README.md`.
2. If nothing is worth retaining, return `Done` without reading other files.
3. Otherwise, read only the directly relevant memory files and update them in place with the fewest tool calls.

Avoid duplicates, transcripts, temporary details, and secrets. Keep `focus.md` short and current. Never edit outside `.memory/`. Return only `Done`."""


## Wraps a summary as the system context persisted after compaction.
static func build_summary_context(summary: String) -> String:
	return SUMMARY_PREFIX + FileUtils.NEWLINE_LF + summary


## Labels a prior summary so the memory-maintenance agent treats it as compacted history.
static func format_previous_context(summary: String) -> String:
	return "Previous compacted context:\n" + summary


## Returns whether [param message] is the system message persisted for a prior compaction.
static func is_compaction_message(message: ChatMessage) -> bool:
	return message.role == ChatMessage.ROLE_SYSTEM and message.content.begins_with(SUMMARY_PREFIX)
