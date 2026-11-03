class_name ShortcutSetting
extends RefCounted

## Persisted in-app shortcuts. Each shortcut is one [enum Key]: the primary key in the low bits
## and modifier flags in the high bits. Edited by [ShortcutSettingSection].

const SEARCH_SHORTCUT_KEY := "agent_search_shortcut"
## Opens chat search. Default is Ctrl+F.
const DEFAULT_SEARCH_SHORTCUT: Key = KEY_F | KEY_MASK_CTRL
const PREV_USER_MESSAGE_SHORTCUT_KEY := "agent_prev_user_message_shortcut"
const NEXT_USER_MESSAGE_SHORTCUT_KEY := "agent_next_user_message_shortcut"
## Jumps to the previous user message in the transcript. Default is Shift+Page Up.
const DEFAULT_PREV_USER_MESSAGE_SHORTCUT: Key = KEY_PAGEUP | KEY_MASK_SHIFT
## Jumps to the next user message in the transcript. Default is Shift+Page Down.
const DEFAULT_NEXT_USER_MESSAGE_SHORTCUT: Key = KEY_PAGEDOWN | KEY_MASK_SHIFT
const PREV_REPLY_SHORTCUT_KEY := "agent_prev_reply_shortcut"
const NEXT_REPLY_SHORTCUT_KEY := "agent_next_reply_shortcut"
## Jumps to the previous agent reply in the transcript. Default is Ctrl+Shift+Page Up.
const DEFAULT_PREV_REPLY_SHORTCUT: Key = KEY_PAGEUP | KEY_MASK_SHIFT | KEY_MASK_CTRL
## Jumps to the next agent reply in the transcript. Default is Ctrl+Shift+Page Down.
const DEFAULT_NEXT_REPLY_SHORTCUT: Key = KEY_PAGEDOWN | KEY_MASK_SHIFT | KEY_MASK_CTRL


static func get_search_shortcut() -> Key:
	return Setting.get_int(SEARCH_SHORTCUT_KEY, DEFAULT_SEARCH_SHORTCUT) as Key


static func set_search_shortcut(key: Key) -> void:
	if get_search_shortcut() == key:
		return
	Setting.set_int(SEARCH_SHORTCUT_KEY, key)
	Setting.save()
	AgentEvents.events.search_shortcut_changed.emit()
	pass


static func get_prev_user_message_shortcut() -> Key:
	return Setting.get_int(PREV_USER_MESSAGE_SHORTCUT_KEY, DEFAULT_PREV_USER_MESSAGE_SHORTCUT) as Key


static func get_next_user_message_shortcut() -> Key:
	return Setting.get_int(NEXT_USER_MESSAGE_SHORTCUT_KEY, DEFAULT_NEXT_USER_MESSAGE_SHORTCUT) as Key


static func set_prev_user_message_shortcut(key: Key) -> void:
	if get_prev_user_message_shortcut() == key:
		return
	Setting.set_int(PREV_USER_MESSAGE_SHORTCUT_KEY, key)
	Setting.save()
	AgentEvents.events.prev_user_message_shortcut_changed.emit()
	pass


static func set_next_user_message_shortcut(key: Key) -> void:
	if get_next_user_message_shortcut() == key:
		return
	Setting.set_int(NEXT_USER_MESSAGE_SHORTCUT_KEY, key)
	Setting.save()
	AgentEvents.events.next_user_message_shortcut_changed.emit()
	pass


static func get_prev_reply_shortcut() -> Key:
	return Setting.get_int(PREV_REPLY_SHORTCUT_KEY, DEFAULT_PREV_REPLY_SHORTCUT) as Key


static func get_next_reply_shortcut() -> Key:
	return Setting.get_int(NEXT_REPLY_SHORTCUT_KEY, DEFAULT_NEXT_REPLY_SHORTCUT) as Key


static func set_prev_reply_shortcut(key: Key) -> void:
	if get_prev_reply_shortcut() == key:
		return
	Setting.set_int(PREV_REPLY_SHORTCUT_KEY, key)
	Setting.save()
	AgentEvents.events.prev_reply_shortcut_changed.emit()
	pass


static func set_next_reply_shortcut(key: Key) -> void:
	if get_next_reply_shortcut() == key:
		return
	Setting.set_int(NEXT_REPLY_SHORTCUT_KEY, key)
	Setting.save()
	AgentEvents.events.next_reply_shortcut_changed.emit()
	pass


static func is_search_shortcut_valid(key: Key) -> bool:
	var code := key & KEY_CODE_MASK
	if code == KEY_NONE or code in [KEY_CTRL, KEY_ALT, KEY_SHIFT, KEY_META]:
		return false
	return (key & (KEY_MASK_CTRL | KEY_MASK_ALT | KEY_MASK_SHIFT | KEY_MASK_META)) != 0


static func make_search_shortcut() -> Shortcut:
	var shortcut := Shortcut.new()
	shortcut.events = [make_shortcut_event(get_search_shortcut())]
	return shortcut


static func make_shortcut_event(key: Key) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.keycode = key & KEY_CODE_MASK
	key_event.ctrl_pressed = (key & KEY_MASK_CTRL) != 0
	key_event.alt_pressed = (key & KEY_MASK_ALT) != 0
	key_event.shift_pressed = (key & KEY_MASK_SHIFT) != 0
	key_event.meta_pressed = (key & KEY_MASK_META) != 0
	return key_event
