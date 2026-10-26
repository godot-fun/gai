class_name PianoEnergyBurst
extends Node2D

## A short-lived, physically moving energy burst. Unlike the ion shader's radial mask,
## these particles carry velocity, drag, gravity, and independent lifetimes.

const ENERGY_SHADER_PATH := "res://agent/ui/visuals/piano_rhythm/piano_energy_burst.gdshader"


class EnergyParticle extends RefCounted:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var life: float = 0.0
	var max_life: float = 0.0
	var size: float = 0.0
	var drag: float = 0.0
	var gravity: float = 0.0
	var color: Color = Color.WHITE
	var trail_scale: float = 1.0


var particles: Array[EnergyParticle] = []
var energy_color: Color = Color.WHITE
var age: float = 0.0
var duration: float = 0.0


func setup(origin: Vector2, impact_color: Color, random_seed: float, style: int) -> void:
	position = origin
	energy_color = impact_color
	duration = randf_range(0.46, 0.74)
	var particle_count := randi_range(18, 32)
	match style:
		1:
			particle_count = randi_range(10, 17)
		2:
			particle_count = randi_range(30, 44)
		3:
			particle_count = randi_range(22, 32)
		4:
			particle_count = randi_range(26, 38)
	for index in range(particle_count):
		var particle := EnergyParticle.new()
		configure_particle(particle, index, style)
		particle.life = particle.max_life
		particles.append(particle)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load(ENERGY_SHADER_PATH) as Shader
	shader_material.set_shader_parameter("energy_color", energy_color)
	shader_material.set_shader_parameter("seed", random_seed)
	material = shader_material
	pass


func configure_particle(particle: EnergyParticle, index: int, style: int) -> void:
	var angle := randf_range(PI * 0.08, PI * 0.92)
	var speed := randf_range(92.0, 245.0)
	particle.max_life = randf_range(0.26, duration)
	particle.size = randf_range(1.3, 3.4)
	particle.drag = randf_range(1.5, 3.0)
	particle.gravity = randf_range(72.0, 150.0)
	particle.trail_scale = randf_range(0.72, 1.18)
	match style:
		1: # Narrow, falling strings for held notes.
			angle = PI * 0.5 + randf_range(-0.22, 0.22)
			speed = randf_range(78.0, 165.0)
			particle.max_life = randf_range(0.38, duration)
			particle.size = randf_range(1.0, 2.1)
			particle.trail_scale = randf_range(1.5, 2.4)
		2: # Fast wide shards for short notes.
			angle = randf_range(PI * 0.02, PI * 0.98)
			speed = randf_range(165.0, 340.0)
			particle.size = randf_range(1.2, 4.2)
			particle.trail_scale = randf_range(1.2, 2.0)
		3: # Two opposing fans for chords.
			angle = randf_range(0.12, 0.48) if index % 2 == 0 else randf_range(PI - 0.48, PI - 0.12)
			speed = randf_range(145.0, 260.0)
			particle.max_life = randf_range(0.32, duration)
			particle.trail_scale = randf_range(1.0, 1.7)
		4: # Slow, low-gravity star dust for successful events.
			angle = randf_range(0.0, PI)
			speed = randf_range(42.0, 138.0)
			particle.max_life = randf_range(0.42, duration)
			particle.size = randf_range(1.0, 2.7)
			particle.drag = randf_range(2.8, 4.4)
			particle.gravity = randf_range(18.0, 58.0)
			particle.trail_scale = randf_range(0.35, 0.82)
	particle.velocity = Vector2.from_angle(angle) * speed + Vector2(0.0, randf_range(12.0, 54.0))
	particle.color = energy_color.lerp(Color.WHITE, randf_range(0.05, 0.34))
	pass


func _process(delta: float) -> void:
	age += delta
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index]
		particle.life -= delta
		if particle.life <= 0.0:
			particles.remove_at(index)
			continue
		particle.velocity = particle.velocity.lerp(Vector2(0.0, particle.gravity), delta * particle.drag)
		particle.position += particle.velocity * delta
	queue_redraw()
	if particles.is_empty() or age >= duration:
		queue_free()
	pass


func _draw() -> void:
	for particle: EnergyParticle in particles:
		var alpha := particle.life / particle.max_life * 0.62
		var tail := particle.velocity.normalized() * minf(38.0, particle.velocity.length() * 0.12) * particle.trail_scale * (0.38 + alpha * 0.62)
		draw_line(particle.position - tail, particle.position, VisualColor.stroke(particle.color, alpha * 0.20), particle.size * 3.0)
		draw_line(particle.position - tail * 0.68, particle.position, VisualColor.stroke(particle.color, alpha * 0.86), particle.size * 0.72)
		draw_circle(particle.position, particle.size * 2.1, VisualColor.stroke(particle.color, alpha * 0.13))
		draw_circle(particle.position, particle.size, VisualColor.stroke(particle.color, alpha))
	pass
