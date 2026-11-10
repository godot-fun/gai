class_name Audio
extends Object

# Single-channel audio: one AudioStreamPlayer per bus; a new sound replaces the current one.

enum AudioBusType {
	Music,
	Voice,
	Ambience,
}

static var audio_map: Dictionary[AudioBusType, AudioStreamPlayer] = {}
static var stream_fade_map: Dictionary[AudioBusType, bool] = {}

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
	var player: AudioStreamPlayer = audio_map[bus]
	player.volume_linear = clampf(volume_linear, 0.0, 1.0)
	player.stream = resource
	player.play()
	pass

static func stop_stream(bus: AudioBusType) -> void:
	var player: AudioStreamPlayer = audio_map[bus]
	player.stop()
	pass

static func begin_stream_fade(bus: AudioBusType, method: String) -> bool:
	if stream_fade_map.get(bus, false):
		Log.error("stream fade already in progress on bus:[{}], skip [{}]", AudioBusType.keys()[bus], method)
		return false
	stream_fade_map[bus] = true
	return true

static func end_stream_fade(bus: AudioBusType) -> void:
	stream_fade_map[bus] = false
	pass

static func play_stream_fade(bus: AudioBusType, path: String, volume_linear: float = 1.0, duration: float = 1.0) -> void:
	var resource := await ResourceHelper.async_load(path) as AudioStream
	if resource == null:
		return
	if !begin_stream_fade(bus, "play_stream_fade"):
		return
	var target_volume := clampf(volume_linear, 0.0, 1.0)
	var audio: AudioStreamPlayer = audio_map[bus]
	if audio.playing:
		var tween := audio.create_tween()
		tween.tween_property(audio, "volume_linear", 0, duration)
		await tween.finished
	else:
		audio.volume_linear = 0
	audio.stream = resource
	audio.play()
	var fade_in := audio.create_tween()
	fade_in.tween_property(audio, "volume_linear", target_volume, duration)
	await fade_in.finished
	end_stream_fade(bus)
	pass

static func stop_stream_fade(bus: AudioBusType, duration: float = 1.0) -> void:
	var audio: AudioStreamPlayer = audio_map[bus]
	if !audio.playing:
		return
	if !begin_stream_fade(bus, "stop_stream_fade"):
		return
	var tween := audio.create_tween()
	tween.tween_property(audio, "volume_linear", 0, duration)
	await tween.finished
	audio.stop()
	end_stream_fade(bus)
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
		return
	if !begin_stream_fade(AudioBusType.Music, "pause_music"):
		return
	var tween := player.create_tween()
	tween.tween_property(player, "volume_linear", 0, duration)
	await tween.finished
	player.stream_paused = true
	end_stream_fade(AudioBusType.Music)
	pass

static func resume_musics(duration: float = 1.0, volume_linear: float = 1.0) -> void:
	var player: AudioStreamPlayer = audio_map[AudioBusType.Music]
	if !player.stream_paused:
		return
	if !begin_stream_fade(AudioBusType.Music, "resume_music"):
		return
	var target_volume := clampf(volume_linear, 0.0, 1.0)
	musics_volume_linear = target_volume
	player.volume_linear = 0
	player.stream_paused = false
	var tween := player.create_tween()
	tween.tween_property(player, "volume_linear", target_volume, duration)
	await tween.finished
	end_stream_fade(AudioBusType.Music)
	pass
