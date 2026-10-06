class_name AgentNotification
extends RefCounted

## Desktop notifications for agent runs — a toast pops up top-right while the app is active or
## bottom-right while it is in the background, plus an optional sound clip. Both are toggled in
## [AgentSettingDialog] and persisted through [AgentNotifySetting].


## Fade of the notification sound when it starts and when its configured duration elapses.
const START_FADE_SECONDS := 0.3
const STOP_FADE_SECONDS := 0.5

## Seconds of playback the queued runs still owe the playlist, summed over every run that asked
## for a sound. See [method play_sound_notifications].
var remaining_seconds := 0.0


func setup() -> void:
	# Deferred: AgentSessionManager appends the outcome chat entry in its own agent_end handler.
	AgentEvents.events.agent_end.connect(on_agent_end, CONNECT_DEFERRED)
	# The playlist is polled once per second instead of one delayed stop per run — see
	# [method check_sound_notifications].
	SchedulerBus.schedule_at_fixed_rate(check_sound_notifications, TimeUtils.MILLIS_PER_SECOND, "agent_notification_sound")
	pass


## Desktop toast when a run ends, positioned according to whether the app is currently active.
func on_agent_end(session_id: int, error_message: String) -> void:
	# A stop comes from the app window, so the user is already looking at it.
	if error_message.begins_with("Stop"):
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null or session.chat_entries.is_empty():
		return
	# The newest chat entry is the outcome: AgentSessionManager already appended the error
	# bubble for a failed run, otherwise it is the agent reply.
	var entry: ChatEntry = session.chat_entries.back()
	if AgentSetting.get_notification_window():
		var accent := ColorBase.error if entry.kind == ChatEntry.KIND_ERROR else ColorBase.success
		var corner := Corner.CORNER_TOP_RIGHT if DisplayServer.window_is_focused(DisplayServer.MAIN_WINDOW_ID) else Corner.CORNER_BOTTOM_RIGHT
		DesktopToast.show_toast(entry.title, entry.body, accent, corner)
	if AgentSetting.get_notification_sound():
		play_sound_notifications()
	pass


## Play the configured folder as one continuous playlist, silenced once every run that asked for a
## sound got its seconds. A playlist that is still running keeps going and a paused one is resumed,
## so a second run does not restart the same beep — only a different folder starts a fresh playlist.
func play_sound_notifications() -> void:
	var audios := ResourceHelper.get_all_audio_files(AgentSetting.get_notification_sound_folder())
	if audios.is_empty():
		return
	audios.shuffle()
	if has_playlist(audios):
		Audio.resume_musics(START_FADE_SECONDS)
	else:
		Audio.play_musics(audios, 1.0, START_FADE_SECONDS)
	# The countdown is shared: a run landing while the sound still plays adds its seconds to the
	# remaining ones, so the clip an earlier run asked for is never cut short by a later run.
	remaining_seconds = maxf(remaining_seconds, 0.0) + AgentSetting.get_notification_sound_seconds()
	pass


## Once-per-second tick of the shared countdown above — the playlist is only ever stopped by the
## last run that added seconds, and the timer stays idle the rest of the time.
func check_sound_notifications() -> void:
	if remaining_seconds <= 0:
		return
	remaining_seconds -= 1
	if remaining_seconds <= 0:
		stop_sound_notifications()
	pass


## True while the music player already runs (or holds) exactly these clips. The playlist rotates as
## it plays, so the order is ignored.
func has_playlist(clips: Array[String]) -> bool:
	if not Audio.is_playing_music() and not Audio.is_music_paused():
		return false
	var loaded := Audio.musics.duplicate()
	var requested := clips.duplicate()
	loaded.sort()
	requested.sort()
	return loaded == requested


## Fade the music out and pause it, so the next run picks the sound up where this one left it.
func stop_sound_notifications() -> void:
	Audio.pause_musics(STOP_FADE_SECONDS)
	pass
