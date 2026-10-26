class_name AgentSetting
extends RefCounted

## Persisted agent preferences — notification behavior for finished runs plus the toolbar toggles
## (Jarvis orb, Markdown rendering, skill index / memory / AGENTS.md prompts).
##
## Behavior lives in [AgentNotification] and the matching `agent/ui/toolbar` toggle; the fields are
## edited by [AgentSettingWindow].
##
## Setters that change an already rendered UI announce it on [AgentEvents].

# ----------------------------------------------------------------------------------------------------------------------
# Toolbar toggles
# ----------------------------------------------------------------------------------------------------------------------

# ------------------------------------------------ Visual presentation ------------------------------------------------

## [VisualsButton] — visual presentation id persisted as int (default matches Jarvis).
const VISUAL_TYPE_KEY := "agent_visual_type"
static func get_visual_type() -> int:
	return Setting.get_int(VISUAL_TYPE_KEY, 1)


static func set_visual_type(visual_type: int) -> void:
	if get_visual_type() == visual_type:
		return
	Setting.set_int(VISUAL_TYPE_KEY, visual_type)
	Setting.save()
	pass


# ------------------------------------------------ Markdown rendering ------------------------------------------------

## Render chat bubble bodies as BBCode instead of raw text.
const MARKDOWN_ENABLED_KEY := "agent_markdown_enabled"


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


# ---------------------------------------------------- Skill prompt ----------------------------------------------------

## [SkillToggle] — keep the skill index system message inside new sessions.
const SKILL_IN_PROMPT_ENABLED_KEY := "agent_skill_in_prompt_enabled"


static func get_skill_in_prompt_enabled() -> bool:
	return Setting.get_bool(SKILL_IN_PROMPT_ENABLED_KEY, true)


static func set_skill_in_prompt_enabled(enabled: bool) -> void:
	Setting.set_bool(SKILL_IN_PROMPT_ENABLED_KEY, enabled)
	Setting.save()
	pass


# --------------------------------------------------- Memory prompt ----------------------------------------------------

## [MemoryToggle] — keep the project memory index inside new sessions.
const MEMORY_IN_PROMPT_ENABLED_KEY := "agent_memory_in_prompt_enabled"


static func get_memory_in_prompt_enabled() -> bool:
	return Setting.get_bool(MEMORY_IN_PROMPT_ENABLED_KEY, true)


static func set_memory_in_prompt_enabled(enabled: bool) -> void:
	Setting.set_bool(MEMORY_IN_PROMPT_ENABLED_KEY, enabled)
	Setting.save()
	pass


# -------------------------------------------------- AGENTS.md prompt -------------------------------------------------

## [AgentPromptToggle] — keep the AGENTS.md project prompt inside new sessions.
const AGENT_PROMPT_IN_PROMPT_ENABLED_KEY := "agent_agents_md_in_prompt_enabled"


static func get_agent_prompt_in_prompt_enabled() -> bool:
	return Setting.get_bool(AGENT_PROMPT_IN_PROMPT_ENABLED_KEY, true)


static func set_agent_prompt_in_prompt_enabled(enabled: bool) -> void:
	Setting.set_bool(AGENT_PROMPT_IN_PROMPT_ENABLED_KEY, enabled)
	Setting.save()
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Agent behavior
# ----------------------------------------------------------------------------------------------------------------------

# ------------------------------------------------ Browser headless mode -----------------------------------------------

const BROWSER_HEADLESS_KEY := "browser_headless"

static func get_browser_headless() -> bool:
	return Setting.get_bool(BROWSER_HEADLESS_KEY, true)


static func set_browser_headless(enabled: bool) -> void:
	Setting.set_bool(BROWSER_HEADLESS_KEY, enabled)
	Setting.save()
	pass


# --------------------------------------------- Remote image recognition ----------------------------------------------

const READ_IMAGE_WITH_API_KEY := "agent_read_image_with_api"


## Uses the configured OpenAI-compatible API for image understanding; disable for local MiniCPM-V.
static func get_read_image_with_api() -> bool:
	return Setting.get_bool(READ_IMAGE_WITH_API_KEY, true)


static func set_read_image_with_api(enabled: bool) -> void:
	Setting.set_bool(READ_IMAGE_WITH_API_KEY, enabled)
	Setting.save()
	pass


# ----------------------------------------------- Maximum agent turns -------------------------------------------------

const MAX_TURNS_KEY := "agent_max_turns"
const DEFAULT_MAX_TURNS := 64
const MIN_MAX_TURNS := 1
const MAX_MAX_TURNS := 256


## Maximum number of model/tool rounds allowed in a single agent run.
static func get_max_turns() -> int:
	return clampi(Setting.get_int(MAX_TURNS_KEY, DEFAULT_MAX_TURNS), MIN_MAX_TURNS, MAX_MAX_TURNS)


static func set_max_turns(turns: int) -> void:
	Setting.set_int(MAX_TURNS_KEY, clampi(turns, MIN_MAX_TURNS, MAX_MAX_TURNS))
	Setting.save()
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Notifications
# ----------------------------------------------------------------------------------------------------------------------

# ------------------------------------------------ Notification window -------------------------------------------------

const NOTIFICATION_WINDOW_ENABLED_KEY := "agent_notification_window"

static func get_notification_window() -> bool:
	return Setting.get_bool(NOTIFICATION_WINDOW_ENABLED_KEY, true)


static func set_notification_window(enabled: bool) -> void:
	Setting.set_bool(NOTIFICATION_WINDOW_ENABLED_KEY, enabled)
	Setting.save()
	pass


# ------------------------------------------------- Notification sound -------------------------------------------------

const NOTIFICATION_SOUND_ENABLED_KEY := "agent_notification_sound"


static func get_notification_sound() -> bool:
	return Setting.get_bool(NOTIFICATION_SOUND_ENABLED_KEY, true)


static func set_notification_sound(enabled: bool) -> void:
	Setting.set_bool(NOTIFICATION_SOUND_ENABLED_KEY, enabled)
	Setting.save()
	pass


# -------------------------------------------- Notification sound duration --------------------------------------------

const NOTIFICATION_SOUND_SECONDS_KEY := "agent_notification_sound_seconds"
const DEFAULT_SOUND_SECONDS := 15
const MIN_SOUND_SECONDS := 1
const MAX_SOUND_SECONDS := 120


## Playback length in seconds — the clip is silenced once it elapses.
static func get_notification_sound_seconds() -> int:
	return clampi(Setting.get_int(NOTIFICATION_SOUND_SECONDS_KEY, DEFAULT_SOUND_SECONDS), MIN_SOUND_SECONDS, MAX_SOUND_SECONDS)


static func set_notification_sound_seconds(seconds: int) -> void:
	Setting.set_int(NOTIFICATION_SOUND_SECONDS_KEY, clampi(seconds, MIN_SOUND_SECONDS, MAX_SOUND_SECONDS))
	Setting.save()
	pass


# --------------------------------------------- Notification sound folder ---------------------------------------------

const NOTIFICATION_SOUND_FOLDER_KEY := "agent_notification_sound_folder"
const DEFAULT_SOUND_FOLDER := "res://test/asset/"


## Folder holding the notification clips — a `res://` folder or any OS folder.
static func get_notification_sound_folder() -> String:
	return Setting.get_string(NOTIFICATION_SOUND_FOLDER_KEY, DEFAULT_SOUND_FOLDER).strip_edges()


static func set_notification_sound_folder(folder: String) -> void:
	Setting.set_string(NOTIFICATION_SOUND_FOLDER_KEY, folder.strip_edges())
	Setting.save()
	pass
