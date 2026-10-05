extends Node


func complete_sentence_after_minimum_test() -> void:
	var tokens: Array[LlamaHelper.Token] = []
	for index in 14:
		var piece := "early." if index == 5 else ("done。" if index == 12 else str(index))
		tokens.append(LlamaHelper.Token.new(index, piece))
	var selected: Array[LlamaHelper.Token] = TokenizerEffect.select_complete_sentence(tokens)
	assert(selected.size() == 13)
	assert(selected[-1].piece == "done。")
	pass


func complete_sentence_with_closing_quote_test() -> void:
	var tokens: Array[LlamaHelper.Token] = []
	for index in 12:
		tokens.append(LlamaHelper.Token.new(index, "完成。”" if index == 11 else str(index)))
	assert(TokenizerEffect.select_complete_sentence(tokens).size() == 12)
	pass


func incomplete_sentence_uses_all_tokens_test() -> void:
	var tokens: Array[LlamaHelper.Token] = []
	for index in 15:
		tokens.append(LlamaHelper.Token.new(index, str(index)))
	assert(TokenizerEffect.select_complete_sentence(tokens).size() == 15)
	pass


func token_color_is_stable_and_id_specific_test() -> void:
	var first := TransformerTokenNode.color_from_token_id(97571)
	assert(first == TransformerTokenNode.color_from_token_id(97571))
	assert(first != TransformerTokenNode.color_from_token_id(14594))
	pass


func EmbeddingEffect_position_matches_token_color_rgb_test() -> void:
	var color := TransformerTokenNode.color_from_token_id(97571)
	var position: Vector3 = EmbeddingEffect.position_from_token_id(97571)
	assert(position == EmbeddingEffect.position_from_color(color))
	assert(is_equal_approx(position.x, (color.r - 0.5) * EmbeddingEffect.SPACE_SCALE))
	assert(is_equal_approx(position.y, (color.g - 0.5) * EmbeddingEffect.SPACE_SCALE))
	assert(is_equal_approx(position.z, (color.b - 0.5) * EmbeddingEffect.SPACE_SCALE))
	assert(position != EmbeddingEffect.position_from_token_id(14594))
	var roundtrip := EmbeddingEffect.color_from_position(position)
	assert(is_equal_approx(roundtrip.r, color.r))
	assert(is_equal_approx(roundtrip.g, color.g))
	assert(is_equal_approx(roundtrip.b, color.b))
	pass


func AttentionEffect_connection_color_is_endpoint_average_test() -> void:
	var average: Color = AttentionEffect.average_color(Color(0.2, 0.4, 0.8, 0.6), Color(0.8, 0.2, 0.4, 1.0))
	assert(average.is_equal_approx(Color(0.5, 0.3, 0.6, 0.8)))
	pass


func token_color_fills_rgb_cube_not_hue_ring_test() -> void:
	var saturations: Dictionary = {}
	var values: Dictionary = {}
	for token_id in [10001, 10002, 48113, 73642, 97571]:
		var color := TransformerTokenNode.color_from_token_id(token_id)
		assert(color.r >= 0.0 and color.r <= 1.0)
		assert(color.g >= 0.0 and color.g <= 1.0)
		assert(color.b >= 0.0 and color.b <= 1.0)
		saturations[snappedf(color.s, 0.01)] = true
		values[snappedf(color.v, 0.01)] = true
	# Old HSV mapping locked S=0.58 and V=1.0; cube mapping must vary both.
	assert(saturations.size() > 1)
	assert(values.size() > 1)
	pass
