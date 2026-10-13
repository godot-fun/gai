class_name MemoryPrompt
extends RefCounted

## Project memory prompt — loads the workspace memory index once and caches its text.
## The file text is appended to a session as a context message and is identified by
## role + content so it can be removed without disturbing other system messages.


const MEMORY_README_PATH := ".memory/README.md"

static var memory_context: String = ""


static func _static_init() -> void:
	var path := AgentWorkspace.resolve_path(MEMORY_README_PATH)
	if not FileAccess.file_exists(path):
		return
	memory_context = FileUtils.read_file_to_string(path)
	pass


static func get_memory_context() -> String:
	return memory_context


static func has_memory_context() -> bool:
	return StringUtils.is_not_blank(memory_context)


static func is_memory_context_message(msg: ChatMessage) -> bool:
	return msg.role == ChatMessage.ROLE_SYSTEM && msg.content == memory_context
