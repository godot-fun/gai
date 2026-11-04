class_name CompactionPrompt
extends RefCounted

## Text protocol and model instructions for conversation compaction and durable memory maintenance.


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


## Strips [method build_summary_context] wrapping so memory maintenance receives plain summary text.
## Call only for content that already passed [method is_compaction_message].
static func extract_summary(compaction_content: String) -> String:
	return StringUtils.substring_after(compaction_content, SUMMARY_PREFIX).strip_edges()


# ---------------------------------------------------------------------------
# Memory
# ---------------------------------------------------------------------------

const MEMORY_PREFIX := "Previous compacted context:"

const MEMORY_UPDATE_REQUEST := """Update `.memory/` with information from this conversation that is worth keeping.

Work immediately without explaining or planning:
1. Read `.memory/README.md`.
2. If nothing is worth retaining, return `Done` without reading other files.
3. Otherwise, read only the directly relevant memory files and update them in place with the fewest tool calls.

Rewrite `focus.md` completely when the active task changes, and keep it short. Replace a standing fact or rule in `user.md`, `relationships.md`, or `goals.md` when a new statement supersedes it. Append to `experiences.md` without rewriting older entries; when a lesson becomes a standing rule, move the rule into `user.md` and leave a pointer. Do not store transcripts, secrets, or project implementation notes. Never create memory files beyond those listed in the index, and never edit outside `.memory/`. Return only `Done`."""


## Labels a prior summary so the memory-maintenance agent treats it as compacted history.
static func build_memory_context(summary: String) -> String:
	return MEMORY_PREFIX + FileUtils.NEWLINE_LF + summary
