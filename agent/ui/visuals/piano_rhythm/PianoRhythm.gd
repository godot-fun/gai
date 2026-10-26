class_name PianoRhythm
extends VisualEffect

## An inverted piano-roll overlay: notes rise from the reading area and resolve into
## a compact keyboard at the top, leaving the lower chat surface unobstructed.
## Each note binds one transcript sentence at spawn; sentence weight drives speed,
## impact particles, and floating text together.

const MIN_KEYBOARD_HEIGHT := 132.0
const MAX_KEYBOARD_HEIGHT := 190.0
# Impacts originate exactly on the key edge so the note and its energy read as one gesture.
const HIT_GAP := 0.0
const WHITE_KEY_COUNT := 52
const BLACK_KEY_HEIGHT_RATIO := 0.62
const BLACK_KEY_WIDTH_RATIO := 0.58
const BOTTOM_SAFE_SPACE := 112.0
const MAX_NOTES := 28
# Keeps stopped GPU afterimages alive long enough to fade after the key impact.
const HIT_LINGER_SECONDS := 0.72
const MAX_FLOATING_LINES := 12
const FLOAT_LINE_SPEED := 92.0
const FLOAT_LINE_LIFE := 4.4
const FLOAT_LINE_MAX_WIDTH := 420.0
const FLOAT_FONT_SIZE_MIN := 12
const FLOAT_FONT_SIZE_MAX := 36
const SENTENCE_WEIGHT_CHARS := 140.0
const NOTE_RISE_SECONDS_MAX := 1.9
const NOTE_RISE_SECONDS_MIN := 0.9

enum NoteState { RISING, HIT }
enum NoteKind { ANSWER, REASONING, TOOL_RUNNING, TOOL_SUCCESS, TOOL_FAILED }


class PianoNote extends RefCounted:
	var lane: int = 0
	var y: float = 0.0
	var speed: float = 0.0
	var state: NoteState = NoteState.RISING
	var kind: NoteKind = NoteKind.ANSWER
	var label: String = ""
	var linger: float = 0.0
	var notation: MusicNotationRenderer.Note = MusicNotationRenderer.Note.new()
	var is_rest: bool = false
	var sentence_text: String = ""
	var entry_kind: String = ""
	var weight: float = 0.35
	var visual: PianoNoteVisual


class FloatingLine extends RefCounted:
	var text: String = ""
	var position: Vector2 = Vector2.ZERO
	var color: Color = Color.WHITE
	var font_size: int = Typography.label_small_size
	var age: float = 0.0
	var life: float = FLOAT_LINE_LIFE


var notes: Array[PianoNote] = []
var floating_lines: Array[FloatingLine] = []
var key_glows: Array[float] = []
var key_colors: Array[Color] = []
var melody_step: int = 0
var note_layer: Node2D
var impact_layer: Control


func _ready() -> void:
	super._ready()
	ensure_render_layers()
	pass


func fade_in_seconds() -> float:
	return 0.38


func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	request_note(NoteKind.TOOL_RUNNING, ToolVisualDisplay.upper_name(tool_name).left(10))
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	var kind := NoteKind.TOOL_FAILED if result.is_error else NoteKind.TOOL_SUCCESS
	request_note(kind)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	ensure_layout()
	if notes.size() < MAX_NOTES:
		var sentence := ChatEntryCursor.take_next_sentence()
		if not sentence.is_empty() and sentence.entry != null:
			var kind := NoteKind.REASONING if sentence.entry.kind == ChatEntry.KIND_THINKING else NoteKind.ANSWER
			request_note(kind, "", sentence.text.strip_edges(), sentence.entry.kind)
	var hit := hit_y()
	var keyboard_animating := false
	for lane in range(key_glows.size()):
		if key_glows[lane] > 0.0:
			key_glows[lane] = move_toward(key_glows[lane], 0.0, delta / HIT_LINGER_SECONDS)
			keyboard_animating = true
	for index in range(notes.size() - 1, -1, -1):
		var note := notes[index]
		if note.state == NoteState.RISING:
			note.y -= note.speed * delta
			var lane_x := key_center_for_lane(note.lane)
			note.visual.position = Vector2(lane_x, note.y)
			if note.y <= hit:
				note.y = hit
				note.state = NoteState.HIT
				note.linger = HIT_LINGER_SECONDS
				note.visual.set_hit()
				var impact_color := note_color_for_note(note)
				keyboard_animating = true
				key_glows[note.lane] = 1.0
				key_colors[note.lane] = impact_color
				var burst := PianoEnergyBurst.new()
				burst.setup(Vector2(lane_x, hit), impact_color, randf(), note.weight)
				impact_layer.add_child(burst)
				spawn_floating_line_on_impact(note)
		else:
			note.linger -= delta
			if note.linger <= 0.0:
				note.visual.queue_free()
				notes.remove_at(index)
	for index in range(floating_lines.size() - 1, -1, -1):
		var line := floating_lines[index]
		line.age += delta
		line.position.y -= FLOAT_LINE_SPEED * delta
		if line.age >= line.life:
			floating_lines.remove_at(index)
	# Notes animate inside their own layers, so the keyboard and text only need a repaint when
	# a key is pressed or a floating line is alive.
	if keyboard_animating or not floating_lines.is_empty():
		queue_redraw()
	pass

func spawn_floating_line_on_impact(note: PianoNote) -> void:
	if note.is_rest:
		return
	var text := note.sentence_text.strip_edges()
	if text.is_empty():
		return
	var impact_color := note_color_for_note(note)
	var band := floating_font_band_for_note(note)
	var font_size := band.x if band.x >= band.y else randi_range(band.x, band.y)
	var origin := Vector2(key_center_for_lane(note.lane), hit_y())
	spawn_floating_line(trim_line_text(text, font_size), origin, impact_color, font_size)
	pass


func spawn_floating_line(text: String, origin: Vector2, color: Color, font_size: int = Typography.label_small_size) -> void:
	if floating_lines.size() >= MAX_FLOATING_LINES:
		floating_lines.pop_front()
	var line := FloatingLine.new()
	line.text = text
	line.position = origin
	line.color = color
	line.font_size = font_size
	# Fade out completely before the line reaches the top edge, otherwise it is clipped mid-fade.
	line.life = clampf((origin.y - 12.0) / FLOAT_LINE_SPEED, 0.6, FLOAT_LINE_LIFE)
	floating_lines.append(line)
	queue_redraw()
	pass


## Weak impacts draw from a narrow low band; strong impacts draw from a wider high band.
func floating_font_band_for_note(note: PianoNote) -> Vector2i:
	var strength := note.weight
	var band_min := lerpf(float(FLOAT_FONT_SIZE_MIN), float(FLOAT_FONT_SIZE_MAX) * 0.58, strength)
	var band_max := lerpf(float(FLOAT_FONT_SIZE_MIN) + 3.0, float(FLOAT_FONT_SIZE_MAX), strength)
	band_max = maxf(band_max, band_min + 2.0)
	band_min = clampf(band_min, float(FLOAT_FONT_SIZE_MIN), float(FLOAT_FONT_SIZE_MAX))
	band_max = clampf(band_max, band_min, float(FLOAT_FONT_SIZE_MAX))
	return Vector2i(ceili(band_min), floori(band_max))


func trim_line_text(text: String, font_size: int = Typography.label_small_size) -> String:
	var font := Fonts.medium()
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= FLOAT_LINE_MAX_WIDTH:
		return text
	var trimmed := text
	while trimmed.length() > 3 and font.get_string_size(trimmed + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > FLOAT_LINE_MAX_WIDTH:
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	return trimmed + "…"


func weight_for_sentence(text: String, kind: NoteKind) -> float:
	var stripped := text.strip_edges()
	if not stripped.is_empty():
		return clampf(float(stripped.length()) / SENTENCE_WEIGHT_CHARS, 0.06, 1.0)
	match kind:
		NoteKind.TOOL_SUCCESS:
			return 0.86
		NoteKind.TOOL_FAILED:
			return 0.34
		NoteKind.TOOL_RUNNING:
			return 0.52
		NoteKind.REASONING:
			return 0.38
	return 0.46


## Heavier sentences cross the reading area faster, but the distance never changes the rhythm:
## the rise keeps a fixed duration band so a tall window does not delay every impact.
func rise_seconds_for_weight(weight: float) -> float:
	return lerpf(NOTE_RISE_SECONDS_MAX, NOTE_RISE_SECONDS_MIN, clampf(weight, 0.0, 1.0))


## Adds an event or transcript note. [constant MAX_NOTES] bounds the visible score.
func request_note(kind: NoteKind, label: String = "", text: String = "", entry_kind: String = "") -> void:
	if notes.size() >= MAX_NOTES:
		return
	# Steps three keys at a time so consecutive notes never repeat a lane.
	spawn_note(melody_step * 3 % WHITE_KEY_COUNT, kind, label, text, entry_kind)
	melody_step += 1
	pass


func spawn_note(lane: int, kind: NoteKind, label: String = "", text: String = "", entry_kind: String = "") -> void:
	ensure_layout()
	if notes.size() >= MAX_NOTES:
		return
	var bottom := maxf(hit_y() + 120.0, size.y - BOTTOM_SAFE_SPACE)
	var note := PianoNote.new()
	note.lane = clampi(lane, 0, WHITE_KEY_COUNT - 1)
	note.y = bottom
	note.kind = kind
	note.label = label
	note.sentence_text = text
	note.entry_kind = entry_kind
	note.weight = weight_for_sentence(text, kind)
	note.is_rest = text.is_empty() and kind == NoteKind.REASONING
	note.speed = (bottom - hit_y()) / rise_seconds_for_weight(note.weight)
	note.notation = build_notation(note)
	ensure_render_layers()
	var visual := PianoNoteVisual.new()
	visual.setup(note_color_for_note(note), note.notation, note.is_rest, note.label)
	visual.position = Vector2(key_center_for_lane(note.lane), note.y)
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


## Maps one agent event onto printed notation. Weight decides note value and accidental so
## the melody reads as a score instead of random glyphs.
func build_notation(note: PianoNote) -> MusicNotationRenderer.Note:
	var notation := MusicNotationRenderer.Note.new()
	notation.step = note.lane % 7 - 3
	if note.is_rest:
		notation.duration = MusicNotationRenderer.Duration.QUARTER
		return notation
	if note.kind == NoteKind.TOOL_RUNNING:
		notation.duration = MusicNotationRenderer.Duration.HALF
		notation.chord_steps = PackedInt32Array([-4, 0, 3])
		notation.dynamic_mark = "mf"
		return notation
	if note.kind == NoteKind.TOOL_SUCCESS:
		notation.chord_steps = PackedInt32Array([0, 4])
		notation.dynamic_mark = "f"
	elif note.kind == NoteKind.TOOL_FAILED:
		notation.chord_steps = PackedInt32Array([0, -3])
		notation.dynamic_mark = "p"
	if note.weight >= 0.72:
		notation.duration = MusicNotationRenderer.Duration.HALF
		notation.dotted = note.weight >= 0.88
	elif note.weight >= 0.42:
		notation.duration = MusicNotationRenderer.Duration.QUARTER
	else:
		notation.duration = MusicNotationRenderer.Duration.SIXTEENTH
		notation.staccato = true
	notation.accidental = -1 if note.weight < 0.22 else (1 if note.weight > 0.78 else 0)
	return notation


func ensure_layout() -> void:
	if key_glows.size() == WHITE_KEY_COUNT:
		return
	key_glows.resize(WHITE_KEY_COUNT)
	key_glows.fill(0.0)
	# Each hit writes its own impact color; the initial value only has to be a valid color.
	key_colors.resize(WHITE_KEY_COUNT)
	key_colors.fill(ThemeColor.accent_theme_color())
	pass


## The keyboard hangs below the app toolbar, so its keys never cover the toolbar buttons.
func keyboard_rect() -> Rect2:
	return Rect2(0.0, float(AgentLayout.TOOLBAR_HEIGHT), size.x, clampf(size.y * 0.18, MIN_KEYBOARD_HEIGHT, MAX_KEYBOARD_HEIGHT))


func hit_y() -> float:
	return keyboard_rect().end.y + HIT_GAP


func key_center_for_lane(lane: int) -> float:
	var key_width := size.x / float(WHITE_KEY_COUNT)
	var key_index := clampi(lane, 0, WHITE_KEY_COUNT - 1)
	return (float(key_index) + 0.5) * key_width


func color_for_white_key(key_index: int) -> Color:
	if key_glows[key_index] > 0.02:
		return key_colors[key_index]
	return ThemeColor.accent_theme_color()


func _draw() -> void:
	if size.x < 180.0 or size.y < 160.0:
		return
	ensure_layout()
	draw_keyboard()
	draw_floating_lines()
	pass


func draw_floating_lines() -> void:
	var font := Fonts.medium()
	for line: FloatingLine in floating_lines:
		var progress := clampf(line.age / line.life, 0.0, 1.0)
		var alpha := sin(progress * PI) * 0.92
		draw_centered_text(line.position, line.text, font, line.font_size, Color(line.color, alpha))
	pass


func draw_keyboard() -> void:
	var keyboard := keyboard_rect()
	var key_width := keyboard.size.x / float(WHITE_KEY_COUNT)
	var accent := ThemeColor.accent_theme_color()
	var light_theme := not ThemeColor.is_dark_theme()
	# The keyboard is an overlay, not a panel: low alpha preserves readability of chat below it.
	# Dark surfaces need a higher alpha floor, otherwise translucent keys sink into the background.
	var chassis_color := Color(Colors.LIGHT_CHROME_SURFACE, 0.16) if light_theme else Color(Colors.deep_surface, 0.42)
	var white_key_base := Color(Colors.LIGHT_SURFACE, 0.20) if light_theme else Color(Colors.LIGHT_SURFACE, 0.30)
	var key_outline := Color(Colors.DARK_MUTED_BORDER, 0.36) if light_theme else Color(Colors.primary_text, 0.40)
	var lower_shade_color := Color(Colors.LIGHT_DEEP_SURFACE, 0.14) if light_theme else Color(Colors.deep_surface, 0.30)
	var black_key_color := Color(Colors.DARK_DEEP_SURFACE, 0.46) if light_theme else Color(Colors.deep_surface, 0.85)
	var octave_label_color := Color(Colors.DARK_DEEP_SURFACE, 0.38) if light_theme else Color(Colors.primary_text, 0.42)
	# A pressed key has to read brighter than its neighbours in both themes, so the dark palette
	# lifts the accent instead of tinting the key with a darker color.
	var press_fill := Color(accent.lightened(0.42), 0.38) if light_theme else Color(accent.lightened(0.70), 0.90)
	# Chassis lip: 5px on the sides and below, so it never tints the toolbar above the keys.
	draw_rect(Rect2(keyboard.position - Vector2(5.0, 0.0), keyboard.size + Vector2(10.0, 5.0)), chassis_color, true)
	var label_font := Fonts.medium()
	for key_index in range(WHITE_KEY_COUNT):
		var glow := key_glows[key_index]
		var press_offset := glow * 3.0
		var key_rect := Rect2(float(key_index) * key_width + 0.5, keyboard.position.y + press_offset, key_width - 1.0, keyboard.size.y - press_offset)
		var fill := white_key_base.lerp(press_fill, glow * 0.78)
		draw_rect(key_rect, fill, true)
		var lower_shade := Rect2(key_rect.position + Vector2(1.0, key_rect.size.y * 0.68), Vector2(maxf(1.0, key_rect.size.x - 2.0), key_rect.size.y * 0.32 - 1.0))
		draw_rect(lower_shade, Color(lower_shade_color, maxf(0.08, lower_shade_color.a - glow * 0.30)), true)
		draw_line(key_rect.position + Vector2(1.0, 2.0), Vector2(key_rect.end.x - 1.0, key_rect.position.y + 2.0), Color.WHITE, 0.24)
		if glow > 0.02:
			draw_rect(Rect2(key_rect.position.x + 2.0, key_rect.end.y - 7.0, maxf(1.0, key_rect.size.x - 4.0), 4.0), Color(color_for_white_key(key_index), glow * 0.66), true)
		if key_index % 7 == 0:
			var octave_label := "C%d" % (key_index / 7 + 1)
			draw_centered_text(Vector2(key_rect.get_center().x, key_rect.end.y - 15.0), octave_label, label_font, Typography.label_small_size, octave_label_color)
	# White key dividers start below the black keys, so a divider never splits a black key in two.
	var black_bottom := keyboard.position.y + keyboard.size.y * BLACK_KEY_HEIGHT_RATIO
	for key_index in range(WHITE_KEY_COUNT + 1):
		var covered := key_index > 0 and key_index < WHITE_KEY_COUNT and (key_index - 1) % 7 in [0, 1, 3, 4, 5]
		var divider_x := minf(float(key_index) * key_width, keyboard.end.x - 0.5)
		var divider_top := black_bottom if covered else keyboard.position.y
		draw_line(Vector2(divider_x, divider_top), Vector2(divider_x, keyboard.end.y), key_outline, 1.0)
	# Close the frame: the dividers no longer carry a per-key bottom border.
	draw_line(Vector2(0.0, keyboard.end.y), Vector2(keyboard.end.x, keyboard.end.y), key_outline, 1.0)
	for key_index in range(WHITE_KEY_COUNT - 1):
		# Black keys sit after C, D, F, G, and A inside each octave.
		if not (key_index % 7 in [0, 1, 3, 4, 5]):
			continue
		var black_width := key_width * BLACK_KEY_WIDTH_RATIO
		var left_glow := key_glows[key_index]
		var right_glow := key_glows[key_index + 1]
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


func note_color_for_note(note: PianoNote) -> Color:
	match note.kind:
		NoteKind.TOOL_SUCCESS:
			return VisualColor.appearance_color(Colors.success)
		NoteKind.TOOL_FAILED:
			return VisualColor.appearance_color(Colors.error)
	if not note.entry_kind.is_empty():
		return ChatEntryCursor.color_for_entry_kind(note.entry_kind)
	if note.kind == NoteKind.REASONING:
		return lane_color(note.lane, 0.035, 0.84)
	if note.kind == NoteKind.TOOL_RUNNING:
		return VisualColor.appearance_color(Colors.success)
	return lane_color(note.lane, 0.0, 1.12)

func lane_color(lane: int, hue_nudge: float = 0.0, value_scale: float = 1.0) -> Color:
	var lane_ratio := float(lane) / float(WHITE_KEY_COUNT - 1)
	# Keep the whole piano inside the user's accent family: low notes are deeper and warmer,
	# high notes are brighter and cooler, but never travel far enough to become a rainbow.
	var accent := ThemeColor.accent_theme_color()
	var hue_offset := lerpf(-0.045, 0.055, lane_ratio) + hue_nudge
	var saturation_scale := lerpf(0.82, 1.14, lane_ratio)
	var base := VisualColor.appearance_color(accent, hue_offset, saturation_scale)
	base.v = clampf(base.v * lerpf(0.76, 1.16, lane_ratio) * value_scale, 0.0, 1.0)
	return base
