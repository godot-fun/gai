class_name TransformerController
extends VisualEffect

## Orchestrates tokenizer, embedding, and attention transformer-stage animations.

## Enables the full completion animation for visual previews and tests. Production stops immediately.
static var complete_animation_on_agent_end: bool = false

var session_id: int = 0
var request_generation: int = 0
var tokenizer: TokenizerEffect
var embedding: EmbeddingEffect
var attention: AttentionEffect
var transformer_block: Control
var logits_burst: Control
var active_tween: Tween
var run_entry_start: int = 0
var pipeline_running: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	tokenizer = TokenizerEffect.new()
	tokenizer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tokenizer)
	embedding = EmbeddingEffect.new()
	embedding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(embedding)
	attention = AttentionEffect.new()
	attention.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	attention.set_embedding_effect(embedding)
	add_child(attention)
	transformer_block = TransformerBlockEffect.new()
	transformer_block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transformer_block.set_embedding_effect(embedding)
	add_child(transformer_block)
	logits_burst = LogitsBurstEffect.new()
	logits_burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logits_burst.set_embedding_effect(embedding)
	add_child(logits_burst)
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.TRANSFORMER


func on_theme_changed() -> void:
	if tokenizer != null:
		tokenizer.on_theme_changed()
	if embedding != null:
		embedding.on_theme_changed()
	if attention != null:
		attention.on_theme_changed()
	if transformer_block != null:
		transformer_block.on_theme_changed()
	if logits_burst != null:
		logits_burst.on_theme_changed()
	pass


func set_visual_visible(show: bool, animated: bool) -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = null
	if show:
		visible = true
		modulate.a = 1.0
		return
	# Soft-hide only — switching chats must not cancel in-flight stages.
	if not animated:
		visible = false
		modulate.a = 1.0
		return
	active_tween = create_tween()
	active_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	active_tween.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
	)
	pass


func reset_visual() -> void:
	request_generation += 1
	cancel_stages()
	modulate = Color.WHITE
	pass


func on_agent_start(value: int) -> void:
	session_id = value
	var session := AgentSessionStore.load_session(value)
	run_entry_start = session.chat_entries.size() if session != null else 0
	var prompt := latest_user_prompt(value)
	if prompt.is_empty():
		return
	request_generation += 1
	var generation := request_generation
	run_transformer(prompt, generation)
	pass


func on_agent_end(error_message: String) -> void:
	if complete_animation_on_agent_end and StringUtils.is_blank(error_message):
		await finish_logits_animation(request_generation)
		return
	request_generation += 1
	cancel_stages()
	pass


func run_transformer(prompt: String, generation: int) -> void:
	pipeline_running = true
	var result := LlamaHelper.TokenizeResult.new()
	if await VLMServer.async_ensure_server_running() == OK:
		result = await LlamaHelper.async_tokenize(VLMServer.server_url(), prompt)
	if generation != request_generation or not is_inside_tree():
		pipeline_running = false
		return
	var selected := TokenizerEffect.select_complete_sentence(result.tokens)
	if selected.is_empty():
		pipeline_running = false
		return
	await tokenizer.play(selected)
	if generation != request_generation or not is_inside_tree():
		pipeline_running = false
		return
	await embedding.play(result.tokens)
	if generation != request_generation or not is_inside_tree():
		pipeline_running = false
		return
	await attention.play(result.tokens)
	if generation != request_generation or not is_inside_tree():
		pipeline_running = false
		return
	await transformer_block.play(result.tokens)
	if generation != request_generation or not is_inside_tree():
		pipeline_running = false
		return
	var thinking_text := collect_run_text(ChatEntry.KIND_THINKING)
	thinking_text = StringUtils.truncate(thinking_text, 1024)
	var low_tokens := await tokenize_text(thinking_text)
	if generation == request_generation and is_inside_tree():
		await logits_burst.collapse_galaxy()
	if generation == request_generation and is_inside_tree():
		logits_burst.play_low_probability(low_tokens)
	pipeline_running = false
	pass


func finish_logits_animation(generation: int) -> void:
	while pipeline_running and generation == request_generation and is_inside_tree():
		await get_tree().process_frame
	if generation != request_generation or not is_inside_tree():
		return
	var final_text := StringUtils.truncate(latest_run_text(ChatEntry.KIND_AGENT), 1024)
	var high_tokens := await tokenize_text(final_text)
	if generation == request_generation and is_inside_tree():
		await logits_burst.play_high_probability(high_tokens)
	pass


func collect_run_text(kind: String) -> String:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return ""
	var builder := StringBuilder.new()
	for index in range(run_entry_start, session.chat_entries.size()):
		var entry: ChatEntry = session.chat_entries[index]
		if entry.kind == kind and StringUtils.is_not_blank(entry.body):
			builder.append_line(entry.body)
	return builder.build_string()


func latest_run_text(kind: String) -> String:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return ""
	for index in range(session.chat_entries.size() - 1, run_entry_start - 1, -1):
		var entry: ChatEntry = session.chat_entries[index]
		if entry.kind == kind and StringUtils.is_not_blank(entry.body):
			return entry.body
	return ""


func tokenize_text(text: String) -> Array[LlamaHelper.Token]:
	if StringUtils.is_blank(text) or await VLMServer.async_ensure_server_running() != OK:
		return []
	var result := await LlamaHelper.async_tokenize(VLMServer.server_url(), text)
	return result.tokens


func latest_user_prompt(value: int) -> String:
	var session := AgentSessionStore.load_session(value)
	if session == null:
		return ""
	for index in range(session.chat_entries.size() - 1, -1, -1):
		var entry: ChatEntry = session.chat_entries[index]
		if entry.kind == ChatEntry.KIND_USER:
			return entry.body
	return ""


func cancel_stages() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = null
	if tokenizer != null:
		tokenizer.cancel()
	if embedding != null:
		embedding.cancel()
	if attention != null:
		attention.cancel()
	if transformer_block != null:
		transformer_block.cancel()
	if logits_burst != null:
		logits_burst.cancel()
	pipeline_running = false
	pass
