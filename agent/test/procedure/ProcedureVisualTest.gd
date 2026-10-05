extends Node

const TOKENIZER := preload("res://agent/ui/visuals/procedure/TokenizerEffect.gd")


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


func cut_order_runs_left_to_right_test() -> void:
	assert(TOKENIZER.left_to_right_boundary_order(5) == [0, 1, 2, 3, 4])
	assert(TOKENIZER.left_to_right_boundary_order(4) == [0, 1, 2, 3])
	pass
