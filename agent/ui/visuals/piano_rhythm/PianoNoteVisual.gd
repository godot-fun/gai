class_name PianoNoteVisual
extends Node2D

## One engraved glyph and its shader-ready visual state. PianoRhythm owns timing; this node
## owns its canvas drawing and per-note material parameters.

const NOTE_SHADER: Shader = preload("res://agent/ui/visuals/piano_rhythm/piano_note.gdshader")

var note_color: Color = Color.WHITE
var note_length: float = 0.0
var notation: MusicNotationRenderer.Note = MusicNotationRenderer.Note.new()
var rest: bool = false
var label: String = ""
var shader_clock: float = 0.0


func setup(p_color: Color, p_length: float, p_notation: MusicNotationRenderer.Note, p_rest: bool, p_label: String, random_seed: float) -> void:
	note_color = p_color
	note_length = p_length
	notation = p_notation
	rest = p_rest
	label = p_label
	var shader_material := ShaderMaterial.new()
	shader_material.shader = NOTE_SHADER
	shader_material.set_shader_parameter("note_tint", note_color)
	shader_material.set_shader_parameter("seed", random_seed)
	material = shader_material
	queue_redraw()
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
	# The shader animates the shimmer; the canvas halo is a static backdrop under the glyph.
	draw_circle(Vector2.ZERO, 22.0, Color(note_color, 0.04))
	draw_circle(Vector2.ZERO, 14.0, Color(note_color, 0.09))
	if note_length > 0.0:
		draw_energy_trail()
	if rest:
		MusicNotationRenderer.draw_rest(self, Vector2.ZERO, note_color, notation.duration)
	else:
		MusicNotationRenderer.draw_note(self, Vector2.ZERO, note_color, notation)
	if not label.is_empty():
		var label_y := MusicNotationRenderer.glyph_bottom(notation) + float(MusicNotationRenderer.DYNAMIC_FONT_SIZE) + 4.0
		MusicNotationRenderer.draw_centered_text(self, Vector2(0.0, label_y), label, Fonts.semibold(), MusicNotationRenderer.DYNAMIC_FONT_SIZE, Color(note_color, 0.72))
	pass


## The falling energy wake behind the glyph. It starts below the engraved silhouette
## instead of crossing it, so the note itself stays readable.
func draw_energy_trail() -> void:
	var trail_top := MusicNotationRenderer.glyph_bottom(notation) + 4.0
	var trail_bottom := maxf(note_length, trail_top + 14.0)
	var trail := PackedVector2Array([Vector2(0.0, trail_top), Vector2(0.0, trail_bottom)])
	MusicNotationRenderer.draw_stroke(self, trail, 11.0, 3.0, Color(note_color, 0.09))
	MusicNotationRenderer.draw_stroke(self, trail, 4.5, 1.0, Color(note_color, 0.24))
	pass
