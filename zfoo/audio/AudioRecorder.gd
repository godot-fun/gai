class_name AudioRecorder
extends Object

## Microphone recorder: captures input via AudioStreamMicrophone + AudioEffectRecord, saves WAV.

const RECORD_BUS_NAME: String = "Record"

static var effect: AudioEffectRecord
static var player: AudioStreamPlayer


static func init() -> void:
	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, RECORD_BUS_NAME)
	AudioServer.set_bus_mute(bus_index, true)

	effect = AudioEffectRecord.new()
	effect.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus_index, effect)

	player = AudioStreamPlayer.new()
	player.name = "AudioRecorder"
	player.stream = AudioStreamMicrophone.new()
	player.bus = RECORD_BUS_NAME
	gdf.gdf_node.add_child(player)
	pass


static func is_recording() -> bool:
	return effect != null and effect.is_recording_active()


static func start() -> void:
	if effect == null:
		Log.error("AudioRecorder not initialized")
		return
	if effect.is_recording_active():
		Log.error("AudioRecorder already recording")
		return
	if not player.playing:
		player.play()
	effect.set_recording_active(true)
	pass


## Stops the capture and returns the recorded audio, or `null` when nothing was recording.
static func stop() -> AudioStreamWAV:
	if effect == null:
		Log.error("AudioRecorder not initialized")
		return null
	if not effect.is_recording_active():
		return null
	var wav := effect.get_recording()
	effect.set_recording_active(false)
	if player != null and player.playing:
		player.stop()
	return wav


## Writes a recorded `AudioStreamWAV` to a local WAV file, creating missing parent folders.
## Returns a Godot engine error code (`OK` / `ERR_*`).
static func save(wav: AudioStreamWAV, path: String) -> int:
	if wav == null:
		Log.error("AudioRecorder has no recording to save path:[{}]", path)
		return ERR_DOES_NOT_EXIST
	if path.is_empty():
		Log.error("AudioRecorder save path is empty")
		return ERR_INVALID_PARAMETER

	var save_path := FileUtils.globalize_writable_path(path)
	if save_path.is_empty():
		Log.error("AudioRecorder failed to prepare path:[{}]", path)
		return ERR_CANT_CREATE

	var err := wav.save_to_wav(save_path)
	if err != OK:
		Log.error("AudioRecorder save failed path:[{}] err:[{}]", save_path, err)
	return err
