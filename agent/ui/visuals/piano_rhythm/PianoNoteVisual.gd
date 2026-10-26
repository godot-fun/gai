class_name PianoNoteVisual
extends Node2D

## One engraved glyph with a GPU particle trail. PianoRhythm owns timing; this node owns drawing.

const TRAIL_PARTICLE_LIFETIME: float = 0.24
const TRAIL_PARTICLE_COUNT: int = 18

var note_color: Color = Color.WHITE
var notation: MusicNotationRenderer.Note = MusicNotationRenderer.Note.new()
var rest: bool = false
var label: String = ""
var glyph_visible: bool = true
var trail_particles: GPUParticles2D

static var trail_texture: ImageTexture


func setup(p_color: Color, p_notation: MusicNotationRenderer.Note, p_rest: bool, p_label: String) -> void:
	note_color = p_color
	notation = p_notation
	rest = p_rest
	label = p_label
	build_trail_particles()
	queue_redraw()
	pass


func set_hit() -> void:
	glyph_visible = false
	if is_instance_valid(trail_particles):
		trail_particles.emitting = false
	queue_redraw()
	pass


func _draw() -> void:
	if not glyph_visible:
		return
	if rest:
		MusicNotationRenderer.draw_rest(self, Vector2.ZERO, note_color, notation.duration)
	else:
		MusicNotationRenderer.draw_note(self, Vector2.ZERO, note_color, notation)
	if not label.is_empty():
		var label_y := MusicNotationRenderer.glyph_bottom(notation) + float(MusicNotationRenderer.DYNAMIC_FONT_SIZE) + 4.0
		MusicNotationRenderer.draw_centered_text(self, Vector2(0.0, label_y), label, Fonts.semibold(), MusicNotationRenderer.DYNAMIC_FONT_SIZE, Color(note_color, 0.72))
	pass


func build_trail_particles() -> void:
	trail_particles = GPUParticles2D.new()
	trail_particles.name = "MotionTrail"
	trail_particles.z_index = -1
	trail_particles.amount = TRAIL_PARTICLE_COUNT
	trail_particles.lifetime = TRAIL_PARTICLE_LIFETIME
	trail_particles.randomness = 0.18
	trail_particles.local_coords = false
	trail_particles.visibility_rect = Rect2(-72.0, -40.0, 144.0, 204.0)
	trail_particles.texture = get_trail_texture()
	var particle_material := ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0.0, 1.0, 0.0)
	particle_material.spread = 12.0
	particle_material.initial_velocity_min = 8.0
	particle_material.initial_velocity_max = 30.0
	particle_material.gravity = Vector3(0.0, 34.0, 0.0)
	particle_material.damping_min = 3.0
	particle_material.damping_max = 9.0
	particle_material.scale_min = 0.62
	particle_material.scale_max = 1.25
	particle_material.color_ramp = make_trail_ramp()
	trail_particles.process_material = particle_material
	add_child(trail_particles)
	pass


func make_trail_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.36, 1.0])
	gradient.colors = PackedColorArray([
		Color(note_color, 0.56),
		Color(note_color, 0.24),
		Color(note_color, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	return color_ramp


static func get_trail_texture() -> ImageTexture:
	if trail_texture != null:
		return trail_texture
	const TEXTURE_SIZE: int = 16
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(TEXTURE_SIZE - 1, TEXTURE_SIZE - 1) * 0.5
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var distance := Vector2(x, y).distance_to(center) / (float(TEXTURE_SIZE) * 0.5)
			var alpha := pow(maxf(1.0 - distance, 0.0), 1.8)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	trail_texture = ImageTexture.create_from_image(image)
	return trail_texture
