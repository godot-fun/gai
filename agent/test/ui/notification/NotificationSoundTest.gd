extends RefCounted

## The notification sound is reconciled by [method AgentNotification.check_sound_notifications] once
## per second. This test drives that tick by hand instead of waiting for the real timer.

## Folder holding long enough clips that a track ends only after the test did.
const CLIP_FOLDER := "res://test/asset/"


## A track starting between two ticks cancels the stop fade — the tick has to ask for the pause
## again, otherwise the playlist stays audible forever once the countdown is spent.
func check_sound_notifications_stops_again_after_playlist_restart_test() -> void:
	var original_folder := AgentSetting.get_notification_sound_folder()
	AgentSetting.set_notification_sound_folder(CLIP_FOLDER)
	var notification := AgentNotification.new()
	notification.play_sound_notifications()
	await wait_playing()
	notification.remaining_seconds = 0.0
	notification.check_sound_notifications()
	await wait_seconds(0.8)
	assert(Audio.is_music_paused())
	# The cancelled fade leaves the same playlist playing again at full volume.
	Audio.resume_musics(0.1, AgentSetting.get_notification_sound_volume_linear())
	await wait_seconds(0.5)
	assert(not Audio.is_music_paused())
	notification.check_sound_notifications()
	await wait_seconds(0.8)
	assert(Audio.is_music_paused())
	AgentSetting.set_notification_sound_folder(original_folder)
	Audio.stop_music()
	pass


## Wait until the playlist really plays — [method Audio.play_musics] loads its first clip async.
func wait_playing() -> void:
	for _attempt in 50:
		if Audio.is_playing_music():
			return
		await wait_seconds(0.1)
	Log.error("notification sound never started")
	pass


func wait_seconds(seconds: float) -> void:
	await gdf.gdf_node.get_tree().create_timer(seconds).timeout
	pass
