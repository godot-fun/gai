class_name PixelBridgePierLights
extends Node2D

## Steady pier glow: flat lifetime ramps plus instant emission avoid warm-up flashes.
const GLOW_PARTICLE_COUNT := 5
const GLOW_LIFETIME := 512.0
const GLOW_SCALE_BASE := 1.55

var pixel: float = 4.0
var bridge_color := Color.WHITE
var lamp_center := Vector2.ZERO
var light_post_rect := Rect2()
var light_pulse: float = 1.0
var glow_scale: float = 1.0
var lamp_tint := Color(1.0, 0.76, 0.34, 1.0)
var active := false
var dark_theme := true

var glow_particles: GPUParticles2D
var glow_material: ParticleProcessMaterial
var built_glow_pixel := -1.0
var synced_draw_pulse := -1.0

static var shared_glow_texture: ImageTexture
static var shared_steady_color_ramp: GradientTexture1D
static var shared_steady_scale_curve: CurveTexture


func sync_visual(new_pixel: float, new_bridge_color: Color, new_lamp_center: Vector2, new_post_rect: Rect2, pulse: float, lamp: Color, pier_active: bool, new_glow_scale: float, new_dark_theme: bool) -> void:
	pixel = new_pixel
	bridge_color = new_bridge_color
	lamp_center = new_lamp_center
	light_post_rect = new_post_rect
	light_pulse = pulse
	glow_scale = new_glow_scale
	lamp_tint = lamp
	active = pier_active
	dark_theme = new_dark_theme
	visible = pier_active
	if not active:
		if glow_particles != null:
			glow_particles.emitting = false
			glow_particles.visible = false
		return
	ensure_glow_particles()
	sync_glow_particles()
	var draw_dirty := not is_equal_approx(pixel, built_glow_pixel) or absf(light_pulse - synced_draw_pulse) > 0.03
	if draw_dirty:
		built_glow_pixel = pixel
		synced_draw_pulse = light_pulse
		queue_redraw()
	pass


func ensure_glow_particles() -> void:
	if glow_particles != null or not is_inside_tree():
		return
	glow_particles = GPUParticles2D.new()
	glow_particles.name = "GlowParticles"
	glow_particles.z_index = 0
	glow_particles.amount = GLOW_PARTICLE_COUNT
	glow_particles.lifetime = GLOW_LIFETIME
	glow_particles.preprocess = 0.0
	glow_particles.explosiveness = 1.0
	glow_particles.interpolate = true
	glow_particles.randomness = 0.0
	glow_particles.local_coords = true
	glow_particles.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if shared_glow_texture == null:
		shared_glow_texture = make_glow_texture()
	glow_particles.texture = shared_glow_texture
	glow_material = ParticleProcessMaterial.new()
	glow_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	glow_material.spread = 0.0
	glow_material.initial_velocity_min = 0.0
	glow_material.initial_velocity_max = 0.0
	glow_material.gravity = Vector3.ZERO
	glow_material.lifetime_randomness = 0.0
	glow_material.color = Color.WHITE
	glow_material.color_ramp = steady_color_ramp()
	glow_material.scale_curve = steady_scale_curve()
	apply_particle_scale()
	glow_particles.process_material = glow_material
	glow_particles.emitting = true
	add_child(glow_particles)
	glow_particles.restart()
	pass


func sync_glow_particles() -> void:
	if glow_particles == null:
		return
	glow_particles.position = lamp_center
	glow_particles.visible = true
	glow_particles.emitting = true
	var bloom_alpha := (0.095 if dark_theme else 0.068) * light_pulse
	glow_particles.modulate = VisualColor.stroke(lamp_tint, bloom_alpha * 0.92)
	apply_particle_scale()
	if not is_equal_approx(pixel, built_glow_pixel):
		var half := pixel * 5.5
		glow_particles.visibility_rect = Rect2(lamp_center.x - half, lamp_center.y - half, half * 2.0, half * 2.0)
	pass


func apply_particle_scale() -> void:
	if glow_material == null:
		return
	var particle_scale := pixel * GLOW_SCALE_BASE * glow_scale
	glow_material.scale_min = particle_scale * 0.98
	glow_material.scale_max = particle_scale * 1.02
	pass


func _draw() -> void:
	if not active:
		return
	draw_rect(light_post_rect, Color(bridge_color, 0.28))
	var lamp_size := Vector2(pixel * 3.0, pixel)
	var lamp_rect := Rect2(lamp_center - lamp_size * 0.5, lamp_size)
	draw_rect(lamp_rect, Color(lamp_tint, 0.78 + 0.14 * light_pulse))
	draw_rect(lamp_rect.grow(-pixel * 0.25), Color(1.0, 0.92, 0.72, 0.35 + 0.28 * light_pulse))
	pass


static func steady_color_ramp() -> GradientTexture1D:
	if shared_steady_color_ramp != null:
		return shared_steady_color_ramp
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 1.0)])
	shared_steady_color_ramp = GradientTexture1D.new()
	shared_steady_color_ramp.gradient = gradient
	return shared_steady_color_ramp


static func steady_scale_curve() -> CurveTexture:
	if shared_steady_scale_curve != null:
		return shared_steady_scale_curve
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 1.0))
	shared_steady_scale_curve = CurveTexture.new()
	shared_steady_scale_curve.curve = curve
	return shared_steady_scale_curve


static func make_glow_texture() -> ImageTexture:
	const SIZE := 32
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SIZE - 1, SIZE - 1) * 0.5
	var radius := float(SIZE) * 0.5
	for y in range(SIZE):
		for x in range(SIZE):
			var dist := Vector2(x, y).distance_to(center) / radius
			var alpha := 1.0 - smoothstep(0.18, 0.78, dist)
			alpha *= alpha * alpha
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
