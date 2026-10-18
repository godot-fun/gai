func pair_int_keeps_key_and_value_test() -> void:
	var pair := PairInt.new(-1, "value")
	assert(pair.key == -1)
	assert(pair.value == "value")
	pass


func pair_string_keeps_key_and_value_test() -> void:
	var pair := PairString.new("key", false)
	assert(pair.key == "key")
	assert(pair.value == false)
	pass
