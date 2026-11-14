class_name AgentPrompt
extends RefCounted

## Project prompt — loads the workspace-root AGENTS.md once and caches its text.
## The text is appended to a session right after the system prompt (messages[0]); it is
## identified by [SystemChatMessage] text so the AGENTS.md text never has to be re-read for matching.
## [method reload_agent_context] re-reads the file, so a new session picks up an edited
## AGENTS.md without restarting the app.


const AGENTS_PATH := "AGENTS.md"

static var agent_context: String = ""


static func _static_init() -> void:
	reload_agent_context()
	pass


static func reload_agent_context() -> String:
	agent_context = ""
	var path := AgentWorkspace.resolve_path(AGENTS_PATH)
	if FileAccess.file_exists(path):
		agent_context = FileUtils.read_file_to_string(path)
	return agent_context


static func get_agent_context() -> String:
	return agent_context

static func has_agent_context() -> bool:
	return StringUtils.is_not_blank(agent_context)


static func is_agent_context_message(msg: ChatMessage) -> bool:
	return msg is SystemChatMessage and (msg as SystemChatMessage).text == agent_context
