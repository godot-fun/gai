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


func setup(origin: Vector2, impact_color: Color, random_seed: float, impact_weight: float) -> void:
	position = origin
	energy_color = impact_color
	var weight := clampf(impact_weight, 0.0, 1.0)
	duration = randf_range(lerpf(0.36, 0.52, weight), lerpf(0.58, 0.86, weight))
	var count_min := roundi(lerpf(10.0, 22.0, weight))
	var count_max := roundi(lerpf(18.0, 48.0, weight))
	var particle_count := randi_range(count_min, count_max)
	for index in range(particle_count):
		var particle := EnergyParticle.new()
		configure_particle(particle, weight)
		particle.life = particle.max_life
		particles.append(particle)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load(ENERGY_SHADER_PATH) as Shader
	shader_material.set_shader_parameter("energy_color", energy_color)
	shader_material.set_shader_parameter("seed", random_seed)
	material = shader_material
	pass


func configure_particle(particle: EnergyParticle, weight: float) -> void:
	var angle := randf_range(PI * 0.08, PI * 0.92)
	var speed_min := lerpf(72.0, 145.0, weight)
	var speed_max := lerpf(165.0, 360.0, weight)
	var speed := randf_range(speed_min, speed_max)
	particle.max_life = randf_range(lerpf(0.22, 0.30, weight), duration)
	particle.size = randf_range(lerpf(0.9, 1.5, weight), lerpf(2.0, 5.4, weight))
	particle.drag = randf_range(lerpf(2.2, 1.6, weight), lerpf(3.4, 2.4, weight))
	particle.gravity = randf_range(lerpf(88.0, 62.0, weight), lerpf(158.0, 118.0, weight))
	particle.trail_scale = randf_range(lerpf(0.62, 0.92, weight), lerpf(1.05, 2.2, weight))
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
