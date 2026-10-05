class_name ProcedureController
extends VisualEffect

## Orchestrates procedure-stage animations (tokenizer first; embedding and others later).

var session_id: int = 0
var request_generation: int = 0
var tokenizer: TokenizerEffect
var active_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	tokenizer = TokenizerEffect.new()
	tokenizer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tokenizer)
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.PROCEDURE


func on_theme_changed() -> void:
	if tokenizer != null:
		tokenizer.on_theme_changed()
	pass


func set_visual_visible(show: bool, animated: bool) -> void:
	if show:
		visible = true
		modulate.a = 1.0
		return
	request_generation += 1
	cancel_stages()
	if not animated:
		visible = false
		return
	active_tween = create_tween()
	active_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	active_tween.tween_callback(func() -> void: visible = false)
	pass


func reset_visual() -> void:
	request_generation += 1
	cancel_stages()
	modulate = Color.WHITE
	pass


func on_agent_start(value: int) -> void:
	session_id = value
	var prompt := latest_user_prompt(value)
	if prompt.is_empty():
		return
	request_generation += 1
	var generation := request_generation
	run_procedure(prompt, generation)
	pass


func run_procedure(prompt: String, generation: int) -> void:
	var result := LlamaHelper.TokenizeResult.new()
	if await VLMServer.async_ensure_server_running() == OK:
		result = await LlamaHelper.async_tokenize(VLMServer.server_url(), prompt)
	if generation != request_generation or not is_inside_tree():
		return
	var selected := TokenizerEffect.select_complete_sentence(result.tokens)
	if selected.is_empty():
		return
	await tokenizer.play(selected)
	# Later stages (e.g. EmbeddingEffect) chain here after tokenizer finishes.
	pass


## Plays supplied tokens without a server request; intended for the visual preview scene.
## TokenizerEffect only animates a complete sentence slice (~12); full list is kept for later stages.
func play_preview(tokens: Array[LlamaHelper.Token]) -> void:
	reset_visual()
	visible = true
	modulate = Color.WHITE
	request_generation += 1
	var selected := TokenizerEffect.select_complete_sentence(tokens)
	if selected.is_empty():
		return
	await tokenizer.play(selected)
	# Later stages (e.g. EmbeddingEffect) can use the full `tokens` list here.
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


func cancel_stages() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = null
	if tokenizer != null:
		tokenizer.cancel()
	pass
