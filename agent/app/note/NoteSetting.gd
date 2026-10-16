class_name NoteSetting
extends RefCounted

## Persisted preferences for the Note app — open-on-startup and related toggles.

const OPEN_ON_STARTUP_KEY := "note_open_on_startup"


static func get_open_on_startup() -> bool:
	return Setting.get_bool(OPEN_ON_STARTUP_KEY, true)


static func set_open_on_startup(enabled: bool) -> void:
	Setting.set_bool(OPEN_ON_STARTUP_KEY, enabled)
	Setting.save()
	pass
