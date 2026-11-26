class_name SenseInput
extends RefCounted

## Global push-to-talk voice input. Hold the configured shortcut to record; release to transcribe
## locally, copy the result, and paste it directly into the foreground input control.
## The shortcut is configured under Settings → Shortcuts and works while the app is unfocused via
## [GlobalHotkey]. Recording is saved as PCM16 WAV, transcribed by the local SenseVoice script, then
## pasted with [method NativeOS.paste_clipboard]. Soft failures are logged and leave the target input
## unchanged; this flow never opens a selection panel.

const HOTKEY_ID: int = 1
const CACHE_DIR: String = "user://sense"
const MAX_CACHE_BYTES: int = 128 * FileUtils.BYTES_PER_MB
const VOICE_INPUT_FILE: String = "voice_input_{}.wav"
const TRANSCRIBE_SCRIPT_REL_PATH: String = ".ai/audio-to-text/transcribe.py"
const TRANSCRIBE_TIMEOUT_MILLIS: int = TimeUtils.MILLIS_PER_MINUTE * 10
## Let other Windows processes observe the new clipboard contents before Ctrl+V arrives.
const PASTE_DELAY_MILLIS: int = 50
const LOG_BODY_MAX: int = 120

## True while the current recording is being transcribed and pasted.
var busy: bool = false


func setup() -> void:
	AgentEvents.events.sense_shortcut_changed.connect(apply_settings)
	apply_settings()
	cleanup_caches()
	SchedulerBus.schedule_at_fixed_rate(cleanup_caches, TimeUtils.MILLIS_PER_HOUR, "sense_clean")
	pass


func apply_settings() -> void:
	unregister_hotkey()
	if not Engine.has_singleton("GlobalHotkey"):
		Log.error("SenseInput: GlobalHotkey singleton missing (GDExtension not loaded)")
		return
	var shortcut := ShortcutSetting.get_sense_shortcut()
	var hotkey_key := (shortcut & KEY_CODE_MASK) as Key
	var modifiers := shortcut & (KEY_MASK_CTRL | KEY_MASK_ALT | KEY_MASK_SHIFT | KEY_MASK_META)
	if not GlobalHotkey.is_key_supported(hotkey_key):
		Log.error("SenseInput: configured key is not supported as a global hotkey")
		return
	if not GlobalHotkey.hotkey_pressed.is_connected(on_hotkey_pressed):
		GlobalHotkey.hotkey_pressed.connect(on_hotkey_pressed)
	if not GlobalHotkey.hotkey_released.is_connected(on_hotkey_released):
		GlobalHotkey.hotkey_released.connect(on_hotkey_released)
	var registered := GlobalHotkey.register_hotkey(HOTKEY_ID, hotkey_key, modifiers)
	if not registered:
		Log.error("SenseInput: failed to register {} (combo may already be taken)", OS.get_keycode_string(shortcut))
		return
	Log.info("SenseInput: registered push-to-talk {}", OS.get_keycode_string(shortcut))
	pass


func unregister_hotkey() -> void:
	if Engine.has_singleton("GlobalHotkey") and GlobalHotkey.is_registered(HOTKEY_ID):
		GlobalHotkey.unregister_hotkey(HOTKEY_ID)
	pass


func shutdown() -> void:
	if AgentEvents.events.sense_shortcut_changed.is_connected(apply_settings):
		AgentEvents.events.sense_shortcut_changed.disconnect(apply_settings)
	SenseWave.dismiss()
	if AudioRecorder.is_active():
		AudioRecorder.stop()
	busy = false
	if not Engine.has_singleton("GlobalHotkey"):
		return
	if GlobalHotkey.hotkey_pressed.is_connected(on_hotkey_pressed):
		GlobalHotkey.hotkey_pressed.disconnect(on_hotkey_pressed)
	if GlobalHotkey.hotkey_released.is_connected(on_hotkey_released):
		GlobalHotkey.hotkey_released.disconnect(on_hotkey_released)
	unregister_hotkey()
	pass


func on_hotkey_pressed(id: int) -> void:
	if id != HOTKEY_ID or busy or AudioRecorder.is_active():
		return
	if SenseWave.instance != null and is_instance_valid(SenseWave.instance):
		Log.info("SenseInput: busy — recording indicator already open")
		return
	AudioRecorder.start()
	SenseWave.show_recording()
	pass


## Stop recording, transcribe it, and paste the text into the foreground input control.
func on_hotkey_released(id: int) -> void:
	if id != HOTKEY_ID or busy:
		return
	if SenseWave.instance == null or not is_instance_valid(SenseWave.instance):
		return
	busy = true
	SenseWave.show_transcribing()
	var voice_text := await async_transcribe_recording()
	SenseWave.dismiss()
	busy = false
	if StringUtils.is_blank(voice_text):
		return
	DisplayServer.clipboard_set(voice_text)
	if Engine.has_singleton("NativeOS"):
		await ThreadUtils.async_sleep(PASTE_DELAY_MILLIS)
		NativeOS.paste_clipboard()
	Log.info("SenseInput: completed text:[{}]", StringUtils.truncate(voice_text, LOG_BODY_MAX))
	pass


## Stop the microphone and run ASR when a buffer exists. Returns blank on a soft failure.
func async_transcribe_recording() -> String:
	if not AudioRecorder.is_active():
		Log.info("SenseInput: microphone is inactive")
		return StringUtils.EMPTY
	var wav := AudioRecorder.stop()
	if wav == null or wav.data.is_empty():
		Log.info("SenseInput: recording is empty")
		return StringUtils.EMPTY
	var voice_path := CACHE_DIR.path_join(StringUtils.format(VOICE_INPUT_FILE, IdUtils.short_uuid()))
	var err := AudioRecorder.save(wav, voice_path)
	if err != OK:
		Log.info("SenseInput: save failed err:[{}]", err)
		return StringUtils.EMPTY
	var absolute := FileUtils.globalize_writable_path(voice_path)
	if StringUtils.is_blank(absolute):
		Log.info("SenseInput: voice path is unavailable")
		return StringUtils.EMPTY
	var result := await async_audio_to_text(absolute)
	if result.is_error:
		Log.info("SenseInput: ASR failed:[{}]", StringUtils.truncate(result.content, LOG_BODY_MAX))
		return StringUtils.EMPTY
	var voice_text := result.content.strip_edges()
	if StringUtils.is_blank(voice_text):
		Log.info("SenseInput: ASR returned empty text")
		return StringUtils.EMPTY
	return voice_text


## Transcribe a PCM16 WAV file via the local SenseVoice script.
static func async_audio_to_text(audio_path: String) -> AgentToolResult:
	if not FileAccess.file_exists(audio_path):
		return AgentToolResult.error(StringUtils.format("error: audio not found: {}", audio_path))
	if not DependencyManifest.has_populated_runtime(DependencyManifest.PYTHON_PATH):
		return AgentToolResult.error(DependencyManifest.PYTHON_INSTALL_PROMPT)
	var argv := PackedStringArray([DependencyManifest.PYTHON_PATH, TRANSCRIBE_SCRIPT_REL_PATH, "--audio", audio_path])
	var exec_result := await OSUtils.async_execute(argv, false, TRANSCRIBE_TIMEOUT_MILLIS)
	var output := exec_result.output.build_string().strip_edges()
	if exec_result.exit_code != 0:
		var message := output if StringUtils.is_not_blank(output) else StringUtils.format("error: audio-to-text failed (exit {})", exec_result.exit_code)
		return AgentToolResult.error(message)
	if StringUtils.is_blank(output):
		return AgentToolResult.error("error: audio-to-text returned no text")
	return AgentToolResult.ok(output)


func cleanup_caches() -> void:
	var absolute := ProjectSettings.globalize_path(CACHE_DIR)
	WorkerThreadPool.add_task(func() -> void: FileUtils.cleanup_cache_folder(absolute, MAX_CACHE_BYTES))
	pass
