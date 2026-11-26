## Unit tests for the direct voice-input helpers. Loaded by [code]SenseInputTest.tscn[/code].

## [method SenseWave.window_position_for_anchor] centers the wave window on the anchor.
func wave_window_position_for_anchor_test() -> void:
	var anchor := Vector2i(200, 300)
	var window_size := Vector2i(SenseWave.WAVE_WIDTH, SenseWave.WAVE_HEIGHT)
	var pos := SenseWave.window_position_for_anchor(anchor, window_size)
	assert(pos == anchor - Vector2i(window_size.x / 2, window_size.y / 2))
	pass


## Loud input rises quickly, while release remains smooth and preserves a short-lived peak.
func sense_wave_energy_response_test() -> void:
	var wave := SenseWave.new()
	wave.update_energy(1.0, 0.1)
	var raised_energy := wave.energy
	assert(raised_energy > 0.7)
	assert(wave.attack > 0.0)
	assert(wave.peak >= wave.attack)
	wave.update_energy(0.0, 0.1)
	assert(wave.energy > 0.0)
	assert(wave.energy < raised_energy)
	wave.free()
	pass


## Input is clamped before it reaches the visual state.
func sense_wave_energy_clamps_input_test() -> void:
	var wave := SenseWave.new()
	wave.update_energy(4.0, 1.0)
	assert(wave.energy <= 1.0)
	wave.free()
	pass


func sense_wave_quiet_voice_is_visually_amplified_test() -> void:
	var wave := SenseWave.new()
	wave.update_energy(0.05, 1.0)
	assert(wave.energy > 0.25)
	wave.free()
	pass


func sense_wave_continuous_speech_creates_syllable_motion_test() -> void:
	var wave := SenseWave.new()
	for i in range(12):
		wave.update_energy(0.08, 0.03)
	wave.update_energy(0.22, 0.03)
	assert(wave.syllable > 0.1)
	assert(wave.activity > 0.0)
	assert(wave.ripple_history[SenseWave.RIPPLE_HISTORY_SIZE - 1] > 0.0)
	wave.free()
	pass


## [method DisplayScale.compute_screen_scale] uses the screen containing the supplied anchor.
func compute_screen_scale_test() -> void:
	var anchor := Vector2i(200, 300)
	var screen := DisplayServer.get_screen_from_rect(Rect2(Vector2(anchor), Vector2.ONE))
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var expected := float(usable.size.x) / float(DisplayScale.REF_SCREEN_WIDTH) if usable.size.x > 0 else 1.0
	assert(is_equal_approx(DisplayScale.compute_screen_scale(anchor), expected))
	pass


## [method SenseWave.active_screen_center] is the active screen's usable-rect midpoint.
func active_screen_center_test() -> void:
	var mouse := DisplayServer.mouse_get_position()
	var rect := ScreenUtils.usable_rect()
	var center := SenseWave.active_screen_center()
	if rect.size.x <= 0 or rect.size.y <= 0:
		assert(center == mouse)
		return
	assert(center == rect.position + rect.size / 2)
	pass


## Missing audio paths fail before starting the local transcription process.
func missing_audio_file_test() -> void:
	var result := await SenseInput.async_audio_to_text("user://sense/missing.wav")
	assert(result.is_error)
	assert(result.content.contains("audio not found"))
	pass
