extends Node

const TOKENIZER := preload("res://agent/ui/visuals/procedure/TokenizerEffect.gd")
const EMBEDDING := preload("res://agent/ui/visuals/procedure/EmbeddingEffect.gd")


func complete_sentence_after_minimum_test() -> void:
	var tokens: Array[LlamaHelper.Token] = []
	for index in 14:
		var piece := "early." if index == 5 else ("done。" if index == 12 else str(index))
		tokens.append(LlamaHelper.Token.new(index, piece))
	var selected: Array[LlamaHelper.Token] = TOKENIZER.select_complete_sentence(tokens)
	assert(selected.size() == 13)
	assert(selected[-1].piece == "done。")
	pass


func complete_sentence_with_closing_quote_test() -> void:
	var tokens: Array[LlamaHelper.Token] = []
	for index in 12:
		tokens.append(LlamaHelper.Token.new(index, "完成。”" if index == 11 else str(index)))
	assert(TOKENIZER.select_complete_sentence(tokens).size() == 12)
	pass


func incomplete_sentence_uses_all_tokens_test() -> void:
	var tokens: Array[LlamaHelper.Token] = []
	for index in 15:
		tokens.append(LlamaHelper.Token.new(index, str(index)))
	assert(TOKENIZER.select_complete_sentence(tokens).size() == 15)
	pass


func token_color_is_stable_and_id_specific_test() -> void:
	var first := ProcedureTokenNode.color_from_token_id(97571)
	assert(first == ProcedureTokenNode.color_from_token_id(97571))
	assert(first != ProcedureTokenNode.color_from_token_id(14594))
	pass


func embedding_position_matches_token_color_rgb_test() -> void:
	var color := ProcedureTokenNode.color_from_token_id(97571)
	var position: Vector3 = EMBEDDING.position_from_token_id(97571)
	assert(position == EMBEDDING.position_from_color(color))
	assert(is_equal_approx(position.x, (color.r - 0.5) * EMBEDDING.SPACE_SCALE))
	assert(is_equal_approx(position.y, (color.g - 0.5) * EMBEDDING.SPACE_SCALE))
	assert(is_equal_approx(position.z, (color.b - 0.5) * EMBEDDING.SPACE_SCALE))
	assert(position != EMBEDDING.position_from_token_id(14594))
	pass


func token_color_fills_rgb_cube_not_hue_ring_test() -> void:
	var saturations: Dictionary = {}
	var values: Dictionary = {}
	for token_id in [10001, 10002, 48113, 73642, 97571]:
		var color := ProcedureTokenNode.color_from_token_id(token_id)
		assert(color.r >= 0.0 and color.r <= 1.0)
		assert(color.g >= 0.0 and color.g <= 1.0)
		assert(color.b >= 0.0 and color.b <= 1.0)
		saturations[snappedf(color.s, 0.01)] = true
		values[snappedf(color.v, 0.01)] = true
	# Old HSV mapping locked S=0.58 and V=1.0; cube mapping must vary both.
	assert(saturations.size() > 1)
	assert(values.size() > 1)
	pass

