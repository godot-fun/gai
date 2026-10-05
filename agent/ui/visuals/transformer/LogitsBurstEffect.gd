class_name LogitsBurstEffect
extends Control

## Keeps low-probability thinking tokens streaming away from the output head, then
## replaces them with a short, brighter burst made from the final answer tokens.

const LOW_INTERVAL := 0.11
const LOW_DURATION := 2.4
const HIGH_TOKEN_LIMIT := 24

var play_generation: int = 0
var emitting_low: bool = false
var low_tokens: Array[LlamaHelper.Token] = []
var low_index: int = 0
var low_elapsed: float = 0.0
var embedding: EmbeddingEffect
var burst_layer: Node3D
var stage_tweens: Array[Tween] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	pass


func _process(delta: float) -> void:
	if not emitting_low or low_tokens.is_empty() or not ensure_layer():
		return
	low_elapsed += delta
	while low_elapsed >= LOW_INTERVAL:
		low_elapsed -= LOW_INTERVAL
		spawn_low_token(low_tokens[low_index % low_tokens.size()], low_index)
		low_index += 1
	pass


func set_embedding_effect(value: EmbeddingEffect) -> void:
	embedding = value
	pass


func on_theme_changed() -> void:
	pass


func play_low_probability(tokens: Array[LlamaHelper.Token]) -> void:
	low_tokens = tokens
	low_index = 0
	low_elapsed = LOW_INTERVAL
	emitting_low = not tokens.is_empty()
	pass


func play_high_probability(tokens: Array[LlamaHelper.Token]) -> void:
	emitting_low = false
	play_generation += 1
	var generation := play_generation
	if not ensure_layer():
		return
	if tokens.is_empty():
		await fade_existing(0.35)
		return
	await fade_existing(0.28)
	var count := mini(tokens.size(), HIGH_TOKEN_LIMIT)
	for index in count:
		spawn_high_token(tokens[index], index, count, generation)
		await get_tree().create_timer(0.045).timeout
	await get_tree().create_timer(1.65).timeout
	if generation == play_generation:
		await fade_existing(0.55)
	pass


func cancel() -> void:
	play_generation += 1
	emitting_low = false
	low_tokens.clear()
	for tween in stage_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	stage_tweens.clear()
	clear_layer()
	pass


func ensure_layer() -> bool:
	if embedding == null or not is_instance_valid(embedding) or embedding.sub_viewport == null:
		return false
	if burst_layer == null or not is_instance_valid(burst_layer):
		burst_layer = Node3D.new()
		burst_layer.name = "LogitsBurstLayer"
		embedding.sub_viewport.add_child(burst_layer)
	return true


func spawn_low_token(token: LlamaHelper.Token, sequence: int) -> void:
	var color := TransformerTokenNode.neon_display_color(TransformerTokenNode.color_from_token_id(token.id))
	var label := embedding.make_token_label(TransformerTokenNode.display_piece(token.piece), color)
	burst_layer.add_child(label)
	label.position = Vector3.ZERO
	label.scale = Vector3.ONE * 0.32
	label.modulate.a = 0.42
	var direction := direction_for(token.id, sequence)
	var distance := 4.4 + float(abs(token.id) % 17) * 0.08
	var tween := remember_tween(create_tween().set_parallel(true))
	tween.tween_property(label, "position", direction * distance, LOW_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE * 0.7, LOW_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, LOW_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)
	pass


func spawn_high_token(token: LlamaHelper.Token, index: int, count: int, generation: int) -> void:
	if generation != play_generation:
		return
	var color := TransformerTokenNode.neon_display_color(TransformerTokenNode.color_from_token_id(token.id))
	var label := embedding.make_token_label(TransformerTokenNode.display_piece(token.piece), color)
	burst_layer.add_child(label)
	label.position = Vector3.ZERO
	label.scale = Vector3.ONE * 0.15
	var rank := 1.0 - float(index) / float(maxi(1, count - 1))
	var distance := lerpf(3.5, 1.15, rank)
	var target := direction_for(token.id, index) * distance
	var target_scale := lerpf(0.72, 1.65, rank)
	var tween := remember_tween(create_tween().set_parallel(true))
	tween.tween_property(label, "position", target, 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE * target_scale, 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color(1.25, 1.25, 1.25, 1.0), 0.25)
	pass


func direction_for(token_id: int, sequence: int) -> Vector3:
	var angle := fposmod(float(token_id * 37 + sequence * 83), 360.0) * PI / 180.0
	var height := sin(float(token_id * 17 + sequence * 29)) * 0.58
	return Vector3(cos(angle), height, sin(angle)).normalized()


func fade_existing(duration: float) -> void:
	if burst_layer == null or not is_instance_valid(burst_layer):
		return
	var children := burst_layer.get_children()
	if children.is_empty():
		return
	var tween := remember_tween(create_tween().set_parallel(true))
	for child: Node in children:
		var label := child as Label3D
		if label != null:
			tween.tween_property(label, "modulate:a", 0.0, duration)
	await tween.finished
	for child: Node in children:
		if is_instance_valid(child):
			child.queue_free()
	pass


func remember_tween(tween: Tween) -> Tween:
	stage_tweens.append(tween)
	return tween


func clear_layer() -> void:
	if burst_layer == null or not is_instance_valid(burst_layer):
		return
	for child in burst_layer.get_children():
		child.queue_free()
	pass
