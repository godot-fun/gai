class_name AgentSetting
extends RefCounted

## Persisted agent preferences — notification behavior for finished runs plus the toolbar toggles
## (Jarvis orb, Markdown rendering, skill index / AGENTS.md prompts).
##
## Behavior lives in [AgentNotification] and the matching `agent/ui/toolbar` toggle; the fields are
## edited by [AgentSettingDialog].
##
## Setters that change something visible right away announce it on [AgentEvents].

# ----------------------------------------------------------------------------------------------------------------------
# Toolbar toggles
# ----------------------------------------------------------------------------------------------------------------------

## [VisualsButton] — show the 3D orb overlay while an agent run is working.
const JARVIS_ORB_ENABLED_KEY := "agent_jarvis_orb_enabled"
## [MarkdownToggle] — render chat bubble bodies as BBCode instead of raw text.
const MARKDOWN_ENABLED_KEY := "agent_markdown_enabled"
## [SkillToggle] — keep the skill index system message inside new sessions.
const SKILL_IN_PROMPT_ENABLED_KEY := "agent_skill_in_prompt_enabled"
## [AgentPromptToggle] — keep the AGENTS.md project prompt inside new sessions.
const AGENT_PROMPT_IN_PROMPT_ENABLED_KEY := "agent_agents_md_in_prompt_enabled"


static func get_jarvis_orb_enabled() -> bool:
	return Setting.get_bool(JARVIS_ORB_ENABLED_KEY, true)


## Announces the switch on [signal AgentEvents.events.jarvis_orb_changed] so the orb overlay can
## show / hide itself.
static func set_jarvis_orb_enabled(enabled: bool) -> void:
	if get_jarvis_orb_enabled() == enabled:
		return
	Setting.set_bool(JARVIS_ORB_ENABLED_KEY, enabled)
	Setting.save()
	AgentEvents.events.jarvis_orb_changed.emit(enabled)
	pass


static func get_markdown_enabled() -> bool:
	return Setting.get_bool(MARKDOWN_ENABLED_KEY, true)


## Announces the switch on [signal AgentEvents.events.markdown_changed] so open transcripts
## re-render their bubbles.
static func set_markdown_enabled(enabled: bool) -> void:
	if get_markdown_enabled() == enabled:
		return
	Setting.set_bool(MARKDOWN_ENABLED_KEY, enabled)
	Setting.save()
	AgentEvents.events.markdown_changed.emit(enabled)
	pass


static func get_skill_in_prompt_enabled() -> bool:
	return Setting.get_bool(SKILL_IN_PROMPT_ENABLED_KEY, true)


static func set_skill_in_prompt_enabled(enabled: bool) -> void:
	Setting.set_bool(SKILL_IN_PROMPT_ENABLED_KEY, enabled)
	Setting.save()
	pass


static func get_agent_prompt_in_prompt_enabled() -> bool:
	return Setting.get_bool(AGENT_PROMPT_IN_PROMPT_ENABLED_KEY, true)


static func set_agent_prompt_in_prompt_enabled(enabled: bool) -> void:
	Setting.set_bool(AGENT_PROMPT_IN_PROMPT_ENABLED_KEY, enabled)
	Setting.save()
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Notifications
# ----------------------------------------------------------------------------------------------------------------------

const NOTIFICATION_WINDOW_ENABLED_KEY := "agent_notification_window"
const NOTIFICATION_SOUND_ENABLED_KEY := "agent_notification_sound"
const NOTIFICATION_SOUND_SECONDS_KEY := "agent_notification_sound_seconds"
const NOTIFICATION_SOUND_FOLDER_KEY := "agent_notification_sound_folder"

const DEFAULT_SOUND_FOLDER := "res://test/asset/"
const DEFAULT_SOUND_SECONDS := 15
const MIN_SOUND_SECONDS := 1
const MAX_SOUND_SECONDS := 120


static func get_notification_window() -> bool:
	return Setting.get_bool(NOTIFICATION_WINDOW_ENABLED_KEY, true)


static func set_notification_window(enabled: bool) -> void:
	Setting.set_bool(NOTIFICATION_WINDOW_ENABLED_KEY, enabled)
	Setting.save()
	pass


static func get_notification_sound() -> bool:
	return Setting.get_bool(NOTIFICATION_SOUND_ENABLED_KEY, true)


static func set_notification_sound(enabled: bool) -> void:
	Setting.set_bool(NOTIFICATION_SOUND_ENABLED_KEY, enabled)
	Setting.save()
	pass


## Playback length in seconds — the clip is silenced once it elapses.
static func get_notification_sound_seconds() -> int:
	return clampi(Setting.get_int(NOTIFICATION_SOUND_SECONDS_KEY, DEFAULT_SOUND_SECONDS), MIN_SOUND_SECONDS, MAX_SOUND_SECONDS)


static func set_notification_sound_seconds(seconds: int) -> void:
	Setting.set_int(NOTIFICATION_SOUND_SECONDS_KEY, clampi(seconds, MIN_SOUND_SECONDS, MAX_SOUND_SECONDS))
	Setting.save()
	pass


## Folder holding the notification clips — a `res://` folder or any OS folder.
static func get_notification_sound_folder() -> String:
	return Setting.get_string(NOTIFICATION_SOUND_FOLDER_KEY, DEFAULT_SOUND_FOLDER).strip_edges()


static func set_notification_sound_folder(folder: String) -> void:
	Setting.set_string(NOTIFICATION_SOUND_FOLDER_KEY, folder.strip_edges())
	Setting.save()
	pass


# ----------------------------------------------------------------------------------------------------------------------
