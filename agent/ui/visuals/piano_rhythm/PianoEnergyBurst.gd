class_name PianoEnergyBurst
extends Node2D

## A short-lived refracted chord: a white-hot key strike grows harmonic ribbons,
## then breaks into independently moving stardust.

const ENERGY_SHADER: Shader = preload("res://agent/ui/visuals/piano_rhythm/piano_energy_burst.gdshader")


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


class HarmonicRibbon extends RefCounted:
	var angle: float = 0.0
	var phase: float = 0.0
	var curvature: float = 0.0
	var length: float = 0.0
	var width: float = 0.0
	var frequency: float = 0.0
	var life: float = 0.0
	var max_life: float = 0.0


var particles: Array[EnergyParticle] = []
var ribbons: Array[HarmonicRibbon] = []
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
	var ribbon_count := randi_range(2, 3 + roundi(weight * 3.0))
	for index in range(ribbon_count):
		var ribbon := HarmonicRibbon.new()
		configure_ribbon(ribbon, weight)
		ribbon.life = ribbon.max_life
		ribbons.append(ribbon)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = ENERGY_SHADER
	shader_material.set_shader_parameter("energy_color", energy_color)
	shader_material.set_shader_parameter("seed", random_seed)
	shader_material.set_shader_parameter("impact_strength", weight)
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


func configure_ribbon(ribbon: HarmonicRibbon, weight: float) -> void:
	# The keyboard lives above the reading area, so the chord unfurls down into open space.
	ribbon.angle = randf_range(PI * 0.16, PI * 0.84)
	ribbon.phase = randf_range(0.0, TAU)
	ribbon.curvature = randf_range(-1.0, 1.0) * lerpf(16.0, 54.0, weight)
	ribbon.length = randf_range(lerpf(52.0, 88.0, weight), lerpf(130.0, 310.0, weight))
	ribbon.width = randf_range(lerpf(0.7, 1.15, weight), lerpf(1.4, 2.8, weight))
	ribbon.frequency = randf_range(1.15, 2.65)
	ribbon.max_life = randf_range(lerpf(0.28, 0.38, weight), lerpf(0.46, 0.68, weight))
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
	for index in range(ribbons.size() - 1, -1, -1):
		var ribbon := ribbons[index]
		ribbon.life -= delta
		if ribbon.life <= 0.0:
			ribbons.remove_at(index)
	queue_redraw()
	if (particles.is_empty() and ribbons.is_empty()) or age >= duration:
		queue_free()
	pass


func _draw() -> void:
	draw_strike_core()
	for ribbon: HarmonicRibbon in ribbons:
		draw_harmonic_ribbon(ribbon)
	for particle: EnergyParticle in particles:
		var alpha := particle.life / particle.max_life * 0.62
		var tail := particle.velocity.normalized() * minf(38.0, particle.velocity.length() * 0.12) * particle.trail_scale * (0.38 + alpha * 0.62)
		draw_line(particle.position - tail, particle.position, VisualColor.stroke(particle.color, alpha * 0.20), particle.size * 3.0)
		draw_line(particle.position - tail * 0.68, particle.position, VisualColor.stroke(particle.color, alpha * 0.86), particle.size * 0.72)
		draw_circle(particle.position, particle.size * 2.1, VisualColor.stroke(particle.color, alpha * 0.13))
		draw_circle(particle.position, particle.size, VisualColor.stroke(particle.color, alpha))
	pass


func draw_strike_core() -> void:
	var flash := clampf(1.0 - age / 0.16, 0.0, 1.0)
	var bloom_radius := lerpf(4.0, 24.0 + duration * 24.0, 1.0 - flash)
	draw_circle(Vector2.ZERO, bloom_radius * 1.8, VisualColor.stroke(energy_color, flash * 0.055))
	draw_circle(Vector2.ZERO, bloom_radius * 0.72, VisualColor.stroke(energy_color.lerp(Color.WHITE, 0.72), flash * 0.22))
	draw_circle(Vector2.ZERO, 2.4 + flash * 5.0, VisualColor.stroke(Color.WHITE, flash * 0.92))
	var ring_progress := clampf(age / 0.42, 0.0, 1.0)
	var ring_alpha := pow(1.0 - ring_progress, 1.7) * 0.58
	if ring_alpha > 0.01:
		var radius := lerpf(6.0, 38.0 + duration * 76.0, ring_progress)
		draw_arc(Vector2.ZERO, radius, -2.54, -0.28, 22, VisualColor.stroke(Color.WHITE, ring_alpha), 1.2, true)
		draw_arc(Vector2.ZERO, radius, 0.38, 2.18, 18, VisualColor.stroke(energy_color, ring_alpha * 0.76), 1.7, true)
	pass


func draw_harmonic_ribbon(ribbon: HarmonicRibbon) -> void:
	var elapsed := 1.0 - ribbon.life / ribbon.max_life
	var growth := sin(minf(elapsed * 2.45, 1.0) * PI * 0.5)
	var fade := minf(elapsed * 10.0, 1.0) * pow(1.0 - elapsed, 1.35)
	var axis := Vector2.from_angle(ribbon.angle)
	var normal := axis.orthogonal()
	var points := PackedVector2Array()
	var segments := 13
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var arc := sin(t * PI) * ribbon.curvature
		var oscillation := sin(t * ribbon.frequency * TAU - elapsed * 12.0 + ribbon.phase) * (4.0 + ribbon.width * 4.5) * sin(t * PI)
		points.append(axis * ribbon.length * growth * t + normal * (arc + oscillation))
	# Keep every harmonic inside the source note's hue family; variation comes from light, not recoloring.
	var ribbon_color := energy_color.lerp(Color.WHITE, 0.16)
	draw_polyline(points, VisualColor.stroke(ribbon_color, fade * 0.12), ribbon.width * 6.2, true)
	draw_polyline(points, VisualColor.stroke(ribbon_color.lerp(Color.WHITE, 0.38), fade * 0.48), ribbon.width * 2.15, true)
	draw_polyline(points, VisualColor.stroke(Color.WHITE, fade * 0.72), maxf(0.55, ribbon.width * 0.48), true)
	if elapsed > 0.22:
		var tip := points[points.size() - 1]
		draw_circle(tip, ribbon.width * 2.8, VisualColor.stroke(ribbon_color, fade * 0.19))
		draw_circle(tip, ribbon.width * 0.78, VisualColor.stroke(Color.WHITE, fade * 0.9))
	pass
