extends RefCounted

const PIANO_RHYTHM_SCRIPT := preload("res://agent/ui/visuals/piano_rhythm/PianoRhythm.gd")


static func visual_type_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.PIANO_RHYTHM)
	assert(effect.get_script() == PIANO_RHYTHM_SCRIPT)
	effect.free()
	pass


func messages_and_tools_create_rising_notes_test() -> void:
	var effect := PIANO_RHYTHM_SCRIPT.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_message_update(1, "A concise streamed answer for the melody.", OpenAiClient.STREAM_KIND_CONTENT)
	assert(not effect.notes.is_empty())
	var reply_count := effect.notes.size()
	effect.on_tool_execution_start(1, "tool-piano", "read_file", {})
	assert(effect.notes.size() == reply_count + 2)
	assert(effect.notes[reply_count].kind == effect.NoteKind.TOOL_RUNNING)
	effect.free()
	pass


func rising_note_hits_top_keyboard_test() -> void:
	var effect := PIANO_RHYTHM_SCRIPT.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.spawn_note(2, effect.NoteKind.ANSWER, 1.0, 0.0, "")
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


func full_note_capacity_keeps_visible_notes_test() -> void:
	var effect := PIANO_RHYTHM_SCRIPT.new()
	effect.size = Vector2(1280.0, 720.0)
	for index in range(PianoRhythm.MAX_NOTES):
		effect.spawn_note(index % effect.lane_count, effect.NoteKind.ANSWER, 1.0, 0.0, "")
	var first_note := effect.notes[0]
	effect.spawn_note(0, effect.NoteKind.ANSWER, 1.0, 0.0, "")
	assert(effect.notes.size() == PianoRhythm.MAX_NOTES)
	assert(effect.notes[0] == first_note)
	effect.free()
	pass
