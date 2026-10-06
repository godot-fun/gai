class_name AttentionEffect
extends TransformerStageEffect

## Sequential attention scan over tokens already settled by [EmbeddingEffect].
## A short energy trail travels token-to-token; every arrival pulses the target token.

const PULSE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 effect_color : source_color = vec4(0.4, 0.85, 1.0, 1.0);
uniform float intensity = 1.0;

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
	float radius = length(UV * 2.0 - 1.0);
	float core = 1.0 - smoothstep(0.0, 0.28, radius);
	float glow = 1.0 - smoothstep(0.05, 1.0, radius);
	float alpha = (core + glow * 0.55) * intensity * effect_color.a;
	ALBEDO = effect_color.rgb;
	EMISSION = effect_color.rgb * (1.5 + core * 2.5);
	ALPHA = alpha;
}
"""

var travel_duration := 0.34
var pulse_duration := 0.85
var flow_line_width := 0.018
var flow_tail_ratio := 0.88
var flow_line_segments := 14
var pulse_scale := 1.65
var hold_after_scan := 0.4

var embedding: EmbeddingEffect
var pulse_shader: Shader
var active_path: Path3D
var active_line: MeshInstance3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	pulse_shader = Shader.new()
	pulse_shader.code = PULSE_SHADER
	pass


func on_theme_changed() -> void:
	pass


func set_embedding_effect(value: EmbeddingEffect) -> void:
	embedding = value
	pass


func cancel() -> void:
	begin_play()
	stop_animation()
	clear_attention_nodes()
	pass


func play(tokens: Array[LlamaHelper.Token]) -> void:
	var generation := begin_play()
	stop_animation()
	clear_attention_nodes()
	if embedding == null or not is_instance_valid(embedding) or tokens.size() < 2:
		return
	if embedding.label_layer == null or not is_instance_valid(embedding.label_layer):
		return
	var labels := embedding.label_layer.get_children()
	var count := mini(tokens.size(), labels.size())
	if count < 2:
		return
	pulse_token(labels[0] as Label3D, token_color(tokens[0]), generation)
	for token_index in range(count - 1):
		if not is_current(generation):
			return
		var from_label := labels[token_index] as Label3D
		var to_label := labels[token_index + 1] as Label3D
		if from_label == null or to_label == null:
			continue
		var color := AttentionEffect.average_color(token_color(tokens[token_index]), token_color(tokens[token_index + 1]))
		await animate_flow(from_label.position, to_label.position, color, generation)
		if not is_current(generation):
			return
		pulse_token(to_label, token_color(tokens[token_index + 1]), generation)
	if hold_after_scan > 0.0:
		await get_tree().create_timer(hold_after_scan).timeout
	pass


static func average_color(first: Color, second: Color) -> Color:
	return Color((first.r + second.r) * 0.5, (first.g + second.g) * 0.5, (first.b + second.b) * 0.5, (first.a + second.a) * 0.5)


static func token_color(token: LlamaHelper.Token) -> Color:
	return TransformerTokenNode.neon_display_color(TransformerTokenNode.color_from_token_id(token.id))


func animate_flow(from_position: Vector3, to_position: Vector3, color: Color, generation: int) -> void:
	var offset := to_position - from_position
	var distance := offset.length()
	if distance < 0.0001:
		return
	clear_active_flow()
	var path := create_curved_path(from_position, to_position)
	var line := create_flow_line(color)
	active_path = path
	active_line = line
	embedding.connection_layer.add_child(path)
	embedding.connection_layer.add_child(line)
	var flow := remember_tween(create_tween())
	flow.tween_method(func(progress: float) -> void:
		if not is_current(generation) or not is_instance_valid(line):
			return
		update_flow_line(line, path.curve, progress, color)
	, 0.0, 1.0, maxf(0.01, travel_duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await flow.finished
	if not is_instance_valid(line):
		return
	line.visible = false
	line.queue_free()
	path.queue_free()
	if active_path == path:
		active_path = null
	if active_line == line:
		active_line = null
	pass


func create_curved_path(from_position: Vector3, to_position: Vector3) -> Path3D:
	var path := Path3D.new()
	path.name = "AttentionCurve"
	var curve := Curve3D.new()
	var offset := to_position - from_position
	var distance := offset.length()
	var direction := offset / maxf(0.0001, distance)
	var midpoint := (from_position + to_position) * 0.5
	var camera_local := embedding.galaxy_root.to_local(embedding.camera.global_position)
	var view_direction := midpoint.direction_to(camera_local)
	var bend_axis := direction.cross(view_direction)
	if bend_axis.length_squared() < 0.0001:
		bend_axis = direction.cross(Vector3.UP)
	if bend_axis.length_squared() < 0.0001:
		bend_axis = direction.cross(Vector3.RIGHT)
	var signature := from_position.x + from_position.y * 1.7 + from_position.z * 2.3
	var bend_sign := -1.0 if sin(signature * 3.1) < 0.0 else 1.0
	var bend := bend_axis.normalized() * clampf(distance * 0.22, 0.16, 0.72) * bend_sign
	var forward_handle := offset * 0.34 + bend
	var backward_handle := -offset * 0.34 + bend
	curve.add_point(from_position, Vector3.ZERO, forward_handle)
	curve.add_point(to_position, backward_handle, Vector3.ZERO)
	curve.bake_interval = 0.035
	path.curve = curve
	return path


func create_flow_line(color: Color) -> MeshInstance3D:
	var line := MeshInstance3D.new()
	line.name = "AttentionFlowLine"
	line.mesh = ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.8
	line.material_override = material
	return line


func update_flow_line(line: MeshInstance3D, curve: Curve3D, head_ratio: float, color: Color) -> void:
	var immediate := line.mesh as ImmediateMesh
	immediate.clear_surfaces()
	if head_ratio <= 0.001:
		return
	var tail_ratio := maxf(0.0, head_ratio - flow_tail_ratio)
	var baked_length := curve.get_baked_length()
	var camera_local := embedding.galaxy_root.to_local(embedding.camera.global_position)
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for segment_index in flow_line_segments + 1:
		var amount := float(segment_index) / float(flow_line_segments)
		var ratio := lerpf(tail_ratio, head_ratio, amount)
		var position := curve.sample_baked(ratio * baked_length, true)
		var previous_ratio := maxf(tail_ratio, ratio - 0.005)
		var next_ratio := minf(head_ratio, ratio + 0.005)
		var previous := curve.sample_baked(previous_ratio * baked_length, true)
		var next := curve.sample_baked(next_ratio * baked_length, true)
		var direction := previous.direction_to(next)
		if direction.length_squared() < 0.0001:
			direction = Vector3.RIGHT
		var view_direction := position.direction_to(camera_local)
		var side := direction.cross(view_direction)
		if side.length_squared() < 0.0001:
			side = direction.cross(Vector3.UP)
		side = side.normalized() * flow_line_width * lerpf(0.28, 1.0, amount)
		var alpha := pow(amount, 1.35) * 0.88
		immediate.surface_set_color(Color(color, alpha))
		immediate.surface_set_uv(Vector2(amount, 0.0))
		immediate.surface_add_vertex(position - side)
		immediate.surface_set_color(Color(color, alpha))
		immediate.surface_set_uv(Vector2(amount, 1.0))
		immediate.surface_add_vertex(position + side)
	immediate.surface_end()
	pass


func clear_active_flow() -> void:
	if active_line != null and is_instance_valid(active_line):
		active_line.queue_free()
	if active_path != null and is_instance_valid(active_path):
		active_path.queue_free()
	active_path = null
	active_line = null
	pass


func pulse_token(label: Label3D, color: Color, generation: int) -> void:
	if label == null or not is_instance_valid(label) or not is_current(generation):
		return
	var halo := create_pulse_halo(color)
	embedding.connection_layer.add_child(halo)
	halo.position = label.position
	halo.scale = Vector3.ONE * 0.18
	var material := halo.material_override as ShaderMaterial
	var pulse := remember_tween(create_tween().set_parallel(true))
	pulse.tween_property(label, "scale", Vector3.ONE * pulse_scale, pulse_duration * 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(label, "modulate", Color(1.35, 1.35, 1.35, 1.0), pulse_duration * 0.28)
	pulse.tween_property(halo, "scale", Vector3.ONE * 1.8, pulse_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pulse.tween_method(func(intensity: float) -> void:
		if material != null and is_instance_valid(halo):
			material.set_shader_parameter("intensity", intensity)
	, 1.0, 0.0, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	pulse.chain().tween_interval(pulse_duration * 0.22)
	pulse.chain().tween_property(label, "scale", Vector3.ONE, pulse_duration * 0.46).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	pulse.tween_property(label, "modulate", Color.WHITE, pulse_duration * 0.46)
	pulse.tween_callback(func() -> void:
		if is_instance_valid(halo):
			halo.queue_free()
	)
	pass

func create_pulse_halo(color: Color) -> MeshInstance3D:
	var halo := MeshInstance3D.new()
	halo.name = "AttentionPulse"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.38, 0.38)
	halo.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = pulse_shader
	material.set_shader_parameter("effect_color", Color(color, 0.9))
	material.set_shader_parameter("intensity", 1.0)
	halo.material_override = material
	return halo


func clear_attention_nodes() -> void:
	clear_active_flow()
	if embedding == null or not is_instance_valid(embedding):
		return
	if embedding.connection_layer == null or not is_instance_valid(embedding.connection_layer):
		return
	for child in embedding.connection_layer.get_children():
		child.queue_free()
	if embedding.label_layer != null and is_instance_valid(embedding.label_layer):
		for child in embedding.label_layer.get_children():
			var label := child as Label3D
			if label != null:
				label.scale = Vector3.ONE
				label.modulate = Color.WHITE
	pass
