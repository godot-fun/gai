class_name PianoRhythm
extends VisualEffect

## An inverted piano-roll overlay: notes rise from the reading area and resolve into
## a compact keyboard at the top, leaving the lower chat surface unobstructed.

const MIN_LANES := 6
const MAX_LANES := 12
const MIN_LANE_WIDTH := 72.0
const KEYBOARD_TOP := 0.0
const MIN_KEYBOARD_HEIGHT := 132.0
const MAX_KEYBOARD_HEIGHT := 190.0
const HIT_GAP := 18.0
const WHITE_KEY_COUNT := 52
const BLACK_KEY_HEIGHT_RATIO := 0.62
const BLACK_KEY_WIDTH_RATIO := 0.58
const BOTTOM_SAFE_SPACE := 112.0
const MAX_NOTES := 72
const NOTE_HEAD_RADIUS := 9.0
const HIT_LINGER_SECONDS := 0.22

enum NoteState { RISING, HIT }
enum NoteKind { ANSWER, REASONING, TOOL_RUNNING, TOOL_SUCCESS, TOOL_FAILED }
enum ImpactStyle { PLASMA_RING, STRING_RIPPLE, CRYSTAL_SHARDS, CHORD_ARC, STARDUST }


class PianoNote extends RefCounted:
	var lane: int = 0
	var y: float = 0.0
	var speed: float = 0.0
	var length: float = 0.0
	var state: NoteState = NoteState.RISING
	var kind: NoteKind = NoteKind.ANSWER
	var label: String = ""
	var linger: float = 0.0
	var seed: float = 0.0
	var duration: int = 2
	var is_rest: bool = false
	var accidental: int = 0
	var dotted: bool = false
	var chord_steps := PackedInt32Array()
	var tie: bool = false
	var triplet: bool = false
	var dynamic_mark: String = ""
	var staccato: bool = false
	var fermata: bool = false
	var visual


var notes: Array[PianoNote] = []
var key_glows: Array[float] = []
var key_colors: Array[Color] = []
var lane_count: int = MIN_LANES
var elapsed: float = 0.0
var melody_step: int = 0
var note_layer: Node2D
var impact_layer: Control


func _ready() -> void:
	super._ready()
	ensure_render_layers()
	pass


func fade_in_seconds() -> float:
	return 0.38


func on_agent_start(_session_id: int) -> void:
	ensure_layout()
	for lane in range(lane_count):
		if lane % 3 == 0:
			spawn_note(lane, NoteKind.REASONING, 0.58, 0.0, "")
	queue_redraw()
	pass


func on_turn_start(_session_id: int) -> void:
	spawn_phrase(2, NoteKind.REASONING, 0.76)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var kind := NoteKind.REASONING if stream_kind == OpenAiClient.STREAM_KIND_REASONING else NoteKind.ANSWER
	var density := clampi(chunk.length() / 28 + 1, 1, 4)
	spawn_phrase(density, kind, 0.92 + float(density) * 0.08)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	ensure_layout()
	var lane := positive_mod(tool_call_id.hash(), lane_count)
	spawn_note(lane, NoteKind.TOOL_RUNNING, 0.7, 70.0, compact_tool_name(tool_name))
	spawn_note(positive_mod(lane + 3, lane_count), NoteKind.TOOL_RUNNING, 0.64, 52.0, "")
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	ensure_layout()
	var lane := positive_mod(tool_call_id.hash(), lane_count)
	var kind := NoteKind.TOOL_FAILED if result.is_error else NoteKind.TOOL_SUCCESS
	spawn_note(lane, kind, 1.34, 0.0, "")
	pass


func on_turn_end(_session_id: int) -> void:
	spawn_phrase(1, NoteKind.ANSWER, 0.7)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	ensure_layout()
	elapsed += delta
	for lane in range(key_glows.size()):
		key_glows[lane] = move_toward(key_glows[lane], 0.0, delta * 3.8)
	for index in range(notes.size() - 1, -1, -1):
		var note := notes[index]
		if note.state == NoteState.RISING:
			note.y -= note.speed * delta
			note.visual.set_note_position(Vector2(key_center_for_lane(note.lane), note.y))
			if note.y <= hit_y():
				note.y = hit_y()
				note.state = NoteState.HIT
				note.linger = HIT_LINGER_SECONDS
				note.visual.set_hit()
				key_glows[note.lane] = 1.0
				key_colors[note.lane] = note_color_for_note(note)
				spawn_energy_burst(Vector2(key_center_for_lane(note.lane), hit_y()), note_color_for_note(note), particle_style_for_note(note))
		else:
			note.linger -= delta
			if note.linger <= 0.0:
				note.visual.queue_free()
				notes.remove_at(index)
	queue_redraw()
	pass


func spawn_energy_burst(origin: Vector2, impact_color: Color, style: int) -> void:
	ensure_render_layers()
	var burst := PianoEnergyBurst.new()
	burst.setup(origin, impact_color, randf(), style)
	impact_layer.add_child(burst)
	pass


func impact_style_for_note(note: PianoNote) -> int:
	if note.chord_steps.size() > 1:
		return ImpactStyle.CHORD_ARC
	if note.kind == NoteKind.TOOL_SUCCESS:
		return ImpactStyle.STARDUST
	if note.length > 0.0 or note.duration == MusicNotationRenderer.Duration.WHOLE or note.duration == MusicNotationRenderer.Duration.HALF:
		return ImpactStyle.STRING_RIPPLE
	if note.staccato or note.duration == MusicNotationRenderer.Duration.SIXTEENTH or note.duration == MusicNotationRenderer.Duration.THIRTY_SECOND:
		return ImpactStyle.CRYSTAL_SHARDS
	return ImpactStyle.PLASMA_RING


func particle_style_for_note(note: PianoNote) -> int:
	var semantic_style := impact_style_for_note(note)
	if semantic_style != ImpactStyle.PLASMA_RING:
		return semantic_style
	# Ordinary notes deliberately rotate through several particle patterns instead of repeating one burst.
	return positive_mod(int(note.seed), 3) * 2


func spawn_phrase(count: int, kind: NoteKind, energy: float) -> void:
	ensure_layout()
	for offset in range(count):
		var lane := positive_mod(melody_step * 3 + offset * 2 + int(melody_step / 3), lane_count)
		var delay := float(offset) * 42.0
		spawn_note(lane, kind, energy, 0.0, "", delay)
		melody_step += 1
	queue_redraw()
	pass


func spawn_note(lane: int, kind: NoteKind, energy: float, length: float, label: String, spawn_offset: float = 0.0) -> void:
	ensure_layout()
	if notes.size() >= MAX_NOTES:
		return
	var note := PianoNote.new()
	note.lane = clampi(lane, 0, lane_count - 1)
	note.y = spawn_y() + spawn_offset
	note.speed = 260.0 + energy * 170.0
	note.length = length
	note.kind = kind
	note.label = label
	note.seed = float(melody_step * 19 + notes.size() * 7)
	configure_notation(note)
	ensure_render_layers()
	var visual := PianoNoteVisual.new()
	visual.setup(note_color_for_note(note), note.length, note.duration, note.is_rest, note.accidental, note.dotted, note.chord_steps, note.tie, note.triplet, note.dynamic_mark, note.staccato, note.fermata, note.label, positive_mod(note.lane, 7) - 3, note.seed)
	visual.set_note_position(Vector2(key_center_for_lane(note.lane), note.y))
	note_layer.add_child(visual)
	note.visual = visual
	notes.append(note)
	pass


func ensure_render_layers() -> void:
	if not is_instance_valid(note_layer):
		note_layer = Node2D.new()
		note_layer.name = "NoteLayer"
		note_layer.z_index = 2
		add_child(note_layer)
	if not is_instance_valid(impact_layer):
		impact_layer = Control.new()
		impact_layer.name = "ImpactLayer"
		impact_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		impact_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		impact_layer.z_index = 3
		add_child(impact_layer)
	pass


func configure_notation(note: PianoNote) -> void:
	var variation := positive_mod(melody_step + notes.size() * 3, 12)
	note.duration = variation % 6
	note.is_rest = note.kind == NoteKind.REASONING and variation == 5
	note.accidental = -1 if variation == 3 else (1 if variation == 8 else 0)
	note.dotted = variation == 4 or variation == 10
	note.tie = variation == 6
	note.triplet = variation == 9
	note.staccato = variation == 1 or variation == 7
	note.fermata = variation == 11
	if note.kind == NoteKind.TOOL_RUNNING:
		note.duration = MusicNotationRenderer.Duration.HALF
		note.chord_steps = PackedInt32Array([-4, 0, 3])
		note.dynamic_mark = "mf"
	elif note.kind == NoteKind.TOOL_SUCCESS:
		note.chord_steps = PackedInt32Array([0, 4])
		note.dynamic_mark = "f"
	elif note.kind == NoteKind.TOOL_FAILED:
		note.chord_steps = PackedInt32Array([0, -3])
		note.dynamic_mark = "p"
	pass


func ensure_layout() -> void:
	var target_lanes := clampi(floori(size.x / MIN_LANE_WIDTH), MIN_LANES, MAX_LANES)
	if target_lanes == lane_count and key_glows.size() == lane_count and key_colors.size() == lane_count:
		return
	lane_count = target_lanes
	key_glows.resize(lane_count)
	key_colors.resize(lane_count)
	for index in range(key_glows.size()):
		key_glows[index] = 0.0
		key_colors[index] = lane_color(index)
	pass


func keyboard_rect() -> Rect2:
	return Rect2(0.0, KEYBOARD_TOP, size.x, clampf(size.y * 0.18, MIN_KEYBOARD_HEIGHT, MAX_KEYBOARD_HEIGHT))


func hit_y() -> float:
	return keyboard_rect().end.y + HIT_GAP


func spawn_y() -> float:
	return maxf(hit_y() + 120.0, size.y - BOTTOM_SAFE_SPACE)


func lane_rect(lane: int) -> Rect2:
	var width := size.x / float(maxi(lane_count, 1))
	return Rect2(float(lane) * width, 0.0, width, size.y)


func white_key_index_for_lane(lane: int) -> int:
	return clampi(roundi(float(lane) / float(maxi(lane_count - 1, 1)) * float(WHITE_KEY_COUNT - 1)), 0, WHITE_KEY_COUNT - 1)


func key_center_for_lane(lane: int) -> float:
	var key_width := size.x / float(WHITE_KEY_COUNT)
	return (float(white_key_index_for_lane(lane)) + 0.5) * key_width


func glow_for_white_key(key_index: int) -> float:
	var glow := 0.0
	for lane in range(key_glows.size()):
		if white_key_index_for_lane(lane) == key_index:
			glow = maxf(glow, key_glows[lane])
	return glow


func color_for_white_key(key_index: int) -> Color:
	var strongest_glow := 0.0
	var color := ThemeColor.accent_theme_color()
	for lane in range(key_glows.size()):
		if white_key_index_for_lane(lane) == key_index and key_glows[lane] > strongest_glow:
			strongest_glow = key_glows[lane]
			color = key_colors[lane]
	return color


func _draw() -> void:
	if size.x < 180.0 or size.y < 160.0:
		return
	ensure_layout()
	draw_stage()
	draw_tracks()
	draw_keyboard()
	pass


func draw_stage() -> void:
	var keyboard := keyboard_rect()
	var stage_rect := Rect2(0.0, keyboard.position.y - 10.0, size.x, keyboard.size.y + HIT_GAP + 24.0)
	draw_rect(stage_rect, Color(ThemeColor.accent_theme_color(), 0.045), true)
	MusicNotationRenderer.draw_staff(self, Rect2(0.0, hit_y() - 34.0, size.x, 30.0), ThemeColor.accent_theme_color())
	MusicNotationRenderer.draw_treble_clef(self, Vector2(20.0, hit_y() - 20.0), ThemeColor.accent_theme_color())
	MusicNotationRenderer.draw_bass_clef(self, Vector2(55.0, hit_y() - 20.0), ThemeColor.accent_theme_color())
	MusicNotationRenderer.draw_pedal(self, Vector2(size.x - 100.0, hit_y() - 38.0), Vector2(size.x - 14.0, hit_y() - 38.0), ThemeColor.accent_theme_color())
	pass


func draw_tracks() -> void:
	var rail_bottom := spawn_y() + 16.0
	for lane in range(lane_count):
		var alpha := 0.035 + key_glows[lane] * 0.20
		var x := key_center_for_lane(lane)
		draw_line(Vector2(x, hit_y()), Vector2(x, rail_bottom), VisualColor.stroke(lane_color(lane), alpha), 1.0)
	var hit_color := ThemeColor.accent_theme_color()
	draw_line(Vector2(0.0, hit_y()), Vector2(size.x, hit_y()), Color(hit_color, 0.22), 4.0)
	draw_line(Vector2(0.0, hit_y()), Vector2(size.x, hit_y()), Color(hit_color, 0.82), 1.0)
	pass


func draw_keyboard() -> void:
	var keyboard := keyboard_rect()
	var key_width := keyboard.size.x / float(WHITE_KEY_COUNT)
	var accent := ThemeColor.accent_theme_color()
	var light_theme := not ThemeColor.is_dark_theme()
	# The keyboard is an overlay, not a panel: low alpha preserves readability of chat below it.
	var chassis_color := Color(Colors.LIGHT_CHROME_SURFACE, 0.16) if light_theme else Color(Colors.deep_surface, 0.20)
	var white_key_base := Color(Colors.LIGHT_SURFACE, 0.20) if light_theme else Color(0.93, 0.94, 0.95, 0.16)
	var key_outline := Color(Colors.DARK_MUTED_BORDER, 0.36) if light_theme else Color(Colors.primary_text, 0.26)
	var lower_shade_color := Color(Colors.LIGHT_DEEP_SURFACE, 0.14) if light_theme else Color(Colors.deep_surface, 0.10)
	var black_key_color := Color(Colors.DARK_DEEP_SURFACE, 0.46)
	draw_rect(keyboard.grow(5.0), chassis_color, true)
	draw_rect(Rect2(keyboard.position - Vector2(0.0, 4.0), Vector2(keyboard.size.x, 5.0)), Color(accent, 0.22), true)
	draw_rect(Rect2(keyboard.position + Vector2(0.0, keyboard.size.y), Vector2(keyboard.size.x, 5.0)), Color(Colors.DARK_DEEP_SURFACE, 0.20), true)
	for key_index in range(WHITE_KEY_COUNT):
		var glow := glow_for_white_key(key_index)
		var press_offset := glow * 3.0
		var key_rect := Rect2(float(key_index) * key_width + 0.5, keyboard.position.y + press_offset, key_width - 1.0, keyboard.size.y - press_offset)
		var fill := white_key_base.lerp(Color(accent.lightened(0.42), 0.38), glow * 0.68)
		draw_rect(key_rect, fill, true)
		var lower_shade := Rect2(key_rect.position + Vector2(1.0, key_rect.size.y * 0.68), Vector2(maxf(1.0, key_rect.size.x - 2.0), key_rect.size.y * 0.32 - 1.0))
		draw_rect(lower_shade, Color(lower_shade_color, maxf(0.08, lower_shade_color.a - glow * 0.10)), true)
		draw_line(key_rect.position + Vector2(1.0, 2.0), Vector2(key_rect.end.x - 1.0, key_rect.position.y + 2.0), Color.WHITE, 0.24)
		draw_rect(key_rect, key_outline, false, 1.0, true)
		if glow > 0.02:
			draw_rect(Rect2(key_rect.position.x + 2.0, key_rect.end.y - 7.0, maxf(1.0, key_rect.size.x - 4.0), 4.0), Color(color_for_white_key(key_index), glow * 0.66), true)
		if key_index % 7 == 0:
			var octave_label := "C%d" % (key_index / 7 + 1)
			draw_centered_text(Vector2(key_rect.get_center().x, key_rect.end.y - 15.0), octave_label, Fonts.medium(), Typography.label_small_size, Color(Colors.DARK_DEEP_SURFACE, 0.38))
	for key_index in range(WHITE_KEY_COUNT - 1):
		if not has_black_key_after(key_index):
			continue
		var black_width := key_width * BLACK_KEY_WIDTH_RATIO
		var left_glow := glow_for_white_key(key_index)
		var right_glow := glow_for_white_key(key_index + 1)
		var glow := maxf(left_glow, right_glow)
		var impact_color := color_for_white_key(key_index) if left_glow >= right_glow else color_for_white_key(key_index + 1)
		var press_offset := glow * 2.0
		var black_key := Rect2(float(key_index + 1) * key_width - black_width * 0.5, keyboard.position.y + press_offset, black_width, keyboard.size.y * BLACK_KEY_HEIGHT_RATIO - press_offset)
		draw_rect(Rect2(black_key.position + Vector2(1.0, 3.0), black_key.size), Color(Color.BLACK, 0.16), true)
		draw_rect(black_key, black_key_color.lerp(Color(impact_color.darkened(0.34), 0.60), glow * 0.82), true)
		draw_rect(Rect2(black_key.position + Vector2(1.0, 1.0), Vector2(maxf(1.0, black_key.size.x - 2.0), 3.0)), Color(impact_color, 0.12 + glow * 0.42), true)
		draw_line(Vector2(black_key.position.x + 1.0, black_key.end.y - 2.0), Vector2(black_key.end.x - 1.0, black_key.end.y - 2.0), Color(Color.BLACK, 0.34), 1.0)
		draw_rect(black_key, Color(Colors.DARK_BORDER, 0.42), false, 1.0, true)
	pass


static func has_black_key_after(white_key_index: int) -> bool:
	var scale_index := white_key_index % 7
	return scale_index == 0 or scale_index == 1 or scale_index == 3 or scale_index == 4 or scale_index == 5


func note_color_for_note(note: PianoNote) -> Color:
	match note.kind:
		NoteKind.REASONING:
			return lane_color(note.lane, 0.035, 0.84)
		NoteKind.TOOL_RUNNING:
			return lane_color(note.lane, -0.025, 1.12)
		NoteKind.TOOL_SUCCESS:
			return lane_color(note.lane, 0.032, 1.30)
		NoteKind.TOOL_FAILED:
			return lane_color(note.lane, -0.032, 0.62)
	return lane_color(note.lane, 0.0, 1.12)


func lane_color(lane: int, hue_nudge: float = 0.0, value_scale: float = 1.0) -> Color:
	var lane_ratio := float(lane) / float(maxi(lane_count - 1, 1))
	# Keep the whole piano inside the user's accent family: low notes are deeper and warmer,
	# high notes are brighter and cooler, but never travel far enough to become a rainbow.
	var accent := ThemeColor.accent_theme_color()
	var hue_offset := lerpf(-0.045, 0.055, lane_ratio) + hue_nudge
	var saturation_scale := lerpf(0.82, 1.14, lane_ratio)
	var base := VisualColor.appearance_color(accent, hue_offset, saturation_scale)
	base.v = clampf(base.v * lerpf(0.76, 1.16, lane_ratio) * value_scale, 0.0, 1.0)
	return base


static func positive_mod(value: int, modulus: int) -> int:
	return ((value % modulus) + modulus) % modulus


static func compact_tool_name(tool_name: String) -> String:
	var label := ToolVisualDisplay.upper_name(tool_name)
	return label.left(10)
