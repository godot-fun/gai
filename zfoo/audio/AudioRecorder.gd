class_name AudioRecorder
extends Object

## Microphone recorder: AudioStreamMicrophone + AudioEffectRecord → WAV.
## While recording, [method poll_volume] updates [member volume] from [AudioEffectCapture].

const RECORD_BUS_NAME: String = "Record"

static var effect: AudioEffectRecord
static var capture: AudioEffectCapture
static var player: AudioStreamPlayer


static func init() -> void:
	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, RECORD_BUS_NAME)
	AudioServer.set_bus_mute(bus_index, true)

	capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus_index, capture)

	effect = AudioEffectRecord.new()
	effect.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus_index, effect)

	player = AudioStreamPlayer.new()
	player.name = "AudioRecorder"
	player.stream = AudioStreamMicrophone.new()
	player.bus = RECORD_BUS_NAME
	gdf.gdf_node.add_child(player)
	pass


static func is_active() -> bool:
	return effect != null and effect.is_recording_active()


static func start() -> void:
	if effect == null:
		Log.error("AudioRecorder not initialized")
		return
	if effect.is_recording_active():
		Log.error("AudioRecorder already recording")
		return
	drain_capture()
	volume = 0.0
	if not player.playing:
		player.play()
	effect.set_recording_active(true)
	pass


## Stops capture and returns the recording, or `null` when nothing was recording.
static func stop() -> AudioStreamWAV:
	if effect == null:
		Log.error("AudioRecorder not initialized")
		return null
	if not effect.is_recording_active():
		return null
	var wav := effect.get_recording()
	effect.set_recording_active(false)
	drain_capture()
	volume = 0.0
	if player != null and player.playing:
		player.stop()
	return wav


## Writes [param wav] to a local path. Returns `OK` / `ERR_*`.
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


# ----------------------------------------------------------------------------------------------------------------------
# Live volume meter (RMS → dB → envelope)
# ----------------------------------------------------------------------------------------------------------------------

## dB floor for the 0..1 meter (speech UI; below this reads as silence).
## Higher (closer to 0) = less sensitive; -40 keeps normal speech mid-wave.
const VOLUME_DB_FLOOR: float = -50.0
const VOLUME_ATTACK: float = 0.85
const VOLUME_RELEASE: float = 0.12

## Mic meter after the last [method poll_volume] (0.0 … 1.0, RMS → dB).
static var volume: float = 0.0


## Call once per frame while recording. Updates and returns [member volume] (0..1).
## Uses RMS → dB → 0..1, then a fast-attack / slow-release envelope.
## Rendering and audio capture run on independent clocks, so a render frame may arrive
## before the capture effect has produced another buffer. No buffer means "no new reading",
## not silence; keeping the previous envelope prevents false one-frame volume dips.
static func poll_volume() -> float:
	if capture == null or not is_active():
		volume = 0.0
		return volume
	var available := capture.get_frames_available()
	if available <= 0:
		return volume
	var frames: PackedVector2Array = capture.get_buffer(available)
	var sum_sq := 0.0
	for sample in frames:
		var mono: float = (sample.x + sample.y) * 0.5
		sum_sq += mono * mono
	var rms := sqrt(sum_sq / float(frames.size()))
	var db := linear_to_db(maxf(rms, 1e-7))
	var level := clampf((db - VOLUME_DB_FLOOR) / (0.0 - VOLUME_DB_FLOOR), 0.0, 1.0)
	var rate := VOLUME_ATTACK if level >= volume else VOLUME_RELEASE
	volume = lerpf(volume, level, rate)
	return volume


static func drain_capture() -> void:
	if capture == null:
		return
	var available := capture.get_frames_available()
	if available > 0:
		capture.get_buffer(available)
	pass
