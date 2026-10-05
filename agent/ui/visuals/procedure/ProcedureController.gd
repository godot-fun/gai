class_name ProcedureController
extends VisualEffect

## Visualizes the first complete >= 12-token sentence as a staged tokenizer procedure.

const MIN_TOKEN_COUNT := 12
const TOKEN_FONT_SIZE := 34
const TOKEN_HEIGHT := 86.0
const TOKEN_MIN_WIDTH := 12.0
const TOKEN_HORIZONTAL_PADDING := 0.0
const CUT_GAP := 30.0
const ROW_SCREEN_MARGIN := 48.0

## Total duration of each major animation stage.
var train_arrival_duration := 1.35
var token_cut_duration := 2.4
var token_reveal_duration := 1.8

var session_id: int = 0
var request_generation: int = 0
var row: Control
var token_nodes: Array[ProcedureTokenNode] = []
var cutter: ColorRect
var active_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.PROCEDURE


func on_theme_changed() -> void:
	for token_node in token_nodes:
		token_node.refresh_theme()
	pass


func set_visual_visible(show: bool, animated: bool) -> void:
	if show:
		visible = true
		modulate.a = 1.0
		return
	request_generation += 1
	stop_animation()
	if not animated:
		visible = false
		return
	active_tween = create_tween()
	active_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	active_tween.tween_callback(func() -> void: visible = false)
	pass


func reset_visual() -> void:
	request_generation += 1
	stop_animation()
	clear_tokens()
	modulate = Color.WHITE
	pass


func on_agent_start(value: int) -> void:
	session_id = value
	var prompt := latest_user_prompt(value)
	if prompt.is_empty():
		return
	request_generation += 1
	var generation := request_generation
	run_tokenization(prompt, generation)
	pass


func run_tokenization(prompt: String, generation: int) -> void:
	var result := LlamaHelper.TokenizeResult.new()
	if await VLMServer.async_ensure_server_running() == OK:
		result = await LlamaHelper.async_tokenize(VLMServer.server_url(), prompt)
	if generation != request_generation or not is_inside_tree():
		return
	var selected := select_complete_sentence(result.tokens)
	if selected.is_empty():
		return
	build_tokens(selected)
	await animate_procedure(generation)
	pass


## Plays supplied tokens without a server request; intended for the visual preview scene.
func play_preview(tokens: Array[LlamaHelper.Token]) -> void:
	reset_visual()
	visible = true
	modulate = Color.WHITE
	request_generation += 1
	var generation := request_generation
	build_tokens(tokens)
	await animate_procedure(generation)
	pass


func latest_user_prompt(value: int) -> String:
	var session := AgentSessionStore.load_session(value)
	if session == null:
		return ""
	for index in range(session.chat_entries.size() - 1, -1, -1):
		var entry: ChatEntry = session.chat_entries[index]
		if entry.kind == ChatEntry.KIND_USER:
			return entry.body
	return ""


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
	var font := Fonts.bold()
	var x := 0.0
	for token in tokens:
		var display := ProcedureTokenNode.display_piece(token.piece)
		var width := maxf(TOKEN_MIN_WIDTH, font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, TOKEN_FONT_SIZE).x + TOKEN_HORIZONTAL_PADDING)
		var token_node := ProcedureTokenNode.new()
		token_node.setup(token, Vector2(width, TOKEN_HEIGHT))
		token_node.position = Vector2(x, 0.0)
		row.add_child(token_node)
		token_nodes.append(token_node)
		x += width
	row.size = Vector2(x, TOKEN_HEIGHT)
	row.pivot_offset = row.size * 0.5
	cutter = ColorRect.new()
	cutter.color = Color(0.86, 0.95, 1.0, 0.0)
	cutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cutter.position = Vector2(-2.0, -8.0)
	cutter.size = Vector2(3.0, TOKEN_HEIGHT + 16.0)
	cutter.pivot_offset = cutter.size * 0.5
	cutter.rotation = 0.25
	cutter.z_index = 10
	row.add_child(cutter)
	var available_width := maxf(1.0, size.x - ROW_SCREEN_MARGIN * 2.0)
	var fit_scale := minf(1.0, available_width / row.size.x)
	row.scale = Vector2(fit_scale, fit_scale)
	row.position = Vector2(size.x + ROW_SCREEN_MARGIN, (size.y - TOKEN_HEIGHT * fit_scale) * 0.5)
	pass


func animate_procedure(generation: int) -> void:
	var scaled_width := row.size.x * row.scale.x
	var centered_x := (size.x - scaled_width) * 0.5
	active_tween = create_tween()
	active_tween.tween_property(row, "position:x", centered_x, train_arrival_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await active_tween.finished
	if generation != request_generation:
		return

	await animate_cut_stage(generation)
	if generation != request_generation:
		return

	var reveal_tween := create_tween()
	var step_duration := token_reveal_duration / float(maxi(1, token_nodes.size()))
	for token_node in token_nodes:
		reveal_tween.tween_callback(reveal_token.bind(token_node))
		reveal_tween.tween_property(token_node, "scale", Vector2.ONE, step_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween = reveal_tween
	await reveal_tween.finished
	pass


func reveal_token(token_node: ProcedureTokenNode) -> void:
	token_node.set_revealed(true)
	token_node.scale = Vector2(0.92, 0.92)
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
	var step_duration := token_cut_duration / float(boundary_count)
	var targets: Array[float] = []
	for token_node in token_nodes:
		targets.append(token_node.position.x)
	var order := left_to_right_boundary_order(boundary_count)
	cutter.color.a = 0.0
	for order_index in order.size():
		if generation != request_generation:
			return
		var boundary_index: int = order[order_index]
		var boundary_x := (targets[boundary_index] + token_nodes[boundary_index].size.x + targets[boundary_index + 1]) * 0.5
		# Each boundary gets a discrete vertical strike. Never slide the blade horizontally
		# between boundaries, otherwise several cuts read as one continuous scanner sweep.
		cutter.position = Vector2(boundary_x + 20.0, -TOKEN_HEIGHT * 0.52)
		cutter.scale = Vector2(1.35, 0.72)
		cutter.color.a = 0.0
		var strike_tween := create_tween().set_parallel(true)
		strike_tween.tween_property(cutter, "position:x", boundary_x, step_duration * 0.34).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		strike_tween.tween_property(cutter, "position:y", -8.0, step_duration * 0.34).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		strike_tween.tween_property(cutter, "scale", Vector2(2.5, 1.18), step_duration * 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		strike_tween.tween_property(cutter, "color:a", 1.0, step_duration * 0.16)
		active_tween = strike_tween
		await strike_tween.finished
		if generation != request_generation:
			return
		spawn_cut_particles(Vector2(boundary_x, TOKEN_HEIGHT * 0.42))
		cutter.scale = Vector2(2.6, 1.22)
		for token_index in token_nodes.size():
			targets[token_index] += -CUT_GAP * 0.5 if token_index <= boundary_index else CUT_GAP * 0.5
		var separation_tween := create_tween().set_parallel(true)
		for token_index in token_nodes.size():
			separation_tween.tween_property(token_nodes[token_index], "position:x", targets[token_index], step_duration * 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var progress := float(order_index + 1) / float(boundary_count)
		var stage_scale := lerpf(initial_scale, final_scale, progress)
		separation_tween.tween_property(row, "scale", Vector2(stage_scale, stage_scale), step_duration * 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		separation_tween.tween_property(cutter, "color:a", 0.0, step_duration * 0.30).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		separation_tween.tween_property(cutter, "scale", Vector2(3.2, 1.28), step_duration * 0.30)
		active_tween = separation_tween
		await separation_tween.finished
		var pause_tween := create_tween()
		pause_tween.tween_interval(step_duration * 0.14)
		active_tween = pause_tween
		await pause_tween.finished
	pass


static func left_to_right_boundary_order(boundary_count: int) -> Array[int]:
	var result: Array[int] = []
	for index in boundary_count:
		result.append(index)
	return result


func spawn_cut_particles(at_position: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.position = at_position
	particles.amount = 18
	particles.lifetime = 0.38
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.RIGHT
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 65.0)
	particles.initial_velocity_min = 55.0
	particles.initial_velocity_max = 145.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.6
	particles.color = ThemeColor.accent_theme_color()
	particles.finished.connect(particles.queue_free)
	row.add_child(particles)
	particles.emitting = true
	pass


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
	pass
