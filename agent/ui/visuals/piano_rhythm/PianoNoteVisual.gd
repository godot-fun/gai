class_name PianoNoteVisual
extends Node2D

## One score glyph and its shader-ready visual state. PianoRhythm owns timing; this node
## owns its canvas drawing and per-note material parameters.

const NOTE_SHADER_PATH := "res://agent/ui/visuals/piano_rhythm/piano_note.gdshader"

var note_color: Color = Color.WHITE
var note_length: float = 0.0
var note_duration: int = MusicNotationRenderer.Duration.QUARTER
var rest: bool = false
var accidental: int = 0
var dotted: bool = false
var chord_steps := PackedInt32Array()
var tie: bool = false
var triplet: bool = false
var dynamic_mark: String = ""
var staccato: bool = false
var fermata: bool = false
var label: String = ""
var pitch_step: int = 0
var shader_clock: float = 0.0


func setup(p_color: Color, p_length: float, p_duration: int, p_rest: bool, p_accidental: int, p_dotted: bool, p_chord_steps: PackedInt32Array, p_tie: bool, p_triplet: bool, p_dynamic_mark: String, p_staccato: bool, p_fermata: bool, p_label: String, p_pitch_step: int, random_seed: float) -> void:
	note_color = p_color
	note_length = p_length
	note_duration = p_duration
	rest = p_rest
	accidental = p_accidental
	dotted = p_dotted
	chord_steps = p_chord_steps
	tie = p_tie
	triplet = p_triplet
	dynamic_mark = p_dynamic_mark
	staccato = p_staccato
	fermata = p_fermata
	label = p_label
	pitch_step = p_pitch_step
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load(NOTE_SHADER_PATH) as Shader
	shader_material.set_shader_parameter("note_tint", note_color)
	shader_material.set_shader_parameter("seed", random_seed)
	material = shader_material
	queue_redraw()
	pass


func set_note_position(next_position: Vector2) -> void:
	position = next_position
	pass


func set_hit() -> void:
	visible = false
	pass


func _process(delta: float) -> void:
	shader_clock += delta
	var shader_material := material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("shader_time", shader_clock)
	pass


func _draw() -> void:
	var shimmer := 0.86 + sin(shader_clock * 5.0) * 0.10
	draw_circle(Vector2.ZERO, 22.0, Color(note_color, 0.05 * shimmer))
	draw_circle(Vector2.ZERO, 14.0, Color(note_color, 0.10 * shimmer))
	if note_length > 0.0:
		draw_line(Vector2(0.0, 8.0), Vector2(0.0, note_length), Color(note_color, 0.26), 5.0)
		draw_line(Vector2(0.0, 8.0), Vector2(0.0, note_length), Color(note_color, 0.60), 1.0)
	if rest:
		MusicNotationRenderer.draw_rest(self, Vector2.ZERO, note_color, note_duration)
	else:
		MusicNotationRenderer.draw_note(self, Vector2.ZERO, note_color, note_duration, pitch_step, accidental, dotted, chord_steps, tie, triplet, dynamic_mark, staccato, fermata)
	if not label.is_empty():
		draw_centered_text(Vector2(0.0, 46.0), label, Fonts.semibold(), Typography.label_small_size, Color(note_color, 0.82))
	pass


func draw_centered_text(position: Vector2, text: String, font: Font, font_size: int, text_color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, position - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	pass
