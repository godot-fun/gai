extends RefCounted

const PIANO_RHYTHM_SCRIPT := preload("res://agent/ui/visuals/piano_rhythm/PianoRhythm.gd")


static func visual_type_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIANO_RHYTHM)
	assert(effect.get_script() == PIANO_RHYTHM_SCRIPT)
	effect.free()
	pass


func every_event_generates_one_note_on_a_fixed_beat_test() -> void:
	var effect := PIANO_RHYTHM_SCRIPT.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.visible = true
	effect.on_message_update(1, "A concise streamed answer for the melody.", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.notes.size() == 1)
	# A second event inside the beat is dropped rather than stacked or queued.
	effect.on_message_update(1, "A second streamed chunk.", OpenAiClient.STREAM_KIND_CONTENT)
	effect.on_tool_execution_start(1, "tool-piano", "read_file", {})
	assert(effect.notes.size() == 1)
	effect._process(PianoRhythm.NOTE_SPAWN_INTERVAL * 0.5)
	effect.on_message_update(1, "A third streamed chunk.", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.notes.size() == 1)
	effect._process(PianoRhythm.NOTE_SPAWN_INTERVAL * 0.5)
	effect.on_message_update(1, "A fourth streamed chunk.", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.notes.size() == 2)
	effect.free()
	pass


func tool_events_generate_one_note_test() -> void:
	var effect := PIANO_RHYTHM_SCRIPT.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_tool_execution_start(1, "tool-piano", "read_file", {})
	assert(effect.notes.size() == 1)
	assert(effect.notes[0].kind == effect.NoteKind.TOOL_RUNNING)
	effect.free()
	pass


func white_key_lanes_are_one_to_one_test() -> void:
	var effect := PIANO_RHYTHM_SCRIPT.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.ensure_layout()
	assert(effect.lane_count == PianoRhythm.WHITE_KEY_COUNT)
	var key_width := effect.size.x / float(PianoRhythm.WHITE_KEY_COUNT)
	for lane in range(effect.lane_count):
		assert(is_equal_approx(effect.key_center_for_lane(lane), (float(lane) + 0.5) * key_width))
	effect.free()
	pass


func rising_note_hits_top_keyboard_test() -> void:
	var effect := PIANO_RHYTHM_SCRIPT.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.spawn_note(2, effect.NoteKind.ANSWER)
	effect.notes[0].y = effect.hit_y() + 1.0
	effect.visible = true
	effect._process(0.1)
	assert(effect.notes[0].state == effect.NoteState.HIT)
	assert(effect.key_glows[2] > 0.0)
	effect.free()
	pass


func failed_tool_uses_error_note_test() -> void:
	var effect := PIANO_RHYTHM_SCRIPT.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_tool_execution_end(1, "tool-piano", "read_file", AgentToolResult.error("no access"))
	assert(effect.notes.size() == 1)
	assert(effect.notes[0].kind == effect.NoteKind.TOOL_FAILED)
	effect.free()
	pass


func floating_line_rises_and_fades_test() -> void:
	var effect := PIANO_RHYTHM_SCRIPT.new()
	effect.size = Vector2(1280.0, 720.0)
	var note := effect.PianoNote.new()
	note.lane = 2
	note.kind = effect.NoteKind.ANSWER
	note.sentence_text = "Floating melody text."
	note.weight = 0.5
	var origin := Vector2(effect.key_center_for_lane(note.lane), effect.hit_y())
	effect.spawn_floating_line("Floating melody text.", origin, effect.note_color_for_note(note))
	assert(effect.floating_lines.size() == 1)
	var start_y := effect.floating_lines[0].position.y
	effect._process(0.5)
	assert(effect.floating_lines[0].position.y < start_y)
	effect._process(effect.FLOAT_LINE_LIFE)
	assert(effect.floating_lines.is_empty())
	effect.free()
	pass


func sentence_weight_drives_speed_and_font_band_test() -> void:
	var effect := PIANO_RHYTHM_SCRIPT.new()
	effect.size = Vector2(1280.0, 720.0)
	var short_text := "短。"
	var long_text := "A longer sentence gives the note more weight across speed, particles, and floating text."
	var short_weight := effect.weight_for_sentence(short_text, effect.NoteKind.ANSWER)
	var long_weight := effect.weight_for_sentence(long_text, effect.NoteKind.ANSWER)
	assert(long_weight > short_weight)
	assert(effect.speed_for_weight(long_weight) > effect.speed_for_weight(short_weight))
	var soft := effect.PianoNote.new()
	soft.weight = short_weight
	var hard := effect.PianoNote.new()
	hard.weight = long_weight
	var soft_band := effect.floating_font_band_for_note(soft)
	var hard_band := effect.floating_font_band_for_note(hard)
	assert(hard_band.x > soft_band.y)
	assert(hard_band.y - hard_band.x > soft_band.y - soft_band.x)
	effect.free()
	pass


func rest_note_impact_skips_floating_line_test() -> void:
	var effect := PIANO_RHYTHM_SCRIPT.new()
	effect.size = Vector2(1280.0, 720.0)
	var note := effect.PianoNote.new()
	note.is_rest = true
	effect.spawn_floating_line_on_impact(note)
	assert(effect.floating_lines.is_empty())
	effect.free()
	pass


func full_note_capacity_keeps_visible_notes_test() -> void:
	var effect := PIANO_RHYTHM_SCRIPT.new()
	effect.size = Vector2(1280.0, 720.0)
	for index in range(PianoRhythm.MAX_NOTES):
		effect.spawn_note(index % effect.lane_count, effect.NoteKind.ANSWER)
	var first_note := effect.notes[0]
	effect.spawn_note(0, effect.NoteKind.ANSWER)
	assert(effect.notes.size() == PianoRhythm.MAX_NOTES)
	assert(effect.notes[0] == first_note)
	effect.free()
	pass


func stem_direction_follows_pitch_test() -> void:
	assert(MusicNotationRenderer.stem_points_up(PackedInt32Array([-1])))
	assert(not MusicNotationRenderer.stem_points_up(PackedInt32Array([1])))
	assert(not MusicNotationRenderer.stem_points_up(PackedInt32Array([0])))
	# The head farthest from the middle line decides, so a low chord keeps the stem up.
	assert(MusicNotationRenderer.stem_points_up(PackedInt32Array([-4, 0, 3])))
	assert(not MusicNotationRenderer.stem_points_up(PackedInt32Array([0, 5])))
	pass


func chord_heads_merge_base_step_without_duplicates_test() -> void:
	var note := MusicNotationRenderer.Note.new()
	note.step = 0
	note.chord_steps = PackedInt32Array([0, 4])
	var steps := MusicNotationRenderer.chord_steps_for(note)
	assert(steps.size() == 2)
	assert(steps[0] == 0)
	assert(steps[1] == 4)
	var heads := MusicNotationRenderer.layout_heads(steps, Vector2.ZERO, MusicNotationRenderer.HEAD_WIDTH)
	assert(heads.size() == 2)
	assert(is_equal_approx(heads[0].y - heads[1].y, MusicNotationRenderer.STEP * 4.0))
	pass


func second_interval_splits_heads_horizontally_test() -> void:
	var steps := PackedInt32Array([0, 1])
	var heads := MusicNotationRenderer.layout_heads(steps, Vector2.ZERO, MusicNotationRenderer.HEAD_WIDTH)
	assert(is_equal_approx(heads[1].x, MusicNotationRenderer.HEAD_WIDTH * 0.62))
	pass


func glyph_bottom_clears_stems_and_dynamics_test() -> void:
	var down_stem := MusicNotationRenderer.Note.new()
	assert(MusicNotationRenderer.glyph_bottom(down_stem) >= MusicNotationRenderer.STEM_LENGTH)
	var low_chord := MusicNotationRenderer.Note.new()
	low_chord.chord_steps = PackedInt32Array([-3])
	var up_stem := MusicNotationRenderer.Note.new()
	up_stem.step = -1
	assert(MusicNotationRenderer.glyph_bottom(low_chord) > MusicNotationRenderer.glyph_bottom(up_stem))
	var with_dynamic := MusicNotationRenderer.Note.new()
	with_dynamic.step = -1
	with_dynamic.dynamic_mark = "p"
	assert(MusicNotationRenderer.glyph_bottom(with_dynamic) > MusicNotationRenderer.glyph_bottom(up_stem))
	pass
