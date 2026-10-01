class_name AudioRecorder
extends Object

## Microphone recorder: captures input via AudioStreamMicrophone + AudioEffectRecord, saves WAV.

const RECORD_BUS_NAME: String = "Record"

static var effect: AudioEffectRecord
static var player: AudioStreamPlayer
static var recording: AudioStreamWAV


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
	recording = null
	if not player.playing:
		player.play()
	effect.set_recording_active(true)
	pass


static func stop() -> AudioStreamWAV:
	if effect == null:
		Log.error("AudioRecorder not initialized")
		return null
	if effect.is_recording_active():
		recording = effect.get_recording()
		effect.set_recording_active(false)
	if player != null and player.playing:
		player.stop()
	return recording


static func get_recording() -> AudioStreamWAV:
	return recording


## Stops if still recording, then writes the last capture to a local WAV file.
## Returns a Godot engine error code (`OK` / `ERR_*`).
static func save(path: String) -> int:
	if is_recording():
		stop()
	if recording == null:
		Log.error("AudioRecorder has no recording to save path:[{}]", path)
		return ERR_DOES_NOT_EXIST
	if path.is_empty():
		Log.error("AudioRecorder save path is empty")
		return ERR_INVALID_PARAMETER

	var save_path := path
	if path.begins_with("user://") or path.begins_with("res://"):
		save_path = ProjectSettings.globalize_path(path)

	var dir := save_path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		var make_err := DirAccess.make_dir_recursive_absolute(dir)
		if make_err != OK:
			Log.error("AudioRecorder failed to create dir:[{}] err:[{}]", dir, make_err)
			return make_err

	var err := recording.save_to_wav(save_path)
	if err != OK:
		Log.error("AudioRecorder save failed path:[{}] err:[{}]", save_path, err)
	return err
