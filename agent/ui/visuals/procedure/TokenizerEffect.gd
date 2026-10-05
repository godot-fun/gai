class_name TokenizerEffect
extends Control

## Staged tokenizer animation: sentence train-in → boundary cuts → vocabulary ID reveal.
## Hosted by [ProcedureController]; sibling stages (e.g. EmbeddingEffect) can follow.

const MIN_TOKEN_COUNT := 12
const TOKEN_FONT_SIZE := 34
const TOKEN_HEIGHT := 86.0
const TOKEN_MIN_WIDTH := 12.0
const TOKEN_HORIZONTAL_PADDING := 0.0
const CUT_GAP := 30.0
const ROW_SCREEN_MARGIN := 48.0
const CUTTER_WIDTH := 44.0
const CUTTER_HEIGHT := TOKEN_HEIGHT + 36.0
const CUT_SHAKE_AMPLITUDE := 7.5
const HAZE_SHADER := """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 effect_color : source_color = vec4(0.0, 0.84, 0.68, 1.0);

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float y = abs(UV.y - 0.5) * 2.0;
	float soft = exp(-pow(x * 1.15, 2.0)) * exp(-pow(y * 2.4, 2.0));
	float alpha = soft * 0.15 * COLOR.a;
	COLOR = vec4(effect_color.rgb * soft, alpha);
}
"""
const CUTTER_SHADER := """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 effect_color : source_color = vec4(0.0, 0.84, 0.68, 1.0);
uniform float intensity = 1.0;

void fragment() {
	// Single descending slit: hot white core + soft theme bloom, brighter toward the leading tip.
	float x = UV.x - 0.5;
	float core = exp(-pow(abs(x) * 58.0, 2.0));
	float body = exp(-pow(abs(x) * 22.0, 2.0));
	float bloom = exp(-pow(abs(x) * 8.0, 2.0));
	float y_soft = smoothstep(0.0, 0.04, UV.y) * smoothstep(1.0, 0.96, UV.y);
	float tip = mix(0.78, 1.22, smoothstep(0.0, 1.0, UV.y));
	float beam = (core * 1.4 + body * 0.55) * tip;
	float alpha = (beam + bloom * 0.4 * tip) * y_soft * intensity * COLOR.a;
	vec3 color = mix(effect_color.rgb, vec3(1.0), clamp(core * 1.85 + body * 0.4, 0.0, 1.0));
	color += effect_color.rgb * bloom * 0.5;
	COLOR = vec4(color * intensity, alpha);
}
"""

## Total duration of each major animation stage.
var train_arrival_duration := 1.35
var token_cut_duration := 2.6
var token_reveal_duration := 2.8

var play_generation: int = 0
var row: Control
var token_nodes: Array[ProcedureTokenNode] = []
var cutter: ColorRect
var cutter_material: ShaderMaterial
var row_haze: ColorRect
var haze_material: ShaderMaterial
var active_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	pass


func on_theme_changed() -> void:
	for token_node in token_nodes:
		token_node.refresh_theme()
	sync_cutter_theme()
	pass


func sync_cutter_theme() -> void:
	var accent := ThemeColor.accent_theme_color()
	if cutter_material != null:
		cutter_material.set_shader_parameter("effect_color", accent)
	if haze_material != null:
		haze_material.set_shader_parameter("effect_color", accent)
	pass


func cancel() -> void:
	play_generation += 1
	stop_animation()
	clear_tokens()
	pass


## Builds the token row and plays arrival → cut → reveal. Cancels any prior play.
func play(tokens: Array[LlamaHelper.Token]) -> void:
	play_generation += 1
	var generation := play_generation
	build_tokens(tokens)
	await animate_procedure(generation)
	pass


static func select_complete_sentence(tokens: Array[LlamaHelper.Token], minimum: int = MIN_TOKEN_COUNT) -> Array[LlamaHelper.Token]:
	var selected: Array[LlamaHelper.Token] = []
	for token in tokens:
		selected.append(token)
		if selected.size() >= minimum and is_sentence_end(token.piece):
			break
	return selected


static func is_sentence_end(piece: String) -> bool:
	var trimmed := piece.strip_edges()
	if trimmed.is_empty():
		return false
	while not trimmed.is_empty() and "\"'”’」』）)]}".contains(trimmed.right(1)):
		trimmed = trimmed.left(-1).strip_edges()
	return trimmed.ends_with(".") or trimmed.ends_with("!") or trimmed.ends_with("?") or trimmed.ends_with("。") or trimmed.ends_with("！") or trimmed.ends_with("？")


func build_tokens(tokens: Array[LlamaHelper.Token]) -> void:
	clear_tokens()
	row = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var font := Fonts.regular()
	var x := 0.0
	for token in tokens:
		var display := ProcedureTokenNode.display_piece(token.piece)
		var width := maxf(TOKEN_MIN_WIDTH, font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, TOKEN_FONT_SIZE).x + TOKEN_HORIZONTAL_PADDING)
		var token_node := ProcedureTokenNode.new()
		token_node.setup(token, Vector2(width, TOKEN_HEIGHT))
		token_node.position = Vector2(x, 0.0)
		token_node.pivot_offset = Vector2(width * 0.5, TOKEN_HEIGHT * 0.42)
		row.add_child(token_node)
		token_nodes.append(token_node)
		x += width
	row.size = Vector2(x, TOKEN_HEIGHT)
	row.pivot_offset = row.size * 0.5
	row_haze = ColorRect.new()
	row_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_haze.color = Color(1.0, 1.0, 1.0, 1.0)
	row_haze.position = Vector2(-36.0, -28.0)
	row_haze.size = Vector2(row.size.x + 72.0, TOKEN_HEIGHT + 40.0)
	row_haze.z_index = -1
	haze_material = create_shader_material(HAZE_SHADER)
	row_haze.material = haze_material
	row.add_child(row_haze)
	cutter = ColorRect.new()
	cutter.color = Color(1.0, 1.0, 1.0, 0.0)
	cutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cutter.size = Vector2(CUTTER_WIDTH, CUTTER_HEIGHT)
	cutter.pivot_offset = Vector2(CUTTER_WIDTH * 0.5, CUTTER_HEIGHT * 0.5)
	cutter.position = Vector2(-CUTTER_WIDTH * 0.5, -CUTTER_HEIGHT)
	cutter.rotation = 0.03
	cutter.z_index = 10
	cutter_material = create_shader_material(CUTTER_SHADER)
	cutter.material = cutter_material
	sync_cutter_theme()
	row.add_child(cutter)
	spawn_ambient_dust()
	var available_width := maxf(1.0, size.x - ROW_SCREEN_MARGIN * 2.0)
	var fit_scale := minf(1.0, available_width / row.size.x)
	row.scale = Vector2(fit_scale, fit_scale)
	row.position = Vector2(size.x + ROW_SCREEN_MARGIN, (size.y - TOKEN_HEIGHT * fit_scale) * 0.5)
	pass


static func create_shader_material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	return shader_material


func animate_procedure(generation: int) -> void:
	var scaled_width := row.size.x * row.scale.x
	var centered_x := (size.x - scaled_width) * 0.5
	active_tween = create_tween()
	active_tween.tween_property(row, "position:x", centered_x, train_arrival_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await active_tween.finished
	if generation != play_generation:
		return

	await animate_cut_stage(generation)
	if generation != play_generation:
		return

	var reveal_tween := create_tween()
	var step_duration := maxf(0.32, token_reveal_duration / float(maxi(1, token_nodes.size())))
	for token_node in token_nodes:
		reveal_tween.tween_callback(reveal_token.bind(token_node, step_duration * 1.55))
		reveal_tween.tween_interval(step_duration)
	active_tween = reveal_tween
	await reveal_tween.finished
	# Let the last scramble finish before the procedure ends.
	await get_tree().create_timer(step_duration * 0.7).timeout
	pass


func reveal_token(token_node: ProcedureTokenNode, duration: float) -> void:
	token_node.play_reveal(duration)
	pass


func animate_cut_stage(generation: int) -> void:
	var boundary_count := maxi(0, token_nodes.size() - 1)
	if boundary_count == 0:
		await get_tree().create_timer(token_cut_duration).timeout
		return
	var cut_width := row.size.x + CUT_GAP * boundary_count
	var available_width := maxf(1.0, size.x - ROW_SCREEN_MARGIN * 2.0)
	var final_scale := minf(1.0, available_width / cut_width)
	var initial_scale := row.scale.x
	var step_duration := maxf(0.28, token_cut_duration / float(boundary_count))
	var targets: Array[float] = []
	for token_node in token_nodes:
		targets.append(token_node.position.x)
	var order := left_to_right_boundary_order(boundary_count)
	cutter.color.a = 0.0
	for order_index in order.size():
		if generation != play_generation:
			return
		var boundary_index: int = order[order_index]
		var boundary_x := (targets[boundary_index] + token_nodes[boundary_index].size.x + targets[boundary_index + 1]) * 0.5
		for token_index in token_nodes.size():
			targets[token_index] += -CUT_GAP * 0.5 if token_index <= boundary_index else CUT_GAP * 0.5
		var progress := float(order_index + 1) / float(boundary_count)
		var stage_scale := lerpf(initial_scale, final_scale, progress)
		await animate_boundary_cut(generation, boundary_index, boundary_x, targets, stage_scale, step_duration)
		if generation != play_generation:
			return
	pass


## Top-to-bottom slash: enter from above → hit → exit below while thinning → shorten out.
func animate_boundary_cut(generation: int, boundary_index: int, boundary_x: float, targets: Array[float], stage_scale: float, step_duration: float) -> void:
	var cutter_x := boundary_x - CUTTER_WIDTH * 0.5
	var start_y := -CUTTER_HEIGHT - 6.0
	var hit_y := TOKEN_HEIGHT * 0.42 - CUTTER_HEIGHT * 0.5
	var exit_y := TOKEN_HEIGHT + 10.0
	cutter.position = Vector2(cutter_x, start_y)
	cutter.scale = Vector2(1.0, 1.0)
	cutter.color.a = 0.0
	if cutter_material != null:
		cutter_material.set_shader_parameter("intensity", 0.35)

	# 1) Descend from above into the glyph line.
	var enter_tween := create_tween().set_parallel(true)
	enter_tween.tween_property(cutter, "position:y", hit_y, step_duration * 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	enter_tween.tween_property(cutter, "color:a", 1.0, step_duration * 0.08)
	if cutter_material != null:
		enter_tween.tween_method(func(value: float) -> void: cutter_material.set_shader_parameter("intensity", value), 0.35, 1.4, step_duration * 0.34)
	active_tween = enter_tween
	await enter_tween.finished
	if generation != play_generation:
		return

	spawn_cut_particles(Vector2(boundary_x, TOKEN_HEIGHT * 0.42))
	var row_rest := row.position

	# 2) Keep cutting downward while tokens separate; beam stays bright through the text.
	var exit_tween := create_tween().set_parallel(true)
	for token_index in token_nodes.size():
		exit_tween.tween_property(token_nodes[token_index], "position:x", targets[token_index], step_duration * 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	exit_tween.tween_property(row, "scale", Vector2(stage_scale, stage_scale), step_duration * 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	exit_tween.tween_property(cutter, "position:y", exit_y, step_duration * 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	exit_tween.tween_property(cutter, "scale:x", 0.30, step_duration * 0.28).set_delay(step_duration * 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	exit_tween.tween_method(func(t: float) -> void: apply_cut_shake(row_rest, boundary_index, t), 0.0, 1.0, step_duration * 0.40)
	if cutter_material != null:
		exit_tween.tween_method(func(value: float) -> void: cutter_material.set_shader_parameter("intensity", value), 1.4, 0.85, step_duration * 0.40)
	active_tween = exit_tween
	await exit_tween.finished
	if generation != play_generation:
		return
	if row != null and is_instance_valid(row):
		row.position = row_rest
	reset_token_shake()

	# 3) Below the line: shorten, then fade away.
	var fade_tween := create_tween().set_parallel(true)
	fade_tween.tween_property(cutter, "scale:y", 0.06, step_duration * 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(cutter, "scale:x", 0.08, step_duration * 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(cutter, "color:a", 0.0, step_duration * 0.12).set_delay(step_duration * 0.03)
	if cutter_material != null:
		fade_tween.tween_method(func(value: float) -> void: cutter_material.set_shader_parameter("intensity", value), 0.85, 0.0, step_duration * 0.14)
	active_tween = fade_tween
	await fade_tween.finished
	if cutter != null and is_instance_valid(cutter):
		cutter.color.a = 0.0
		cutter.scale = Vector2(1.0, 1.0)
	if cutter_material != null:
		cutter_material.set_shader_parameter("intensity", 0.0)
	pass


static func left_to_right_boundary_order(boundary_count: int) -> Array[int]:
	var result: Array[int] = []
	for index in boundary_count:
		result.append(index)
	return result


func apply_cut_shake(rest_position: Vector2, boundary_index: int, t: float) -> void:
	if row == null or not is_instance_valid(row):
		return
	# Keep ~screen-pixel amplitude when the fitted row scale is small.
	var screen_amp := CUT_SHAKE_AMPLITUDE / maxf(row.scale.x, 0.25)
	var envelope := exp(-t * 3.4)
	var wave := Vector2(sin(t * TAU * 4.5 + 1.2), cos(t * TAU * 3.6 + 0.4))
	row.position = rest_position + wave * screen_amp * envelope * Vector2(1.0, 0.7)
	for token_index in token_nodes.size():
		var token_node := token_nodes[token_index]
		if token_node == null or not is_instance_valid(token_node):
			continue
		var distance := absf(float(token_index) - (float(boundary_index) + 0.5))
		var falloff := clampf(1.15 - distance * 0.35, 0.15, 1.0)
		var side := -1.0 if token_index <= boundary_index else 1.0
		token_node.position.y = wave.y * screen_amp * 0.9 * envelope * falloff * side
		token_node.rotation = wave.x * 0.018 * envelope * falloff * side
	pass


func reset_token_shake() -> void:
	for token_node in token_nodes:
		if token_node == null or not is_instance_valid(token_node):
			continue
		token_node.position.y = 0.0
		token_node.rotation = 0.0
	pass


func spawn_cut_particles(at_position: Vector2) -> void:
	var accent := ThemeColor.accent_theme_color()
	# Bright sparks at the slit.
	var sparks := make_cut_particles(at_position, 14, 0.42, 70.0, 160.0, 1.2, 2.8)
	sparks.color = Color(1.0, 1.0, 1.0, 0.95)
	var spark_ramp := Gradient.new()
	spark_ramp.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(accent, 0.85), Color(accent, 0.0)])
	spark_ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	sparks.color_ramp = spark_ramp
	row.add_child(sparks)
	sparks.emitting = true
	# Soft floating dust / bokeh matching the cinematic haze.
	var dust := make_cut_particles(at_position, 22, 0.78, 18.0, 58.0, 1.8, 4.5)
	dust.gravity = Vector2(0.0, -12.0)
	dust.damping_min = 1.5
	dust.damping_max = 3.5
	dust.color = Color(accent, 0.75)
	var dust_ramp := Gradient.new()
	dust_ramp.colors = PackedColorArray([Color(accent.lightened(0.45), 0.9), Color(accent, 0.45), Color(accent, 0.0)])
	dust_ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	dust.color_ramp = dust_ramp
	row.add_child(dust)
	dust.emitting = true
	pass


func spawn_ambient_dust() -> void:
	var accent := ThemeColor.accent_theme_color()
	var dust := CPUParticles2D.new()
	dust.position = Vector2(row.size.x * 0.5, TOKEN_HEIGHT * 0.42)
	dust.z_index = 8
	dust.amount = 16
	dust.lifetime = 2.4
	dust.preprocess = 1.2
	dust.emitting = true
	dust.one_shot = false
	dust.explosiveness = 0.0
	dust.randomness = 0.7
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(row.size.x * 0.48, 18.0)
	dust.direction = Vector2(0.0, -1.0)
	dust.spread = 180.0
	dust.gravity = Vector2(0.0, -6.0)
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 16.0
	dust.scale_amount_min = 0.8
	dust.scale_amount_max = 2.0
	dust.color = Color(accent, 0.35)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(accent, 0.0), Color(accent.lightened(0.35), 0.32), Color(accent, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	dust.color_ramp = ramp
	row.add_child(dust)
	pass


func make_cut_particles(at_position: Vector2, amount: int, lifetime: float, speed_min: float, speed_max: float, scale_min: float, scale_max: float) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.position = at_position
	particles.z_index = 11
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 28.0)
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max
	particles.scale_amount_min = scale_min
	particles.scale_amount_max = scale_max
	particles.finished.connect(particles.queue_free)
	return particles


func stop_animation() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = null
	pass


func clear_tokens() -> void:
	token_nodes.clear()
	if row != null and is_instance_valid(row):
		row.queue_free()
	row = null
	cutter = null
	cutter_material = null
	row_haze = null
	haze_material = null
	pass
