class_name Audio
extends Object

# Single-channel audio: one AudioStreamPlayer per bus; a new sound replaces the current one.

enum AudioBusType {
	Music,
	Voice,
	Ambience,
}

static var audio_map: Dictionary[AudioBusType, AudioStreamPlayer] = {}
static var stream_tween_map: Dictionary[AudioBusType, Tween] = {}

static func init() -> void:
	for bus_name in AudioBusType.keys():
		AudioServer.add_bus()
		var bus_index := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_index, bus_name)

		var bus_value: AudioBusType = AudioBusType[bus_name]
		var audio_stream_player := AudioStreamPlayer.new()
		audio_stream_player.name = bus_name
		audio_stream_player.bus = bus_name
		gdf.gdf_node.add_child(audio_stream_player)
		audio_map[bus_value] = audio_stream_player
	
	var music := audio_map[AudioBusType.Music]
	music.finished.connect(play_music_next)
	pass

####################################################################################################

static func set_audio_bus_volume_linear(type: AudioBusType, volume_linear: float) -> void:
	var bus_name: String = AudioBusType.keys()[type]
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus_name), clampf(volume_linear, 0.0, 1.0))
	pass

static func stop_all() -> void:
	for audio_bus in audio_map.keys():
		stop_stream(audio_bus)
	pass

static func stop_all_fade() -> void:
	for audio_bus in audio_map.keys():
		stop_stream_fade(audio_bus)
	pass

####################################################################################################
# stream
static func play_stream(bus: AudioBusType, path: String, volume_linear: float = 1.0) -> void:
	var resource := await ResourceHelper.async_load(path) as AudioStream
	if resource == null:
		return
	cancel_stream_tween(bus)
	var player: AudioStreamPlayer = audio_map[bus]
	player.volume_linear = clampf(volume_linear, 0.0, 1.0)
	player.stream = resource
	player.play()
	pass

static func stop_stream(bus: AudioBusType) -> void:
	cancel_stream_tween(bus)
	var player: AudioStreamPlayer = audio_map[bus]
	player.stop()
	pass

## Cancel the previous fade on this bus. Emitting [signal Tween.finished] releases its awaiting
## coroutine; that coroutine sees it is no longer the current tween and exits without applying its
## stale final state.
static func cancel_stream_tween(bus: AudioBusType) -> void:
	var tween: Tween = stream_tween_map.get(bus)
	if tween == null:
		return
	stream_tween_map.erase(bus)
	if tween.is_valid():
		tween.kill()
		tween.finished.emit()
	pass

static func fade_stream(bus: AudioBusType, player: AudioStreamPlayer, volume_linear: float, duration: float) -> bool:
	cancel_stream_tween(bus)
	var tween := player.create_tween()
	stream_tween_map[bus] = tween
	tween.tween_property(player, "volume_linear", volume_linear, duration)
	await tween.finished
	if stream_tween_map.get(bus) != tween:
		return false
	stream_tween_map.erase(bus)
	return true

static func play_stream_fade(bus: AudioBusType, path: String, volume_linear: float = 1.0, duration: float = 1.0) -> void:
	var resource := await ResourceHelper.async_load(path) as AudioStream
	if resource == null:
		return
	var target_volume := clampf(volume_linear, 0.0, 1.0)
	var audio: AudioStreamPlayer = audio_map[bus]
	if audio.playing:
		var faded_out := await fade_stream(bus, audio, 0.0, duration)
		if not faded_out:
			return
	else:
		cancel_stream_tween(bus)
		audio.volume_linear = 0.0
	audio.stream = resource
	audio.play()
	await fade_stream(bus, audio, target_volume, duration)
	pass

static func stop_stream_fade(bus: AudioBusType, duration: float = 1.0) -> void:
	var audio: AudioStreamPlayer = audio_map[bus]
	if !audio.playing:
		cancel_stream_tween(bus)
		return
	var faded_out := await fade_stream(bus, audio, 0.0, duration)
	if not faded_out:
		return
	audio.stop()
	pass
####################################################################################################
# music
static func play_music(path: String, volume_linear: float = 1.0) -> void:
	musics.clear()
	await play_stream(AudioBusType.Music, path, volume_linear)
	pass

static func stop_music() -> void:
	musics.clear()
	stop_stream(AudioBusType.Music)
	pass

static func play_music_fade(path: String, volume_linear: float = 1.0, duration: float = 1.0) -> void:
	musics.clear()
	await play_stream_fade(AudioBusType.Music, path, volume_linear, duration)
	pass

static func stop_music_fade(duration: float = 1.0) -> void:
	musics.clear()
	await stop_stream_fade(AudioBusType.Music, duration)
	pass
####################################################################################################
# voice
static func play_voice(path: String, volume_linear: float = 1.0) -> void:
	await play_stream(AudioBusType.Voice, path, volume_linear)
	pass

static func is_playing_voice() -> bool:
	var audio := audio_map[AudioBusType.Voice]
	return audio.playing
	
static func stop_voice() -> void:
	stop_stream(AudioBusType.Voice)
	pass

static func play_voice_fade(path: String, volume_linear: float = 1.0, duration: float = 1.0) -> void:
	await play_stream_fade(AudioBusType.Voice, path, volume_linear, duration)
	pass

static func stop_voice_fade(duration: float = 1.0) -> void:
	await stop_stream_fade(AudioBusType.Voice, duration)
	pass
####################################################################################################
# ambience
static func play_ambience(path: String, volume_linear: float = 1.0) -> void:
	await play_stream(AudioBusType.Ambience, path, volume_linear)
	pass

static func is_playing_ambience() -> bool:
	var audio := audio_map[AudioBusType.Ambience]
	return audio.playing

static func stop_ambience() -> void:
	stop_stream(AudioBusType.Ambience)
	pass

static func play_ambience_fade(path: String, volume_linear: float = 1.0, duration: float = 1.0) -> void:
	await play_stream_fade(AudioBusType.Ambience, path, volume_linear, duration)
	pass

static func stop_ambience_fade(duration: float = 1.0) -> void:
	await stop_stream_fade(AudioBusType.Ambience, duration)
	pass


####################################################################################################
# musics
static var musics: Array[String] = []
static var musics_volume_linear: float = 1.0

static func play_musics(paths: Array[String], volume_linear: float = 1.0, duration: float = 3.0) -> void:
	musics = paths.duplicate()
	musics_volume_linear = clampf(volume_linear, 0.0, 1.0)
	play_music_next(duration)
	pass


## True while the music playlist is audible.
static func is_playing_music() -> bool:
	return audio_map[AudioBusType.Music].playing


## True while the music playlist is paused — [method resume_musics] carries on from there.
static func is_music_paused() -> bool:
	return audio_map[AudioBusType.Music].stream_paused

static func play_music_next(duration: float = 3.0) -> void:
	if musics.is_empty():
		return
	var path: String = musics.pop_front()
	musics.push_back(path)
	await play_stream_fade(AudioBusType.Music, path, musics_volume_linear, duration)
	pass

static func pause_musics(duration: float = 1.0) -> void:
	var player: AudioStreamPlayer = audio_map[AudioBusType.Music]
	if !player.playing or player.stream_paused:
		cancel_stream_tween(AudioBusType.Music)
		return
	var faded_out := await fade_stream(AudioBusType.Music, player, 0.0, duration)
	if not faded_out:
		return
	player.stream_paused = true
	pass

static func resume_musics(duration: float = 1.0, volume_linear: float = 1.0) -> void:
	var player: AudioStreamPlayer = audio_map[AudioBusType.Music]
	if !player.stream_paused:
		return
	var target_volume := clampf(volume_linear, 0.0, 1.0)
	musics_volume_linear = target_volume
	player.volume_linear = 0.0
	player.stream_paused = false
	await fade_stream(AudioBusType.Music, player, target_volume, duration)
	pass
