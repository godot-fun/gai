class_name MemoryPrompt
extends RefCounted

## Project memory prompt — loads the workspace-root MEMORY.md once and caches its text.
## The index is appended to a session last, after the skill index; it is
## identified by [SystemChatMessage] text so it can be removed without disturbing other messages.
## [method reload_memory_context] re-reads the file, so a new session picks up an edited
## MEMORY.md without restarting the app.
## Also owns the text protocol for durable memory maintenance during compaction.


const MEMORY_PATH := "MEMORY.md"

static var memory_context: String = ""


static func _static_init() -> void:
	reload_memory_context()
	pass


static func reload_memory_context() -> String:
	memory_context = ""
	var path := AgentWorkspace.resolve_path(MEMORY_PATH)
	if FileAccess.file_exists(path):
		memory_context = FileUtils.read_file_to_string(path)
	return memory_context


static func get_memory_context() -> String:
	return memory_context

static func has_memory_context() -> bool:
	return StringUtils.is_not_blank(memory_context)


static func is_memory_context_message(msg: ChatMessage) -> bool:
	return msg is SystemChatMessage and (msg as SystemChatMessage).text == memory_context


# ---------------------------------------------------------------------------
# Maintenance
# ---------------------------------------------------------------------------

const MEMORY_PREFIX := "Previous compacted context:"

const MEMORY_UPDATE_REQUEST := """Update `.memory/` with information from this conversation that is worth keeping.

Work immediately without explaining or planning:
1. Read `MEMORY.md`.
2. If nothing is worth retaining, return `Done` without reading other files.
3. Otherwise, read only the directly relevant memory files and update them in place with the fewest tool calls.

Rewrite `focus.md` completely when the active task changes, and keep it short. Replace a standing fact or rule in `user.md`, `relationships.md`, or `goals.md` when a new statement supersedes it. Append to `experiences.md` without rewriting older entries; when a lesson becomes a standing rule, move the rule into `user.md` and leave a pointer. Do not store transcripts, secrets, or project implementation notes. Never create memory files beyond those listed in the index, and never edit outside `.memory/`. Return only `Done`."""


## Labels a prior summary so the memory-maintenance agent treats it as compacted history.
static func build_memory_context(summary: String) -> String:
	return MEMORY_PREFIX + FileUtils.NEWLINE_LF + summary
