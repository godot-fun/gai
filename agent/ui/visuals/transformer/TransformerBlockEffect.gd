class_name TransformerBlockEffect
extends Control

## Sixteen accelerated matrix gates suggest the repeated transformations of a deep network.
## The effect reuses tokens settled in [EmbeddingEffect] and mutates their color and position in place.

const CAMERA_TRANSFER_POS := Vector3(2.4, 3.2, 12.8)
const GATE_SIZE := 4.5
const GATE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 effect_color : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform float progress = 0.0;
uniform float intensity = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 cells = abs(fract((UV + vec2(progress * 0.12, -progress * 0.08)) * 9.0) - 0.5);
	float traces = 1.0 - smoothstep(0.035, 0.075, min(cells.x, cells.y));
	float branches = step(0.56, fract(floor(UV.x * 9.0) * 0.37 + floor(UV.y * 9.0) * 0.61));
	traces *= mix(0.32, 1.0, branches);
	float square_radius = max(abs(p.x), abs(p.y));
	float wave_center = fract(progress * 1.65) * 1.18;
	float wave = 1.0 - smoothstep(0.025, 0.095, abs(square_radius - wave_center));
	float edge = smoothstep(0.72, 1.0, square_radius) * (1.0 - smoothstep(0.97, 1.02, square_radius));
	float alpha = (traces * 0.2 + wave * 0.82 + edge * 0.42) * intensity;
	ALBEDO = effect_color.rgb;
	EMISSION = effect_color.rgb * (1.4 + wave * 3.0 + traces);
	ALPHA = alpha * effect_color.a;
}
"""

var layer_count := 16
var camera_pull_duration := 0.8
var gate_duration := 1.65
var gate_frame_width := 0.018
var rearrange_distance := 0.035
var hold_after_layers := 0.45

var play_generation: int = 0
var embedding: EmbeddingEffect
var gate_shader: Shader
var stage_tweens: Array[Tween] = []
var active_gates: Array[Node3D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	gate_shader = Shader.new()
	gate_shader.code = GATE_SHADER
	pass


func on_theme_changed() -> void:
	pass


func set_embedding_effect(value: EmbeddingEffect) -> void:
	embedding = value
	pass


func cancel() -> void:
	play_generation += 1
	stop_animation()
	clear_gates()
	pass


func is_current(generation: int) -> bool:
	return generation == play_generation


func play(tokens: Array[LlamaHelper.Token]) -> void:
	play_generation += 1
	var generation := play_generation
	stop_animation()
	clear_gates()
	if embedding == null or not is_instance_valid(embedding) or tokens.is_empty():
		return
	if embedding.label_layer == null or not is_instance_valid(embedding.label_layer):
		return
	var labels := embedding.label_layer.get_children()
	var count := mini(tokens.size(), labels.size())
	if count == 0:
		return
	await pull_camera_back(generation)
	if not is_current(generation):
		return
	for layer_index in layer_count:
		if not is_current(generation):
			return
		await animate_gate_layer(tokens, labels, count, layer_index, generation)
	if hold_after_layers > 0.0:
		await get_tree().create_timer(hold_after_layers).timeout
	pass


func pull_camera_back(generation: int) -> void:
	if embedding.camera == null or not is_instance_valid(embedding.camera):
		return
	var start := embedding.camera.position
	var pull := remember_tween(create_tween())
	pull.tween_method(func(progress: float) -> void:
		if not is_current(generation) or embedding.camera == null or not is_instance_valid(embedding.camera):
			return
		embedding.camera.position = start.lerp(CAMERA_TRANSFER_POS, progress)
		embedding.camera.look_at(Vector3.ZERO)
	, 0.0, 1.0, camera_pull_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await pull.finished
	pass


func animate_gate_layer(tokens: Array[LlamaHelper.Token], labels: Array[Node], count: int, layer_index: int, generation: int) -> void:
	var color := gate_color(layer_index)
	var gate := create_matrix_gate(color, layer_index)
	active_gates.append(gate)
	embedding.sub_viewport.add_child(gate)
	var start := layer_start(layer_index)
	var finish := layer_finish(layer_index)
	set_gate_world_transform(gate, start, -0.08)
	var impacted := PackedByteArray()
	impacted.resize(count)
	var thresholds := PackedFloat32Array()
	thresholds.resize(count)
	var sweep := finish - start
	var sweep_length_squared := maxf(0.0001, sweep.length_squared())
	for token_index in count:
		var label := labels[token_index] as Label3D
		thresholds[token_index] = clampf((label.global_position - start).dot(sweep) / sweep_length_squared, 0.08, 0.92) if label != null else 1.0
	var ghost_marks := [0.2, 0.43, 0.67]
	var next_ghost := 0
	var surface := gate.get_node("Surface") as MeshInstance3D
	var shader_material := surface.material_override as ShaderMaterial
	var travel := remember_tween(create_tween())
	travel.tween_method(func(progress: float) -> void:
		if not is_current(generation) or not is_instance_valid(gate):
			return
		set_gate_world_transform(gate, start.lerp(finish, progress), lerpf(-0.08, 0.1, progress))
		if shader_material != null:
			shader_material.set_shader_parameter("progress", progress + float(layer_index) * 0.17)
			shader_material.set_shader_parameter("intensity", 0.72 + sin(progress * PI) * 0.45)
		while next_ghost < ghost_marks.size() and progress >= ghost_marks[next_ghost]:
			spawn_gate_afterimage(gate, color, generation)
			next_ghost += 1
		for token_index in count:
			if impacted[token_index] != 0 or progress < thresholds[token_index]:
				continue
			impacted[token_index] = 1
			transform_token(labels[token_index] as Label3D, tokens[token_index], layer_index)
	, 0.0, 1.0, gate_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await travel.finished
	if is_instance_valid(gate):
		gate.queue_free()
	active_gates.erase(gate)
	pass


func layer_start(layer_index: int) -> Vector3:
	var camera_basis := embedding.camera.global_transform.basis
	var center := embedding.galaxy_root.global_position + camera_basis.y.normalized() * 0.35
	var depth := sin(float(layer_index) * 1.37) * 0.42
	return center + camera_basis.x.normalized() * screen_edge_distance(center) - camera_basis.z.normalized() * depth


func layer_finish(layer_index: int) -> Vector3:
	var camera_basis := embedding.camera.global_transform.basis
	var center := embedding.galaxy_root.global_position + camera_basis.y.normalized() * 0.35
	var depth := cos(float(layer_index) * 1.19) * 0.42
	return center - camera_basis.x.normalized() * screen_edge_distance(center) - camera_basis.z.normalized() * depth


func screen_edge_distance(center: Vector3) -> float:
	var camera_basis := embedding.camera.global_transform.basis
	var forward := -camera_basis.z.normalized()
	var depth := maxf(0.1, (center - embedding.camera.global_position).dot(forward))
	var vertical_extent := depth * tan(deg_to_rad(embedding.camera.fov * 0.5))
	var viewport_size := embedding.sub_viewport.size
	var aspect := float(viewport_size.x) / float(maxi(1, viewport_size.y))
	var horizontal_extent := vertical_extent * aspect
	# Include half the gate so it begins fully outside the right edge and exits fully past the left edge.
	return horizontal_extent + GATE_SIZE * 0.5 + 0.25


func set_gate_world_transform(gate: Node3D, position: Vector3, roll: float) -> void:
	var camera_basis := embedding.camera.global_transform.basis.orthonormalized()
	var rolled_basis := camera_basis.rotated(camera_basis.z.normalized(), roll)
	gate.global_transform = Transform3D(rolled_basis, position)
	pass


func gate_color(layer_index: int) -> Color:
	var phase := float(layer_index) / float(maxi(1, layer_count - 1))
	return TransformerTokenNode.neon_display_color(Color.from_hsv(lerpf(0.52, 0.86, phase), 0.62, 1.0))


func create_matrix_gate(color: Color, layer_index: int) -> Node3D:
	var gate := Node3D.new()
	gate.name = "TransferLayer%02d" % (layer_index + 1)
	var surface := MeshInstance3D.new()
	surface.name = "Surface"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * GATE_SIZE
	surface.mesh = quad
	var shader_material := ShaderMaterial.new()
	shader_material.shader = gate_shader
	shader_material.set_shader_parameter("effect_color", Color(color, 0.78))
	shader_material.set_shader_parameter("progress", 0.0)
	shader_material.set_shader_parameter("intensity", 0.8)
	surface.material_override = shader_material
	gate.add_child(surface)
	var half := GATE_SIZE * 0.5
	gate.add_child(create_frame_edge(Vector3(0.0, -half, 0.015), Vector3(GATE_SIZE, gate_frame_width, gate_frame_width), color))
	gate.add_child(create_frame_edge(Vector3(0.0, half, 0.015), Vector3(GATE_SIZE, gate_frame_width, gate_frame_width), color))
	gate.add_child(create_frame_edge(Vector3(-half, 0.0, 0.015), Vector3(gate_frame_width, GATE_SIZE, gate_frame_width), color))
	gate.add_child(create_frame_edge(Vector3(half, 0.0, 0.015), Vector3(gate_frame_width, GATE_SIZE, gate_frame_width), color))
	return gate


func create_frame_edge(position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var edge := MeshInstance3D.new()
	edge.name = "FrameEdge"
	var box := BoxMesh.new()
	box.size = size
	edge.mesh = box
	edge.position = position
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.88)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.4
	edge.material_override = material
	return edge


func spawn_gate_afterimage(source: Node3D, color: Color, generation: int) -> void:
	if not is_current(generation) or not is_instance_valid(source):
		return
	var ghost := create_matrix_gate(color, 0)
	ghost.name = "TransferAfterimage"
	ghost.transform = source.transform
	embedding.sub_viewport.add_child(ghost)
	active_gates.append(ghost)
	var fade := remember_tween(create_tween().set_parallel(true))
	fade.tween_property(ghost, "scale", Vector3(1.06, 1.06, 1.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_method(func(intensity: float) -> void:
		if not is_instance_valid(ghost):
			return
		var surface := ghost.get_node("Surface") as MeshInstance3D
		var material := surface.material_override as ShaderMaterial
		material.set_shader_parameter("intensity", intensity)
		for child in ghost.get_children():
			var edge := child as MeshInstance3D
			if edge == null or edge == surface:
				continue
			var edge_material := edge.material_override as StandardMaterial3D
			if edge_material != null:
				edge_material.albedo_color.a = intensity * 0.55
	, 0.42, 0.0, 0.2)
	fade.chain().tween_callback(func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free()
		active_gates.erase(ghost)
	)
	pass


func transform_token(label: Label3D, token: LlamaHelper.Token, layer_index: int) -> void:
	if label == null or not is_instance_valid(label):
		return
	var transformed_id := token.id + (layer_index + 1) * 7919
	var color := TransformerTokenNode.neon_display_color(TransformerTokenNode.color_from_token_id(transformed_id))
	label.outline_modulate = Color(color, 0.94)
	label.modulate = Color.WHITE.lerp(color, 0.18)
	var angle := float((token.id * 31 + layer_index * 47) % 360) * PI / 180.0
	var vertical := sin(float(token.id + layer_index * 13) * 0.73) * rearrange_distance * 0.55
	var offset := Vector3(cos(angle) * rearrange_distance, vertical, sin(angle) * rearrange_distance)
	label.position += offset
	label.position = label.position.clamp(Vector3.ONE * -EmbeddingEffect.SPACE_SCALE * 0.52, Vector3.ONE * EmbeddingEffect.SPACE_SCALE * 0.52)
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


func clear_gates() -> void:
	for gate in active_gates:
		if gate != null and is_instance_valid(gate):
			gate.queue_free()
	active_gates.clear()
	pass
