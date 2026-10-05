class_name EmbeddingEffect
extends Control

## Semantic starfield: token text chips fly from the origin into RGB seats (Tokenizer-style trail).
## On arrival the rectangle expands away and the label stays in the rotating galaxy.
## Hosted by [ProcedureController]; plays after [TokenizerEffect].

const SPACE_SCALE := 5.0
const STAR_SIZE := 0.055
const AMBIENT_STAR_COUNT := 520
const AMBIENT_SPACE_SCALE := 4.2
const CAMERA_DISTANCE_NEAR := 6.4
const CAMERA_DISTANCE_FAR := 32.0
const CAMERA_FOV := 42.0
const CAMERA_NEAR_POS := Vector3(0.35, 0.55, CAMERA_DISTANCE_NEAR)
const CAMERA_FAR_POS := Vector3(1.6, 2.5, CAMERA_DISTANCE_FAR)
## Longer denser afterimage than [TokenizerEffect] so origin→seat flights read as streaks.
const FLY_TRAIL_INTERVAL := 0.038
const FLY_TRAIL_FADE := 0.72
const FLY_TRAIL_DRIFT := 0.48
const FLY_ARC_HEIGHT := 0.45
## World-space glyph size (not screen-fixed) so distance yields near-large / far-small.
const LABEL_PIXEL_SIZE := 0.00135
const LABEL_FONT_SIZE := 32
const FLY_SCALE_START := 0.08
const FLY_SCALE_END := 1.0
const FRAME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 effect_color : source_color = vec4(0.4, 0.85, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float border = 0.12;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float scale_x = length(MODEL_MATRIX[0].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * scale_x, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * scale_y, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz, 0.0),
		vec4(world_pos, 1.0)
	);
}

void fragment() {
	vec2 point = abs(UV * 2.0 - 1.0);
	float outer = max(point.x, point.y);
	float frame = smoothstep(1.0 - border, 1.0 - border * 0.45, outer);
	frame *= 1.0 - smoothstep(0.97, 1.0, outer);
	float alpha = frame * intensity * effect_color.a;
	ALBEDO = effect_color.rgb;
	EMISSION = effect_color.rgb * (0.9 + frame * 0.6);
	ALPHA = alpha;
}
"""

var token_fly_stagger := 0.2
var token_fly_duration := 1.2
var frame_expand_duration := 0.48
var galaxy_angular_speed := 0.12
## Camera dolly far→near duration at intro.
var camera_approach_duration := 5.0
var hold_after_settle := 0.35

var play_generation: int = 0
var rotating: bool = false
var viewport_container: SubViewportContainer
var sub_viewport: SubViewport
var camera: Camera3D
var galaxy_root: Node3D
var label_layer: Node3D
var ambient_stars: MultiMeshInstance3D
var flight_layer: Node3D
var trail_layer: Node3D
var star_material: StandardMaterial3D
var frame_shader: Shader
var stage_tweens: Array[Tween] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func _process(delta: float) -> void:
	if not rotating or galaxy_root == null or not is_instance_valid(galaxy_root):
		return
	galaxy_root.rotate_y(galaxy_angular_speed * delta)
	galaxy_root.rotate_x(galaxy_angular_speed * 0.22 * delta)
	pass


func on_theme_changed() -> void:
	pass


func cancel() -> void:
	play_generation += 1
	rotating = false
	clear_runtime()
	visible = false
	pass


func is_current(generation: int) -> bool:
	return generation == play_generation


## Dolly camera far→near while tokens fly in (Tokenizer-style); flights do not wait on the camera.
func play(tokens: Array[LlamaHelper.Token]) -> void:
	play_generation += 1
	var generation := play_generation
	ensure_scene()
	prepare_starfield()
	visible = true
	modulate = Color.WHITE
	rotating = true
	# Start camera without blocking token flights.
	animate_camera_approach(generation)
	await animate_token_flights(tokens, generation)
	if not is_current(generation):
		return
	if hold_after_settle > 0.0:
		await get_tree().create_timer(hold_after_settle).timeout
	pass


static func position_from_token_id(value: int) -> Vector3:
	return position_from_color(ProcedureTokenNode.color_from_token_id(value))


static func position_from_color(color: Color) -> Vector3:
	return Vector3((color.r - 0.5) * SPACE_SCALE, (color.g - 0.5) * SPACE_SCALE, (color.b - 0.5) * SPACE_SCALE)


func ensure_scene() -> void:
	if viewport_container != null and is_instance_valid(viewport_container):
		return

	viewport_container = SubViewportContainer.new()
	viewport_container.name = "EmbeddingViewport"
	viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)

	sub_viewport = SubViewport.new()
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.own_world_3d = true
	sub_viewport.msaa_3d = Viewport.MSAA_4X
	viewport_container.add_child(sub_viewport)

	var env_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.03, 0.08, 0.0)
	environment.glow_enabled = true
	environment.glow_intensity = 1.25
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.32
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = environment
	sub_viewport.add_child(env_node)

	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	sub_viewport.add_child(camera)
	reset_camera_to_far()

	galaxy_root = Node3D.new()
	galaxy_root.name = "GalaxyRoot"
	sub_viewport.add_child(galaxy_root)

	star_material = create_star_material()
	frame_shader = Shader.new()
	frame_shader.code = FRAME_SHADER
	ambient_stars = build_ambient_stars()
	galaxy_root.add_child(ambient_stars)

	label_layer = Node3D.new()
	label_layer.name = "LabelLayer"
	galaxy_root.add_child(label_layer)

	# Flight / trails stay in world space so origin→seat stays stable while the galaxy rotates.
	flight_layer = Node3D.new()
	flight_layer.name = "FlightLayer"
	sub_viewport.add_child(flight_layer)
	trail_layer = Node3D.new()
	trail_layer.name = "TrailLayer"
	sub_viewport.add_child(trail_layer)
	pass


func create_star_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_energy_multiplier = 1.35
	return material


func build_ambient_stars() -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = create_square_mesh(STAR_SIZE * 0.45)
	multi.instance_count = AMBIENT_STAR_COUNT
	for index in AMBIENT_STAR_COUNT:
		var direction := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if direction.length_squared() < 0.0001:
			direction = Vector3.FORWARD
		direction = direction.normalized()
		var radius := randf_range(AMBIENT_SPACE_SCALE * 0.55, AMBIENT_SPACE_SCALE)
		var scale := randf_range(0.35, 1.0)
		var transform := Transform3D.IDENTITY.scaled(Vector3.ONE * scale)
		transform.origin = direction * radius
		multi.set_instance_transform(index, transform)
		var dim := randf_range(0.28, 0.72)
		multi.set_instance_color(index, Color(0.62 * dim, 0.72 * dim, 1.0 * dim, dim))
	multi.visible_instance_count = AMBIENT_STAR_COUNT
	var instance := MultiMeshInstance3D.new()
	instance.name = "AmbientStars"
	instance.multimesh = multi
	instance.material_override = star_material
	return instance


func create_square_mesh(size: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	return mesh


func prepare_starfield() -> void:
	stop_animation()
	clear_layer_children(flight_layer)
	clear_layer_children(trail_layer)
	clear_layer_children(label_layer)
	show_ambient_stars()
	reset_camera_to_far()
	pass


func show_ambient_stars() -> void:
	if ambient_stars == null or not is_instance_valid(ambient_stars) or ambient_stars.multimesh == null:
		return
	ambient_stars.multimesh.visible_instance_count = ambient_stars.multimesh.instance_count
	pass


func reset_camera_to_far() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	camera.position = CAMERA_FAR_POS
	camera.look_at(Vector3.ZERO)
	pass


## Dolly the camera from far to near; ambient stars stay fully lit.
func animate_camera_approach(generation: int) -> void:
	reset_camera_to_far()
	show_ambient_stars()
	var duration := maxf(0.01, camera_approach_duration)
	var approach := remember_tween(create_tween())
	approach.tween_method(func(t: float) -> void:
		if not is_current(generation) or camera == null or not is_instance_valid(camera):
			return
		camera.position = CAMERA_FAR_POS.lerp(CAMERA_NEAR_POS, t)
		camera.look_at(Vector3.ZERO)
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await approach.finished
	if is_current(generation) and camera != null and is_instance_valid(camera):
		camera.position = CAMERA_NEAR_POS
		camera.look_at(Vector3.ZERO)
	pass


func animate_token_flights(tokens: Array[LlamaHelper.Token], generation: int) -> void:
	if tokens.is_empty():
		return
	var stagger := maxf(0.08, token_fly_stagger)
	var launch := remember_tween(create_tween())
	for token_index in tokens.size():
		launch.tween_callback(launch_token_flight.bind(token_index, tokens[token_index], generation))
		launch.tween_interval(stagger)
	await launch.finished
	if not is_current(generation):
		return
	await get_tree().create_timer(token_fly_duration + frame_expand_duration + FLY_TRAIL_FADE).timeout
	pass


## Same easing / arc / neon afterimages as [TokenizerEffect.launch_token_flight], flying origin → RGB seat.
func launch_token_flight(_token_index: int, token: LlamaHelper.Token, generation: int) -> void:
	if not is_current(generation) or flight_layer == null or not is_instance_valid(flight_layer):
		return
	if galaxy_root == null or not is_instance_valid(galaxy_root):
		return
	var color := ProcedureTokenNode.neon_display_color(ProcedureTokenNode.color_from_token_id(token.id))
	var display := ProcedureTokenNode.display_piece(token.piece)
	var target_local := position_from_color(ProcedureTokenNode.color_from_token_id(token.id))
	var start := Vector3.ZERO

	var chip := create_token_chip(display, color)
	chip.position = start
	chip.scale = Vector3.ONE * FLY_SCALE_START
	flight_layer.add_child(chip)
	var frame := chip.get_node("Frame") as MeshInstance3D
	var label := chip.get_node("Label") as Label3D

	var last_trail: Array[float] = [-FLY_TRAIL_INTERVAL]
	var flight := remember_tween(create_tween())
	flight.tween_method(func(t: float) -> void:
		if not is_current(generation) or not is_instance_valid(chip) or not is_instance_valid(galaxy_root):
			return
		var e := t * t
		var live_target := galaxy_root.to_global(target_local)
		var arc := Vector3(0.0, FLY_ARC_HEIGHT * sin(t * PI), 0.0)
		chip.position = start.lerp(live_target, e) + arc
		# Rectangle + text grow small → large while flying in (cinematic approach).
		chip.scale = Vector3.ONE * lerpf(FLY_SCALE_START, FLY_SCALE_END, e)
		chip.rotation.z = lerpf(0.0, -0.12, e)
		if t - last_trail[0] >= FLY_TRAIL_INTERVAL and e < 0.92:
			last_trail[0] = t
			spawn_trail_ghost(chip, start.direction_to(live_target), generation)
	, 0.0, 1.0, token_fly_duration)
	flight.tween_callback(func() -> void:
		if not is_current(generation):
			return
		arrive_token_chip(chip, frame, label, target_local, color, generation)
	)
	pass


func create_token_chip(text: String, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "TokenChip"
	root.add_child(make_token_label(text if not text.is_empty() else "·", color))

	var frame_size := estimate_frame_size(text)
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	var quad := QuadMesh.new()
	quad.size = frame_size
	frame.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = frame_shader
	material.set_shader_parameter("effect_color", Color(color, 0.95))
	material.set_shader_parameter("intensity", 1.0)
	material.set_shader_parameter("border", 0.14)
	frame.material_override = material
	root.add_child(frame)
	return root


func make_token_label(text: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = "Label"
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Critical: false keeps true perspective (near large / far small).
	label.fixed_size = false
	label.font = Fonts.regular()
	label.font_size = LABEL_FONT_SIZE
	label.pixel_size = LABEL_PIXEL_SIZE
	label.modulate = Color(0.97, 0.98, 1.0, 1.0)
	label.outline_size = 8
	label.outline_modulate = Color(color, 0.85)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func estimate_frame_size(text: String) -> Vector2:
	var glyphs := maxi(1, text.length())
	var width := clampf(float(glyphs) * LABEL_PIXEL_SIZE * float(LABEL_FONT_SIZE) * 0.62 + 0.05, 0.12, 0.55)
	var height := LABEL_PIXEL_SIZE * float(LABEL_FONT_SIZE) + 0.055
	return Vector2(width, height)


## Neon afterimage trail — same idea as [TokenizerEffect.spawn_trail_ghost], stretched longer.
func spawn_trail_ghost(source: Node3D, direction: Vector3, generation: int) -> void:
	if not is_current(generation) or trail_layer == null or not is_instance_valid(trail_layer):
		return
	if source == null or not is_instance_valid(source):
		return
	var ghost := source.duplicate() as Node3D
	if ghost == null:
		return
	trail_layer.add_child(ghost)
	ghost.position = source.position
	ghost.rotation = source.rotation
	ghost.scale = source.scale

	var ghost_label := ghost.get_node_or_null("Label") as Label3D
	var ghost_frame := ghost.get_node_or_null("Frame") as MeshInstance3D
	var ghost_material := ghost_frame.material_override as ShaderMaterial if ghost_frame != null else null
	if ghost_material != null:
		ghost_material = ghost_material.duplicate() as ShaderMaterial
		ghost_frame.material_override = ghost_material
	if ghost_label != null:
		ghost_label.modulate.a *= 0.62
		ghost_label.outline_modulate.a *= 0.62
	if ghost_material != null:
		ghost_material.set_shader_parameter("intensity", 0.55)

	var drift := -direction.normalized() * FLY_TRAIL_DRIFT if direction.length_squared() > 0.0001 else Vector3(0.0, -FLY_TRAIL_DRIFT * 0.7, 0.0)
	var fade := remember_tween(create_tween().set_parallel(true))
	fade.tween_property(ghost, "position", ghost.position + drift, FLY_TRAIL_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_property(ghost, "scale", ghost.scale * Vector3(0.78, 1.35, 1.0), FLY_TRAIL_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_method(func(alpha: float) -> void:
		if not is_instance_valid(ghost):
			return
		var label := ghost.get_node_or_null("Label") as Label3D
		if label != null:
			label.modulate.a = alpha
			label.outline_modulate.a = alpha
		var frame := ghost.get_node_or_null("Frame") as MeshInstance3D
		var material := frame.material_override as ShaderMaterial if frame != null else null
		if material != null:
			material.set_shader_parameter("intensity", alpha)
	, 0.55, 0.0, FLY_TRAIL_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.chain().tween_callback(func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free()
	)
	pass


func arrive_token_chip(chip: Node3D, frame: MeshInstance3D, label: Label3D, target_local: Vector3, color: Color, generation: int) -> void:
	if not is_current(generation):
		return
	if label != null and is_instance_valid(label) and label_layer != null and is_instance_valid(label_layer):
		var settled := make_token_label(label.text, color)
		label_layer.add_child(settled)
		settled.position = target_local
		settled.scale = Vector3.ONE
	if label != null and is_instance_valid(label):
		label.visible = false

	if frame == null or not is_instance_valid(frame):
		if is_instance_valid(chip):
			chip.queue_free()
		return

	var material := frame.material_override as ShaderMaterial
	var expand := remember_tween(create_tween().set_parallel(true))
	expand.tween_property(frame, "scale", Vector3.ONE * 2.4, frame_expand_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	expand.tween_method(func(intensity: float) -> void:
		if material == null or not is_instance_valid(frame):
			return
		material.set_shader_parameter("intensity", intensity)
	, 1.0, 0.0, frame_expand_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	expand.chain().tween_callback(func() -> void:
		if is_instance_valid(chip):
			chip.queue_free()
	)
	pass


func remember_tween(tween: Tween) -> Tween:
	stage_tweens.append(tween)
	return tween


func stop_animation() -> void:
	for tween in stage_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	stage_tweens.clear()
	pass


func clear_layer_children(layer: Node3D) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	for child in layer.get_children():
		child.queue_free()
	pass


func clear_runtime() -> void:
	stop_animation()
	clear_layer_children(flight_layer)
	clear_layer_children(trail_layer)
	clear_layer_children(label_layer)
	show_ambient_stars()
	reset_camera_to_far()
	pass
