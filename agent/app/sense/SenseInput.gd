class_name SenseInput
extends RefCounted

## Global push-to-talk sense input method. Hold Alt+Z to record (works in the background via
## [GlobalHotkey]); release to stop, transcribe with [AudioToTextTool], wait for the parallel
## screenshot → VLM context (up to 3 s), build five candidates (voice / correct / optimize / expand / diverge),
## then let [SensePicker] choose (↑↓ / Enter / click); it restores the target app before
## clipboard + Ctrl+V via [method NativeOS.paste_clipboard].
## Two LLM backends ([member use_local_llm]):
## - Local: [VLMServer] + [SensePromptLocal] — sequential correct → optimize → expand → diverge.
## - Remote: [OpenAiClient] + [SensePrompt] — one-shot compose JSON; diverge early from screen alone.
## Screen OCR always uses local [VLMServer] (vision).
## Never shows error toasts: every press opens the picker; ASR soft-fails fall through to diverge.

const HOTKEY_ID := 1
const CACHE_DIR := "user://sense"
const MAX_CACHE_BYTES := 128 * FileUtils.BYTES_PER_MB
const VOICE_INPUT_FILE := "voice_input_{}.wav"
const SCREEN_INPUT_FILE := "screen_input_{}.png"

const SCREEN_WAIT_MILLIS := 3 * TimeUtils.MILLIS_PER_SECOND
const VOICE_HISTORY_SIZE := 6
const LOG_BODY_MAX := 120

## True while transcription / candidate compose / picker is in flight.
var busy: bool = false
## Local MiniCPM path when true; remote OpenAI-compatible path when false.
var use_local_llm: bool = true
## In-memory corrected-voice history (oldest → newest), appended when compose returns `correct`.
var voice_history: RingStringList = RingStringList.new(VOICE_HISTORY_SIZE)

## Parallel screenshot → VLM / diverge state for the current press.
## A new press replaces this instance; stale async work may still finish into the old session and is ignored.
var sense_session: SenseSession = SenseSession.new()


## Per-press screen OCR + diverge state. Identity replaces generation counters.
class SenseSession extends RefCounted:
	var screen_ready: bool = false
	var screen_text: String = ""
	var diverge_ready: bool = false
	var diverge_text: String = ""


func setup() -> void:
	apply_settings()
	cleanup_caches()
	SchedulerBus.schedule_at_fixed_rate(cleanup_caches, TimeUtils.MILLIS_PER_HOUR, "sense_clean")
	pass


func apply_settings() -> void:
	use_local_llm = SenseSetting.use_local_model()
	unregister_hotkey()
	if not SenseSetting.is_enabled():
		return
	if not Engine.has_singleton("GlobalHotkey"):
		Log.error("SenseInput: GlobalHotkey singleton missing (GDExtension not loaded)")
		return
	var hotkey_key := SenseSetting.get_hotkey_key()
	var modifiers := SenseSetting.get_hotkey_modifiers()
	if not GlobalHotkey.is_key_supported(hotkey_key):
		Log.error("SenseInput: configured key is not supported as a global hotkey")
		return
	if not GlobalHotkey.hotkey_pressed.is_connected(on_hotkey_pressed):
		GlobalHotkey.hotkey_pressed.connect(on_hotkey_pressed)
	if not GlobalHotkey.hotkey_released.is_connected(on_hotkey_released):
		GlobalHotkey.hotkey_released.connect(on_hotkey_released)
	var registered := GlobalHotkey.register_hotkey(HOTKEY_ID, hotkey_key, modifiers)
	if not registered:
		Log.error("SenseInput: failed to register {} (combo may already be taken)", SenseSetting.hotkey_text())
		return
	Log.info("SenseInput: registered push-to-talk {}", SenseSetting.hotkey_text())
	pass


static func with_custom_system(base_prompt: String) -> String:
	return SenseSetting.append_system_prompt(base_prompt)


func unregister_hotkey() -> void:
	if Engine.has_singleton("GlobalHotkey") and GlobalHotkey.is_registered(HOTKEY_ID):
		GlobalHotkey.unregister_hotkey(HOTKEY_ID)
	pass


func shutdown() -> void:
	SenseWave.dismiss()
	SensePicker.dismiss()
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
	if id != HOTKEY_ID:
		return
	if busy or AudioRecorder.is_active():
		return
	if SenseWave.instance != null and is_instance_valid(SenseWave.instance):
		Log.info("SenseInput: busy — recording indicator already open")
		return
	if SensePicker.is_open():
		Log.info("SenseInput: busy — picker already open")
		return
	# Capture before the beacon: capture_screen is sync and would stall the main thread
	# while a newly visible transparent Window still has no frame → gray rectangle flash.
	sense_session = SenseSession.new()
	AudioRecorder.start()
	WorkerThreadPool.add_task(func() -> void: async_ocr_screen_and_diverge(sense_session))
	# Mic is best-effort; screen OCR / diverge already guarantees a picker result on release.
	SenseWave.show_recording()
	pass


## Stop mic (if any), soft-fail ASR into voice slots, always open the picker for diverge.
## Do not gate on [method DisplayServer.window_is_focused]: after async work the agent can still
## report focused while another app owns the caret, which would skip the paste.
func on_hotkey_released(id: int) -> void:
	if id != HOTKEY_ID:
		return
	# Wave marks the press session (mic may be off); ignore stray releases.
	if SenseWave.instance == null or not is_instance_valid(SenseWave.instance):
		return
	busy = true
	SenseWave.show_transcribing()
	var voice_text := await async_transcribe_recording()
	# Reuse the wave pin so the picker opens on the same screen point / width band.
	var picker_anchor := SenseWave.instance.fixed_anchor
	SenseWave.dismiss()
	var picker := SensePicker.open(picker_anchor)
	if picker == null:
		busy = false
		return
	if StringUtils.is_not_blank(voice_text):
		picker.set_entry(SensePicker.SLOT_VOICE, voice_text)
		# Separate coroutines so compose and diverge fill the picker in parallel.
		async_fill_compose(picker, voice_text)
	else:
		# Short press / empty ASR: do not leave voice+compose on "生成中…".
		picker.skip_voice_slots()
	async_fill_diverge(picker)
	var chosen := str(await picker.finished)
	busy = false
	if StringUtils.is_blank(chosen):
		return
	DisplayServer.clipboard_set(chosen)
	if Engine.has_singleton("NativeOS"):
		NativeOS.paste_clipboard()
	Log.info("SenseInput: completed text:[{}]", StringUtils.truncate(chosen, LOG_BODY_MAX))
	pass


## Stop the mic and run ASR when a buffer exists. Returns blank on any soft failure (logs only).
func async_transcribe_recording() -> String:
	if not AudioRecorder.is_active():
		Log.info("SenseInput: mic inactive — diverge-only picker")
		return StringUtils.EMPTY
	var wav := AudioRecorder.stop()
	if wav == null or wav.data.is_empty():
		Log.info("SenseInput: empty recording — diverge-only picker")
		return StringUtils.EMPTY
	var voice_path := CACHE_DIR.path_join(StringUtils.format(VOICE_INPUT_FILE, IdUtils.short_uuid()))
	var err := AudioRecorder.save(wav, voice_path)
	if err != OK:
		Log.info("SenseInput: save failed err:[{}] — diverge-only picker", err)
		return StringUtils.EMPTY
	var absolute := FileUtils.globalize_writable_path(voice_path)
	if StringUtils.is_blank(absolute):
		Log.info("SenseInput: voice path failed — diverge-only picker")
		return StringUtils.EMPTY
	var result := await AudioToTextTool.async_audio_to_text(absolute)
	if result.is_error:
		Log.info("SenseInput: ASR soft-fail:[{}] — diverge-only picker", StringUtils.truncate(result.content, LOG_BODY_MAX))
		return StringUtils.EMPTY
	var voice_text := result.content.strip_edges()
	if StringUtils.is_blank(voice_text):
		Log.info("SenseInput: empty ASR text — diverge-only picker")
		return StringUtils.EMPTY
	return voice_text



## Dispatch compose to local (sequential) or remote (one-shot JSON).
func async_fill_compose(picker: SensePicker, voice_text: String) -> void:
	if use_local_llm:
		await async_fill_compose_local(picker, voice_text)
	else:
		await async_fill_compose_remote(picker, voice_text)
	pass



## Remote compose: one [OpenAiClient] chat returns correct + optimize + expand as JSON via [SensePrompt].
func async_fill_compose_remote(picker: SensePicker, voice_text: String) -> void:
	var screen_context := await async_wait_screen_context()
	if not is_picker_alive(picker):
		return
	var prompt := SensePrompt.compose_user_prompt(voice_text, screen_context, voice_history.to_array())
	var raw := await async_remote_chat(prompt, with_custom_system(SensePrompt.compose_system()))
	if not is_picker_alive(picker):
		return
	var parsed := parse_compose_json(raw)
	var correct := str(parsed.get("correct", ""))
	var optimize := str(parsed.get("optimize", ""))
	var expand := str(parsed.get("expand", ""))
	if StringUtils.is_blank(correct):
		correct = voice_text
	if StringUtils.is_blank(optimize):
		optimize = correct
	if StringUtils.is_blank(expand):
		expand = optimize
	voice_history.add(correct)
	picker.set_entry(SensePicker.SLOT_CORRECT, correct)
	picker.set_entry(SensePicker.SLOT_OPTIMIZE, optimize)
	picker.set_entry(SensePicker.SLOT_EXPAND, expand)
	pass


## Wait up to [constant SCREEN_WAIT_MILLIS] for OCR; returns blank when still pending.
func async_wait_screen_context() -> String:
	var session := sense_session
	var deadline := Time.get_ticks_msec() + SCREEN_WAIT_MILLIS
	while not session.screen_ready and Time.get_ticks_msec() < deadline:
		await ThreadUtils.async_sleep(50)
	return session.screen_text if session.screen_ready else ""


## Remote OpenAI-compatible chat via [ApiSetting].
func async_remote_chat(prompt: String, system_prompt: String) -> String:
	return await ApiSetting.get_client().async_chat(prompt, system_prompt, ApiSetting.get_proxy_address())


## Fill diverge into the open picker when the early guess finishes. Waits while the sheet
## stays open — model latency often exceeds the short screen-OCR wait used for compose.
## Falls back to screen OCR text so the picker always gets a pasteable prediction row.
func async_fill_diverge(picker: SensePicker) -> void:
	var session := sense_session
	while not session.diverge_ready and is_picker_alive(picker):
		await ThreadUtils.async_sleep(50)
	if not is_picker_alive(picker):
		return
	var text := session.diverge_text.strip_edges()
	if StringUtils.is_blank(text):
		text = session.screen_text.strip_edges()
	if StringUtils.is_blank(text):
		Log.info("SenseInput: diverge empty after screen wait")
		return
	picker.set_entry(SensePicker.SLOT_DIVERGE, text)
	pass


func is_picker_alive(picker: Variant) -> bool:
	return picker != null and is_instance_valid(picker) and not picker.closed


## Parses a compose reply into `{ "correct": String, "optimize": String, "expand": String }`. Empty strings on failure.
static func parse_compose_json(raw: String) -> Dictionary:
	var empty := {"correct": StringUtils.EMPTY, "optimize": StringUtils.EMPTY, "expand": StringUtils.EMPTY}
	var text := strip_guess_text(raw)
	var data := JsonUtils.parse_object_lenient(text, PackedStringArray(["correct", "optimize", "expand"]))
	var parsed := {
		"correct": str(data.get("correct", "")).strip_edges(),
		"optimize": str(data.get("optimize", "")).strip_edges(),
		"expand": str(data.get("expand", "")).strip_edges(),
	}
	if StringUtils.is_blank(parsed.correct) and StringUtils.is_blank(parsed.optimize) and StringUtils.is_blank(parsed.expand):
		if StringUtils.is_not_blank(text):
			Log.info("SenseInput: compose fields missing raw:[{}]", StringUtils.truncate(text, LOG_BODY_MAX))
		return empty
	return parsed


## Drop optional quotes / fences from a plain-text model reply.
static func strip_guess_text(raw: String) -> String:
	var text := raw.strip_edges()
	if StringUtils.is_blank(text):
		return StringUtils.EMPTY
	if text.begins_with("```"):
		var first_nl := text.find("\n")
		if first_nl >= 0:
			text = text.substr(first_nl + 1)
		var fence := text.rfind("```")
		if fence >= 0:
			text = text.substr(0, fence)
		text = text.strip_edges()
	if text.length() >= 2:
		var first := text.left(1)
		var last := text.right(1)
		if (first == "\"" and last == "\"") or (first == "'" and last == "'") or (first == "“" and last == "”"):
			text = text.substr(1, text.length() - 2).strip_edges()
	return text


func cleanup_caches() -> void:
	var absolute := ProjectSettings.globalize_path(CACHE_DIR)
	WorkerThreadPool.add_task(func() -> void: FileUtils.cleanup_cache_folder(absolute, MAX_CACHE_BYTES))
	pass


# -----------------------------------------------------------------------------
# Local model requests
# -----------------------------------------------------------------------------

## Capture screenshot → OCR into [param session], then diverge (remote only; local OCR is enough for the picker fallback).
func async_ocr_screen_and_diverge(session: SenseSession) -> void:
	if not Engine.has_singleton("NativeOS"):
		session.screen_ready = true
		session.diverge_ready = true
		return
	var path := CACHE_DIR.path_join(StringUtils.format(SCREEN_INPUT_FILE, IdUtils.short_uuid()))
	var absolute := FileUtils.globalize_writable_path(path)
	if StringUtils.is_blank(absolute):
		Log.error("SenseInput: screen cache path failed")
		session.screen_ready = true
		session.diverge_ready = true
		return
	var ok: bool = NativeOS.capture_screen(absolute)
	if not ok:
		Log.error("SenseInput: capture_screen failed path:[{}]", absolute)
		session.screen_ready = true
		session.diverge_ready = true
		return
	var screen_prompt := with_custom_system(SensePromptLocal.screen_prompt() if use_local_llm else SensePrompt.screen_prompt())
	var text := (await VLMServer.async_image_to_text(absolute, screen_prompt)).strip_edges()
	session.screen_text = text
	session.screen_ready = true
	if session != sense_session:
		return
	# Local: compose chain runs diverge after expand. Mark ready so [method async_fill_diverge] can fall back to OCR.
	if use_local_llm:
		session.diverge_ready = true
		return
	if StringUtils.is_blank(text):
		session.diverge_ready = true
		return
	var prompt := SensePrompt.diverge_user_prompt(text)
	var raw := await async_remote_chat(prompt, with_custom_system(SensePrompt.diverge_system()))
	session.diverge_text = strip_guess_text(raw)
	session.diverge_ready = true
	pass


## Local compose: sequential [VLMServer] plain-text chats — correct → optimize → expand → screen-grounded expansion.
## Each step fills its picker slot as soon as it finishes; later steps continue from the prior draft.
func async_fill_compose_local(picker: SensePicker, voice_text: String) -> void:
	if not is_picker_alive(picker):
		return
	var trimmed_voice := voice_text.strip_edges()
	if trimmed_voice.length() > SensePromptLocal.MAX_ASR_CHARS:
		Log.info("SenseInput: ASR source exceeds local compose limit; preserve source length:[{}]", trimmed_voice.length())
		voice_history.add(trimmed_voice)
		picker.set_entry(SensePicker.SLOT_CORRECT, trimmed_voice)
		picker.set_entry(SensePicker.SLOT_OPTIMIZE, trimmed_voice)
		picker.set_entry(SensePicker.SLOT_EXPAND, trimmed_voice)
		picker.set_entry(SensePicker.SLOT_DIVERGE, trimmed_voice)
		return
	var screen_context := await async_wait_screen_context()
	if not is_picker_alive(picker):
		return
	var correct_raw := await VLMServer.async_chat(SensePromptLocal.correct_user_prompt(voice_text), with_custom_system(SensePromptLocal.correct_screen_system(screen_context)), SensePromptLocal.MAX_TOKENS_CORRECT)
	if not is_picker_alive(picker):
		return
	var correct := SensePromptLocal.parse_step_reply(correct_raw, SensePromptLocal.KEY_CORRECT)
	if SensePromptLocal.is_output_deviated(SensePromptLocal.KEY_CORRECT, voice_text, correct):
		Log.info("SenseInput: correct output drift; retry with ASR only source:[{}] result:[{}]", voice_text.length(), correct.length())
		correct_raw = await VLMServer.async_chat(SensePromptLocal.correct_user_prompt(voice_text), with_custom_system(SensePromptLocal.correct_system()), SensePromptLocal.MAX_TOKENS_CORRECT)
		if not is_picker_alive(picker):
			return
		correct = SensePromptLocal.parse_step_reply(correct_raw, SensePromptLocal.KEY_CORRECT)
	if SensePromptLocal.is_output_deviated(SensePromptLocal.KEY_CORRECT, voice_text, correct):
		Log.info("SenseInput: correct output drift after retry; use ASR source:[{}] result:[{}]", voice_text.length(), correct.length())
		correct = voice_text
	voice_history.add(correct)
	picker.set_entry(SensePicker.SLOT_CORRECT, correct)
	var optimize_raw := await VLMServer.async_chat(SensePromptLocal.optimize_user_prompt(correct), with_custom_system(SensePromptLocal.optimize_screen_system(screen_context)), SensePromptLocal.MAX_TOKENS_OPTIMIZE)
	if not is_picker_alive(picker):
		return
	var optimize := SensePromptLocal.parse_step_reply(optimize_raw, SensePromptLocal.KEY_OPTIMIZE)
	if SensePromptLocal.is_output_deviated(SensePromptLocal.KEY_OPTIMIZE, correct, optimize):
		Log.info("SenseInput: optimize output drift; retry without screen source:[{}] result:[{}]", correct.length(), optimize.length())
		optimize_raw = await VLMServer.async_chat(SensePromptLocal.optimize_user_prompt(correct), with_custom_system(SensePromptLocal.optimize_system()), SensePromptLocal.MAX_TOKENS_OPTIMIZE)
		if not is_picker_alive(picker):
			return
		optimize = SensePromptLocal.parse_step_reply(optimize_raw, SensePromptLocal.KEY_OPTIMIZE)
	if SensePromptLocal.is_output_deviated(SensePromptLocal.KEY_OPTIMIZE, correct, optimize):
		Log.info("SenseInput: optimize output drift after retry; use correct source:[{}] result:[{}]", correct.length(), optimize.length())
		optimize = correct
	picker.set_entry(SensePicker.SLOT_OPTIMIZE, optimize)
	var expand_raw := await VLMServer.async_chat(SensePromptLocal.expand_user_prompt(optimize), with_custom_system(SensePromptLocal.expand_screen_system(screen_context)), SensePromptLocal.MAX_TOKENS_EXPAND)
	if not is_picker_alive(picker):
		return
	var expand := SensePromptLocal.parse_step_reply(expand_raw, SensePromptLocal.KEY_EXPAND)
	if SensePromptLocal.is_output_deviated(SensePromptLocal.KEY_EXPAND, optimize, expand):
		Log.info("SenseInput: expand output drift; retry without screen source:[{}] result:[{}]", optimize.length(), expand.length())
		expand_raw = await VLMServer.async_chat(SensePromptLocal.expand_user_prompt(optimize), with_custom_system(SensePromptLocal.expand_system()), SensePromptLocal.MAX_TOKENS_EXPAND)
		if not is_picker_alive(picker):
			return
		expand = SensePromptLocal.parse_step_reply(expand_raw, SensePromptLocal.KEY_EXPAND)
	if SensePromptLocal.is_output_deviated(SensePromptLocal.KEY_EXPAND, optimize, expand):
		Log.info("SenseInput: expand output drift after retry; use optimize source:[{}] result:[{}]", optimize.length(), expand.length())
		expand = optimize
	picker.set_entry(SensePicker.SLOT_EXPAND, expand)
	var diverge_raw := await VLMServer.async_chat(SensePromptLocal.diverge_simple_user_prompt(expand), with_custom_system(SensePromptLocal.diverge_system(screen_context)), SensePromptLocal.MAX_TOKENS_DIVERGE)
	if not is_picker_alive(picker):
		return
	var diverge := SensePromptLocal.parse_step_reply(diverge_raw, SensePromptLocal.KEY_DIVERGE)
	if SensePromptLocal.is_output_deviated(SensePromptLocal.KEY_DIVERGE, expand, diverge):
		Log.info("SenseInput: diverge output drift; retry without screen source:[{}] result:[{}]", expand.length(), diverge.length())
		diverge_raw = await VLMServer.async_chat(SensePromptLocal.diverge_simple_user_prompt(expand), with_custom_system(SensePromptLocal.diverge_simple_system()), SensePromptLocal.MAX_TOKENS_DIVERGE)
		if not is_picker_alive(picker):
			return
		diverge = SensePromptLocal.parse_step_reply(diverge_raw, SensePromptLocal.KEY_DIVERGE)
	if SensePromptLocal.is_output_deviated(SensePromptLocal.KEY_DIVERGE, expand, diverge):
		Log.info("SenseInput: diverge output drift after retry; use expand source:[{}] result:[{}]", expand.length(), diverge.length())
		diverge = expand
	picker.set_entry(SensePicker.SLOT_DIVERGE, diverge)
	pass
