class_name PixelWeather
extends Node2D

const MIN_RAIN_AMOUNT := 56
const MAX_RAIN_EXTRA := 112
const MAX_RAIN_AMOUNT := MIN_RAIN_AMOUNT + MAX_RAIN_EXTRA
const FALL_SPEED := 250.0

var viewport_size := Vector2.ZERO
var pixel: float = 4.0
var elapsed: float = 0.0
var rain_intensity: float = 0.0

var rain_particles: GPUParticles2D
var rain_material: ParticleProcessMaterial
var layout_viewport_size := Vector2.ZERO
var layout_pixel := 0.0


func _ready() -> void:
	ensure_rain_particles()
	pass


func update_visual(new_size: Vector2, new_pixel: float, new_elapsed: float, new_rain: float) -> void:
	viewport_size = new_size
	pixel = new_pixel
	elapsed = new_elapsed
	rain_intensity = new_rain
	ensure_rain_particles()
	sync_rain_particles()
	pass


func ensure_rain_particles() -> void:
	if rain_particles != null or not is_inside_tree():
		return
	build_rain_particles()
	pass


func build_rain_particles() -> void:
	rain_particles = GPUParticles2D.new()
	rain_particles.name = "Rain"
	rain_particles.z_index = 10
	rain_particles.amount = MAX_RAIN_AMOUNT
	rain_particles.local_coords = true
	rain_particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rain_particles.texture = make_rain_texture()
	rain_material = ParticleProcessMaterial.new()
	rain_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_material.direction = Vector3(-1.0, 3.0, 0.0).normalized()
	rain_material.spread = 4.0
	rain_material.gravity = Vector3.ZERO
	rain_material.initial_velocity_min = FALL_SPEED * 0.96
	rain_material.initial_velocity_max = FALL_SPEED * 1.04
	rain_material.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	rain_particles.process_material = rain_material
	add_child(rain_particles)
	sync_rain_particles()
	pass


func sync_rain_particles() -> void:
	if rain_particles == null or viewport_size == Vector2.ZERO:
		return
	var active := rain_intensity > 0.01
	rain_particles.emitting = active
	rain_particles.visible = active
	if not active:
		return
	if viewport_size != layout_viewport_size or not is_equal_approx(pixel, layout_pixel):
		apply_rain_layout()
	var density := MIN_RAIN_AMOUNT + rain_intensity * MAX_RAIN_EXTRA
	rain_particles.amount_ratio = clampf(density / float(MAX_RAIN_AMOUNT), 0.08, 1.0)
	rain_particles.modulate = Color(0.49, 0.76, 0.96, rain_intensity * 0.34)
	pass


func apply_rain_layout() -> void:
	layout_viewport_size = viewport_size
	layout_pixel = pixel
	var half_width := viewport_size.x * 0.5
	var half_height := viewport_size.y * 0.62
	rain_material.emission_box_extents = Vector3(half_width, half_height, 1.0)
	rain_particles.position = Vector2(half_width, viewport_size.y * 0.44)
	var streak_scale := pixel * 0.25
	rain_material.scale_min = streak_scale * 0.92
	rain_material.scale_max = streak_scale * 1.08
	rain_particles.lifetime = clampf(viewport_size.y / FALL_SPEED * 1.15, 1.4, 4.8)
	rain_particles.preprocess = rain_particles.lifetime
	rain_particles.visibility_rect = Rect2(-half_width, -half_height, viewport_size.x, viewport_size.y + half_height).grow(maxf(viewport_size.x, viewport_size.y) * 0.15)
	pass


static func make_rain_texture() -> ImageTexture:
	const HEIGHT := 12
	var image := Image.create(1, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in range(HEIGHT):
		var t := float(y) / float(HEIGHT - 1)
		var alpha := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.82, 1.0, t))
		image.set_pixel(0, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
