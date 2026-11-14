class_name SkillPrompt
extends RefCounted

## Skill index prompt — loads the workspace-root SKILLS.md once and caches its text.
## The index is appended to a session right after the system prompt (messages[0]); it is
## identified by [SystemChatMessage] text so the skill index text never has to be re-read for
## matching. [method reload_skill_context] re-reads the file, so a new session picks up an edited
## SKILLS.md without restarting the app.


const SKILLS_PATH := "SKILLS.md"

static var skill_context: String = ""


static func _static_init() -> void:
	reload_skill_context()
	pass


static func reload_skill_context() -> String:
	skill_context = ""
	var path := AgentWorkspace.resolve_path(SKILLS_PATH)
	if FileAccess.file_exists(path):
		skill_context = FileUtils.read_file_to_string(path)
	return skill_context


static func get_skill_context() -> String:
	return skill_context

static func has_skill_context() -> bool:
	return StringUtils.is_not_blank(skill_context)


static func is_skill_context_message(msg: ChatMessage) -> bool:
	return msg is SystemChatMessage and (msg as SystemChatMessage).text == skill_context
