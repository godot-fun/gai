## Unit tests for Sense input helpers. Loaded by [code]SenseInputTest.tscn[/code] ([UnitTest]).

## [method SenseWave.window_position_for_cursor] centers the wave window just below-right of the anchor.
func window_position_for_cursor_test() -> void:
	var cursor := Vector2i(200, 300)
	var window_size := Vector2i(SenseWave.WAVE_WIDTH, SenseWave.WAVE_HEIGHT)
	var pos := SenseWave.window_position_for_cursor(cursor, window_size)
	assert(pos == cursor + SenseWave.CURSOR_OFFSET - Vector2i(window_size.x / 2, window_size.y / 2))
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


## [method SensePicker.window_position_for_anchor] matches the wave top-left for the same width.
func window_position_for_anchor_test() -> void:
	var anchor := Vector2i(200, 300)
	var scale := 1.5
	var window_size := Vector2i(roundi(float(SenseWave.WAVE_WIDTH) * scale), 400)
	var pos := SensePicker.window_position_for_anchor(anchor, window_size, scale)
	var wave_size := Vector2i(window_size.x, roundi(float(SenseWave.WAVE_HEIGHT) * scale))
	assert(pos == SenseWave.window_position_for_cursor(anchor, wave_size))
	pass


## [method DisplayScale.compute_screen_scale] is usable width / 2K reference (not app UI scale).
func compute_screen_scale_test() -> void:
	var anchor := Vector2i(200, 300)
	var screen := DisplayServer.get_screen_from_rect(Rect2(Vector2(anchor), Vector2.ONE))
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var expected := float(usable.size.x) / float(DisplayScale.REF_SCREEN_WIDTH) if usable.size.x > 0 else 1.0
	assert(is_equal_approx(DisplayScale.compute_screen_scale(anchor), expected))
	pass


## [method SensePicker.move_selection] walks ready slots + cancel and wraps; [method SensePicker.find_nearest_ready] fills gaps.
func sense_picker_selection_nav_test() -> void:
	var picker := SensePicker.new()
	picker.entry_ready[0] = true
	picker.entry_ready[2] = true
	picker.entry_ready[4] = true
	picker.set_selected_index(0)
	assert(picker.selected_index == 0)
	picker.move_selection(1)
	assert(picker.selected_index == 2)
	picker.move_selection(1)
	assert(picker.selected_index == 4)
	picker.move_selection(1)
	assert(picker.selected_index == SensePicker.SLOT_CANCEL)
	picker.move_selection(1)
	assert(picker.selected_index == 0)
	picker.move_selection(-1)
	assert(picker.selected_index == SensePicker.SLOT_CANCEL)
	assert(picker.find_nearest_ready(1) == 2)
	assert(picker.find_nearest_ready(3) == 4)
	assert(picker.find_nearest_ready(5) == 4)
	for i in SensePicker.SLOT_COUNT:
		picker.entry_ready[i] = false
	assert(picker.find_nearest_ready(2) == -1)
	picker.move_selection(1)
	assert(picker.selected_index == SensePicker.SLOT_CANCEL)
	picker.free()
	pass


## [method SenseInput.strip_guess_text] trims fences and wrapping quotes from model replies.
func strip_guess_text_test() -> void:
	assert(SenseInput.strip_guess_text('  hello  ') == "hello")
	assert(SenseInput.strip_guess_text('"quoted"') == "quoted")
	assert(SenseInput.strip_guess_text("```\nguess\n```") == "guess")
	assert(SenseInput.strip_guess_text("") == "")
	pass


## [method SenseInput.parse_compose_json] reads correct + optimize + expand from a JSON model reply.
func parse_compose_json_test() -> void:
	var ok := SenseInput.parse_compose_json('{"correct":"fixed","optimize":"polished","expand":"fuller"}')
	assert(ok.correct == "fixed")
	assert(ok.optimize == "polished")
	assert(ok.expand == "fuller")
	var fenced := SenseInput.parse_compose_json("```json\n{\"correct\":\"a\",\"optimize\":\"b\",\"expand\":\"c\"}\n```")
	assert(fenced.correct == "a")
	assert(fenced.optimize == "b")
	assert(fenced.expand == "c")
	var wrapped := SenseInput.parse_compose_json('Here you go: {"correct":"x","optimize":"y","expand":"z"} thanks')
	assert(wrapped.correct == "x")
	assert(wrapped.optimize == "y")
	assert(wrapped.expand == "z")
	var legacy := SenseInput.parse_compose_json('{"correct":"fixed","optimize":"polished"}')
	assert(legacy.correct == "fixed")
	assert(legacy.optimize == "polished")
	assert(legacy.expand == "")
	var escaped := SenseInput.parse_compose_json('{"correct":"say \\"hi\\"","optimize":"line\\n2","expand":"ok"}')
	assert(escaped.correct == "say \"hi\"")
	assert(escaped.optimize == "line\n2")
	assert(escaped.expand == "ok")
	pass


## Invalid compose replies: empty fields, no [code]log_error[/code] from failed strict JSON (UnitTest watches it).
func parse_compose_json_invalid_test() -> void:
	var empty := SenseInput.parse_compose_json("")
	assert(empty.correct == "")
	assert(empty.optimize == "")
	assert(empty.expand == "")
	var bad := SenseInput.parse_compose_json("not json")
	assert(bad.correct == "")
	assert(bad.optimize == "")
	assert(bad.expand == "")
	# Godot JSON.parse accepts a single trailing comma; double comma forces extraction fallback.
	var trailing := SenseInput.parse_compose_json('{"correct":"a","optimize":"b","expand":"c",}')
	assert(trailing.correct == "a")
	assert(trailing.optimize == "b")
	assert(trailing.expand == "c")
	var junk := SenseInput.parse_compose_json('{"correct":"a","optimize":"b","expand":"c",,}')
	assert(junk.correct == "a")
	assert(junk.optimize == "b")
	assert(junk.expand == "c")
	var broken := SenseInput.parse_compose_json('{"correct": "unterminated')
	assert(broken.correct == "")
	assert(broken.optimize == "")
	assert(broken.expand == "")
	var missing_brace := SenseInput.parse_compose_json('{"correct":"a"')
	assert(missing_brace.correct == "")
	assert(missing_brace.optimize == "")
	assert(missing_brace.expand == "")
	var wrong_keys := SenseInput.parse_compose_json('{"other":"x"}')
	assert(wrong_keys.correct == "")
	assert(wrong_keys.optimize == "")
	assert(wrong_keys.expand == "")
	# Non-string values + failed strict parse → string-field fallback yields empty compose fields.
	var numbers := SenseInput.parse_compose_json('{"correct":1,"optimize":2,"expand":3,,}')
	assert(numbers.correct == "")
	assert(numbers.optimize == "")
	assert(numbers.expand == "")
	pass


## [SensePrompt] returns Chinese or English remote prompts from the app locale.
func sense_prompt_locale_test() -> void:
	var previous := I18n.get_locale()
	var empty_history: Array[String] = []
	var prompt_script := preload("res://agent/app/sense/SensePrompt.gd")
	Setting.set_string(I18n.LOCALE_SETTING_KEY, I18n.EN)
	assert(not prompt_script.use_chinese())
	assert(prompt_script.screen_prompt() == prompt_script.SCREEN_PROMPT_EN)
	assert(prompt_script.screen_seed_system() == prompt_script.SCREEN_SEED_SYSTEM_EN)
	assert(prompt_script.compose_system() == prompt_script.COMPOSE_SYSTEM_EN)
	assert(prompt_script.diverge_system() == prompt_script.DIVERGE_SYSTEM_EN)
	assert(prompt_script.diverge_user_prompt("ui").contains("Screen context"))
	var en_user := prompt_script.compose_user_prompt("hi", "", empty_history)
	assert(en_user.contains("ASR transcript"))
	assert(en_user.contains("(unavailable)"))
	assert(en_user.contains("(none)"))
	Setting.set_string(I18n.LOCALE_SETTING_KEY, I18n.ZH)
	assert(prompt_script.use_chinese())
	assert(prompt_script.screen_prompt() == prompt_script.SCREEN_PROMPT_ZH)
	assert(prompt_script.screen_seed_system() == prompt_script.SCREEN_SEED_SYSTEM_ZH)
	assert(prompt_script.compose_system() == prompt_script.COMPOSE_SYSTEM_ZH)
	assert(prompt_script.diverge_system() == prompt_script.DIVERGE_SYSTEM_ZH)
	assert(prompt_script.diverge_user_prompt("界面").contains("屏幕上下文"))
	var zh_user := prompt_script.compose_user_prompt("你好", "", empty_history)
	assert(zh_user.contains("语音识别文本"))
	assert(zh_user.contains("（不可用）"))
	assert(zh_user.contains("（无）"))
	Setting.set_string(I18n.LOCALE_SETTING_KEY, previous)
	pass


## [SensePromptLocal] returns short locale-matched plain-text prompts and clamps long inputs.
func sense_prompt_local_locale_test() -> void:
	var previous := I18n.get_locale()
	var prompt_script := preload("res://agent/app/sense/SensePromptLocal.gd")
	Setting.set_string(I18n.LOCALE_SETTING_KEY, I18n.EN)
	assert(not prompt_script.use_chinese())
	assert(prompt_script.screen_prompt() == prompt_script.SCREEN_PROMPT_EN)
	assert(prompt_script.screen_prompt().contains("main center pane"))
	assert(prompt_script.screen_prompt().contains("at most 6 lines"))
	assert(prompt_script.screen_prompt().contains("FOCUS:"))
	assert(prompt_script.screen_seed_system().contains(prompt_script.SCREEN_SEED_SYSTEM_EN))
	assert(prompt_script.screen_seed_user_prompt() == prompt_script.SCREEN_SEED_USER_EN)
	assert(prompt_script.screen_seed_system("Settings").contains("<screen_reference>"))
	assert(prompt_script.screen_seed_system("Settings").contains("Settings"))
	assert(prompt_script.correct_screen_system().contains("same language"))
	assert(prompt_script.correct_system().contains("corrected text only"))
	assert(prompt_script.optimize_system().contains("polished text only"))
	assert(prompt_script.expand_system().contains("expanded text only"))
	assert(not prompt_script.diverge_system().contains("JSON"))
	assert(prompt_script.diverge_system().contains("Do not guess"))
	assert(prompt_script.diverge_system().contains("Further expand"))
	assert(prompt_script.diverge_system("ui").contains("<screen_reference>"))
	assert(prompt_script.diverge_system("ui").contains("ui"))
	assert(prompt_script.diverge_user_prompt("draft", "ui") == "draft")
	var en_simple_diverge := prompt_script.diverge_simple_user_prompt("expand")
	assert(en_simple_diverge == "expand")
	var en_screen_correct := prompt_script.correct_screen_user_prompt("hi", "Settings")
	assert(en_screen_correct == "hi")
	assert(prompt_script.correct_screen_system("Settings").contains("Settings"))
	var en_correct := prompt_script.correct_user_prompt("hi")
	assert(en_correct == "hi")
	assert(prompt_script.optimize_user_prompt("draft") == "draft")
	var en_screen_optimize := prompt_script.optimize_screen_user_prompt("correct", "Settings")
	assert(en_screen_optimize == "correct")
	assert(prompt_script.optimize_screen_system("Settings").contains("Settings"))
	assert(prompt_script.expand_user_prompt("draft") == "draft")
	var en_screen_expand := prompt_script.expand_screen_user_prompt("optimize", "Settings")
	assert(en_screen_expand == "optimize")
	assert(prompt_script.expand_screen_system("Settings").contains("Settings"))
	var long_asr := "a".repeat(prompt_script.MAX_ASR_CHARS + 40)
	var clamped := prompt_script.correct_screen_user_prompt(long_asr, "")
	assert(clamped.length() < long_asr.length() + 80)
	Setting.set_string(I18n.LOCALE_SETTING_KEY, I18n.ZH)
	assert(prompt_script.use_chinese())
	assert(prompt_script.screen_prompt() == prompt_script.SCREEN_PROMPT_ZH)
	assert(prompt_script.screen_prompt().contains("中央主面板"))
	assert(prompt_script.screen_prompt().contains("最多 6 行"))
	assert(prompt_script.screen_prompt().contains("FOCUS："))
	assert(prompt_script.screen_seed_system().contains(prompt_script.SCREEN_SEED_SYSTEM_ZH))
	assert(prompt_script.screen_seed_user_prompt() == prompt_script.SCREEN_SEED_USER_ZH)
	assert(prompt_script.screen_seed_system("设置").contains("<屏幕参考>"))
	assert(prompt_script.screen_seed_system("设置").contains("设置"))
	assert(prompt_script.correct_screen_system().contains("中文输入只输出中文"))
	assert(prompt_script.correct_system().contains("禁止翻译成英文"))
	assert(prompt_script.optimize_screen_system().contains("已修正文本"))
	assert(prompt_script.expand_screen_system().contains("已润色文本"))
	assert(not prompt_script.diverge_simple_system().contains("JSON"))
	assert(prompt_script.diverge_system().contains("禁止猜测"))
	assert(prompt_script.diverge_system().contains("继续扩展"))
	assert(prompt_script.diverge_user_prompt("草稿", "界面") == "草稿")
	assert(prompt_script.diverge_system("界面").contains("<屏幕参考>"))
	assert(prompt_script.diverge_system("界面").contains("界面"))
	var zh_correct := prompt_script.correct_screen_user_prompt("你好", "")
	assert(zh_correct == "你好")
	assert(prompt_script.correct_screen_system("").contains("（不可用）"))
	Setting.set_string(I18n.LOCALE_SETTING_KEY, previous)
	pass


## Local correction retries only when output length is clearly detached from the ASR source.
func sense_prompt_local_correct_length_deviation_test() -> void:
	assert(not SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_CORRECT, "帮我打开设置", "请帮我打开设置"))
	assert(not SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_CORRECT, "abcdefghij", "abcdefghijklmno"))
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_CORRECT, "abcdefghij", "abcdefghijklmnop"))
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_CORRECT, "abcdefghij", "abcd"))
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_CORRECT, "hello", ""))
	pass


## Chinese source text translated wholly to English triggers the no-screen retry path.
func sense_prompt_local_language_deviation_test() -> void:
	assert(SensePromptLocal.is_language_deviated("帮我打开设置", "Please open Settings"))
	assert(not SensePromptLocal.is_language_deviated("帮我打开设置", "请打开 Settings"))
	assert(not SensePromptLocal.is_language_deviated("open settings", "打开设置"))
	pass


## Combined output validation rejects either length drift or a full language change.
func sense_prompt_local_output_deviation_test() -> void:
	assert(SensePromptLocal.is_output_deviated(SensePromptLocal.KEY_CORRECT, "帮我打开设置", "Please open Settings"))
	assert(SensePromptLocal.is_output_deviated(SensePromptLocal.KEY_CORRECT, "abcdefghij", "abcd"))
	assert(not SensePromptLocal.is_output_deviated(SensePromptLocal.KEY_CORRECT, "帮我打开设置", "请帮我打开设置"))
	pass


## OPTIMIZE permits more length change than CORRECT, then rejects clear screen-driven drift.
func sense_prompt_local_optimize_length_deviation_test() -> void:
	var source := "abcdefghij"
	var moderate_growth := "abcdefghijklmnop"
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_CORRECT, source, moderate_growth))
	assert(not SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_OPTIMIZE, source, moderate_growth))
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_OPTIMIZE, source, "abcdefghijklmnopqrs"))
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_OPTIMIZE, source, "abcd"))
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_OPTIMIZE, source, ""))
	pass


## EXPAND accepts substantial growth, but retries when screen context overwhelms the draft.
func sense_prompt_local_expand_length_deviation_test() -> void:
	var source := "abcdefghij"
	assert(not SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_EXPAND, source, "abcdefghijklmnopqrstuvwxyz1234"))
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_EXPAND, source, "abcdefghijklmnopqrstuvwxyz12345"))
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_EXPAND, source, "abcdefg"))
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_EXPAND, source, ""))
	pass


## DIVERGE retries without screen when its second expansion is no longer source-sized.
func sense_prompt_local_diverge_length_deviation_test() -> void:
	var source := "abcdefghij"
	assert(not SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_DIVERGE, source, "abcdefghijklmnopqrstuvwxyz12345678"))
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_DIVERGE, source, "abcdefghijklmnopqrstuvwxyz123456789"))
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_DIVERGE, source, "abcdefg"))
	assert(SensePromptLocal.is_length_deviated(SensePromptLocal.KEY_DIVERGE, source, ""))
	assert(SensePromptLocal.is_length_deviated("unknown", source, source))
	pass


## [method SensePromptLocal.parse_step_reply] reads plain text and remains compatible with old JSON replies.
func sense_prompt_local_parse_step_reply_test() -> void:
	assert(SensePromptLocal.parse_step_reply("直接回复", SensePromptLocal.KEY_CORRECT) == "直接回复")
	assert(SensePromptLocal.parse_step_reply("```text\npolished\n```", SensePromptLocal.KEY_OPTIMIZE) == "polished")
	assert(SensePromptLocal.parse_step_reply('{"correct":"fixed"}', SensePromptLocal.KEY_CORRECT) == "fixed")
	assert(SensePromptLocal.parse_step_reply('Here: {"optimize":"polished"} ok', SensePromptLocal.KEY_OPTIMIZE) == "polished")
	assert(SensePromptLocal.parse_step_reply('{"other":"x"}', SensePromptLocal.KEY_CORRECT) == "")
	assert(SensePromptLocal.parse_step_reply("保留 {name} 占位符", SensePromptLocal.KEY_CORRECT) == "保留 {name} 占位符")
	pass


func sense_custom_system_prompt_test() -> void:
	var previous := SenseSetting.get_system_prompt()
	SenseSetting.set_system_prompt("")
	assert(SenseSetting.append_system_prompt("base") == "base")
	SenseSetting.set_system_prompt("Write concise answers.")
	var combined := SenseSetting.append_system_prompt("base")
	assert(combined.begins_with("base\n\n<user_system_prompt>"))
	assert(combined.contains("Write concise answers."))
	SenseSetting.set_system_prompt(previous)
	pass


## The leading library templates fill the results list before the user searches; typing searches the whole library.
func sense_prompt_default_template_test() -> void:
	var previous_locale := Setting.get_string(I18n.LOCALE_SETTING_KEY)
	var sense_button := SenseButton.new()
	sense_button.setup(Button.new(), null)
	assert(sense_button.search_edit.keep_editing_on_text_submit)
	for locale: String in [I18n.ZH, I18n.EN]:
		Setting.set_string(I18n.LOCALE_SETTING_KEY, locale)
		sense_button.load_prompt_entries()
		assert(sense_button.prompt_entries.size() > SenseButton.DEFAULT_TEMPLATE_COUNT)
		sense_button.refresh_results("")
		assert(sense_button.results.item_count == SenseButton.DEFAULT_TEMPLATE_COUNT)
		var template_title := sense_button.results.get_item_text(0)
		assert(not template_title.is_empty())
		assert(str(sense_button.results.get_item_metadata(0)) == sense_button.prompt_entries.get_value(template_title))
		sense_button.refresh_results(template_title)
		assert(sense_button.results.item_count > 0 and sense_button.results.item_count <= SenseButton.MAX_RESULTS)
	sense_button.button.free()
	Setting.set_string(I18n.LOCALE_SETTING_KEY, previous_locale)
	pass


func sense_hotkey_text_test() -> void:
	assert(SenseSetting.hotkey_text(SenseSetting.DEFAULT_HOTKEY_KEY, SenseSetting.DEFAULT_HOTKEY_MODIFIERS) == "Alt+Z")
	assert(SenseSetting.hotkey_text(KEY_Z, KEY_MASK_CTRL | KEY_MASK_ALT) == "Ctrl+Alt+Z")
	assert(SenseSetting.hotkey_text(KEY_F9, KEY_MASK_CTRL | KEY_MASK_SHIFT) == "Ctrl+Shift+F9")
	pass


## Voice history keeps at most six corrected (or ASR fallback) strings in memory (oldest dropped first).
func voice_history_capacity_test() -> void:
	var sense := SenseInput.new()
	for i in 8:
		sense.voice_history.add(str(i))
	assert(sense.voice_history.size() == 6)
	assert(sense.voice_history.to_array() == ["2", "3", "4", "5", "6", "7"])
	pass


## A new press replaces [member SenseInput.sense_session]; waiters hold the old instance and ignore stale writes.
func sense_session_replace_test() -> void:
	var sense := SenseInput.new()
	var old_session := sense.sense_session
	old_session.screen_text = "ocr"
	old_session.screen_ready = true
	old_session.diverge_text = "guess"
	old_session.diverge_ready = true
	sense.sense_session = SenseInput.SenseSession.new()
	assert(sense.sense_session != old_session)
	assert(not sense.sense_session.screen_ready)
	assert(not sense.sense_session.diverge_ready)
	assert(old_session.screen_text == "ocr")
	assert(old_session.diverge_text == "guess")
	pass


## [method SenseCaretLocator.resolve_anchor] always returns a finite screen point (TextEdit, OS caret, or screen center).
func resolve_anchor_test() -> void:
	var anchor := SenseCaretLocator.resolve_anchor()
	assert(anchor.x > -1000000 and anchor.x < 1000000)
	assert(anchor.y > -1000000 and anchor.y < 1000000)
	pass


## [method SenseCaretLocator.focused_screen_center] is the usable-rect midpoint of the screen under the mouse.
func focused_screen_center_test() -> void:
	var mouse := DisplayServer.mouse_get_position()
	var screen := DisplayServer.get_screen_from_rect(Rect2(Vector2(mouse), Vector2.ONE))
	var rect: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var center := SenseCaretLocator.focused_screen_center()
	if rect.size.x <= 0 or rect.size.y <= 0:
		assert(center == mouse)
		return
	assert(center == rect.position + rect.size / 2)
	pass


## [method SenseCaretLocator.godot_focus_anchor] is null when no Godot window is focused; otherwise caret or mouse.
func godot_focus_anchor_test() -> void:
	var anchor: Variant = SenseCaretLocator.godot_focus_anchor()
	var window := Window.get_focused_window()
	if window == null:
		assert(anchor == null)
		return
	assert(anchor is Vector2i)
	var focus: Control = window.gui_get_focus_owner()
	if focus is TextEdit:
		var text_edit := focus as TextEdit
		var viewport: Viewport = text_edit.get_viewport()
		assert(viewport != null)
		var canvas_pos: Vector2 = text_edit.get_global_transform_with_canvas() * text_edit.get_caret_draw_pos()
		var window_pos: Vector2 = viewport.get_final_transform() * canvas_pos
		var origin := DisplayServer.window_get_position(viewport.get_window_id())
		assert(anchor == origin + Vector2i(roundi(window_pos.x), roundi(window_pos.y)))
	else:
		assert(anchor == DisplayServer.mouse_get_position())
	pass
