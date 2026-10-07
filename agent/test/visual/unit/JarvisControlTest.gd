extends RefCounted


func take_sentence_test() -> void:
	var first := VisualChatSentenceCursor.take_sentence("第一句。第二句还没结束", 0)
	assert(first.text == "第一句。")
	assert(first.next_index == 4)
	var tail := VisualChatSentenceCursor.take_sentence("第一句。第二句还没结束", first.next_index)
	assert(tail.text.is_empty())
	assert(tail.next_index == first.next_index)
	pass


func take_sentences_by_index_test() -> void:
	var text := "Hello! How are you?"
	var first := VisualChatSentenceCursor.take_sentence(text, 0)
	var second := VisualChatSentenceCursor.take_sentence(text, first.next_index)
	assert(first.text == "Hello!")
	assert(second.text == "How are you?")
	assert(second.next_index == text.length())
	pass


func comma_is_not_a_complete_sentence_test() -> void:
	var sentence := VisualChatSentenceCursor.take_sentence("还在继续，尚未结束", 0)
	assert(sentence.text.is_empty())
	assert(sentence.next_index == 0)
	pass
