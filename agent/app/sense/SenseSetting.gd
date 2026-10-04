class_name SenseSetting
extends RefCounted

## Persisted preferences shared by the Sense toolbar panel and [SenseInput].

const ENABLED_KEY := "sense_enabled"
const LOCAL_MODEL_KEY := "sense_use_local_model"
const HOTKEY_KEY_KEY := "sense_hotkey_key"
const HOTKEY_MODIFIERS_KEY := "sense_hotkey_modifiers"
const SYSTEM_PROMPT_KEY := "sense_system_prompt"

const DEFAULT_HOTKEY_KEY := KEY_Z
const DEFAULT_HOTKEY_MODIFIERS := KEY_MASK_ALT


static func is_enabled() -> bool:
	return Setting.get_bool(ENABLED_KEY, true)


static func set_enabled(enabled: bool) -> void:
	Setting.set_bool(ENABLED_KEY, enabled)
	Setting.save()
	pass


static func use_local_model() -> bool:
	return Setting.get_bool(LOCAL_MODEL_KEY, true)


static func set_use_local_model(local: bool) -> void:
	Setting.set_bool(LOCAL_MODEL_KEY, local)
	Setting.save()
	pass


static func get_hotkey_key() -> Key:
	var key: Key = Setting.get_int(HOTKEY_KEY_KEY, DEFAULT_HOTKEY_KEY)
	return key


static func get_hotkey_modifiers() -> int:
	return Setting.get_int(HOTKEY_MODIFIERS_KEY, DEFAULT_HOTKEY_MODIFIERS)


static func set_hotkey(key: Key, modifiers: int) -> void:
	Setting.set_int(HOTKEY_KEY_KEY, key)
	Setting.set_int(HOTKEY_MODIFIERS_KEY, modifiers)
	Setting.save()
	pass


static func get_system_prompt() -> String:
	return Setting.get_string(SYSTEM_PROMPT_KEY, "")


static func set_system_prompt(prompt: String) -> void:
	Setting.set_string(SYSTEM_PROMPT_KEY, prompt)
	Setting.save()
	pass


static func append_system_prompt(base_prompt: String) -> String:
	var custom := get_system_prompt().strip_edges()
	if custom.is_empty():
		return base_prompt
	return base_prompt + "\n\n<user_system_prompt>\n" + custom + "\n</user_system_prompt>"


static func hotkey_text(key: Key = get_hotkey_key(), modifiers: int = get_hotkey_modifiers()) -> String:
	var parts: Array[String] = []
	if modifiers & KEY_MASK_CTRL:
		parts.append("Ctrl")
	if modifiers & KEY_MASK_ALT:
		parts.append("Alt")
	if modifiers & KEY_MASK_SHIFT:
		parts.append("Shift")
	if modifiers & KEY_MASK_META:
		parts.append("Meta")
	parts.append(OS.get_keycode_string(key))
	return "+".join(parts)
