class_name AttentionEffect
extends Control

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
var trail_length_ratio := 0.55
var trail_width := 0.012
var pulse_scale := 1.65
var hold_after_scan := 0.4

var play_generation: int = 0
var embedding: EmbeddingEffect
var stage_tweens: Array[Tween] = []
var pulse_shader: Shader


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
	play_generation += 1
	stop_animation()
	clear_attention_nodes()
	pass


func is_current(generation: int) -> bool:
	return generation == play_generation


func play(tokens: Array[LlamaHelper.Token]) -> void:
	play_generation += 1
	var generation := play_generation
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
	return ProcedureTokenNode.neon_display_color(ProcedureTokenNode.color_from_token_id(token.id))


func animate_flow(from_position: Vector3, to_position: Vector3, color: Color, generation: int) -> void:
	var offset := to_position - from_position
	var distance := offset.length()
	if distance < 0.0001:
		return
	var trail := create_trail(color)
	var head := create_energy_head(color)
	embedding.connection_layer.add_child(trail)
	embedding.connection_layer.add_child(head)
	head.position = from_position
	var direction := offset / distance
	var flow := remember_tween(create_tween())
	flow.tween_method(func(progress: float) -> void:
		if not is_current(generation) or not is_instance_valid(trail) or not is_instance_valid(head):
			return
		var head_distance := distance * progress
		var tail_distance := distance * maxf(0.0, progress - trail_length_ratio)
		set_trail_segment(trail, from_position + direction * tail_distance, from_position + direction * head_distance)
		head.position = from_position + offset * progress
		var beat := 0.82 + sin(progress * PI * 5.0) * 0.18
		head.scale = Vector3.ONE * beat
	, 0.0, 1.0, maxf(0.01, travel_duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await flow.finished
	if not is_instance_valid(trail) or not is_instance_valid(head):
		return
	var fade := remember_tween(create_tween().set_parallel(true))
	fade.tween_property(trail, "scale", Vector3(0.15, 1.0, 0.15), 0.12)
	fade.tween_property(head, "scale", Vector3.ONE * 0.05, 0.12)
	fade.chain().tween_callback(func() -> void:
		if is_instance_valid(trail):
			trail.queue_free()
		if is_instance_valid(head):
			head.queue_free()
	)
	pass


func create_trail(color: Color) -> MeshInstance3D:
	var trail := MeshInstance3D.new()
	trail.name = "AttentionTrail"
	var cylinder := CylinderMesh.new()
	cylinder.height = 1.0
	cylinder.top_radius = trail_width * 0.35
	cylinder.bottom_radius = trail_width
	cylinder.radial_segments = 8
	trail.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.62)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.8
	trail.material_override = material
	return trail


func create_energy_head(color: Color) -> MeshInstance3D:
	var head := MeshInstance3D.new()
	head.name = "AttentionHead"
	var sphere := SphereMesh.new()
	sphere.radius = trail_width * 3.4
	sphere.height = trail_width * 6.8
	sphere.radial_segments = 12
	sphere.rings = 6
	head.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.95)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 6.0
	head.material_override = material
	return head


func set_trail_segment(trail: MeshInstance3D, from_position: Vector3, to_position: Vector3) -> void:
	var offset := to_position - from_position
	var distance := maxf(0.001, offset.length())
	trail.position = (from_position + to_position) * 0.5
	trail.basis = Basis(Quaternion(Vector3.UP, offset / distance))
	trail.scale = Vector3(1.0, distance, 1.0)
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


func remember_tween(tween: Tween) -> Tween:
	stage_tweens.append(tween)
	return tween


func stop_animation() -> void:
	for tween in stage_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	stage_tweens.clear()
	pass


func clear_attention_nodes() -> void:
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
