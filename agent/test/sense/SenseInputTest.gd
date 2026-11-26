## Unit tests for the direct voice-input helpers. Loaded by [code]SenseInputTest.tscn[/code].

## [method SenseWave.window_position_for_anchor] centers the wave window on the anchor.
func wave_window_position_for_anchor_test() -> void:
	var anchor := Vector2i(200, 300)
	var window_size := Vector2i(SenseWave.WAVE_WIDTH, SenseWave.WAVE_HEIGHT)
	var pos := SenseWave.window_position_for_anchor(anchor, window_size)
	assert(pos == anchor - Vector2i(window_size.x / 2, window_size.y / 2))
	pass


## Slow frames interpolate skipped history columns instead of creating a sharp amplitude wall.
func sense_wave_history_interpolation_test() -> void:
	var wave := SenseWave.new()
	wave.reset_volume_history()
	wave.push_volume_history(1.0, 4.0, 1.0)
	assert(is_equal_approx(wave.volume_history[SenseWave.WAVE_WIDTH - 4], 0.25))
	assert(is_equal_approx(wave.volume_history[SenseWave.WAVE_WIDTH - 3], 0.5))
	assert(is_equal_approx(wave.volume_history[SenseWave.WAVE_WIDTH - 2], 0.75))
	assert(is_equal_approx(wave.volume_history[SenseWave.WAVE_WIDTH - 1], 1.0))
	wave.free()
	pass


## Painting uses neighboring history values to suppress isolated one-column spikes.
func sense_wave_history_smoothing_test() -> void:
	var wave := SenseWave.new()
	wave.reset_volume_history()
	var center := SenseWave.WAVE_WIDTH / 2
	wave.volume_history[center] = 1.0
	assert(is_equal_approx(wave.smoothed_history_level(center), 19.0 / 81.0))
	assert(is_equal_approx(wave.smoothed_history_level(center - 1), 16.0 / 81.0))
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
