## Unit tests for [ArrayMapString]. Loaded by [code]test/collection/CollectionTest.tscn[/code] ([UnitTest]).

func ArrayMapString_put_and_get_test() -> void:
	var map := ArrayMapString.new()
	assert(map.is_empty())
	assert(map.put("title", "Hello") == "")
	assert(map.put("prompt", "Explain this") == "")
	assert(map.size() == 2)
	assert(map.has("title"))
	assert(map.get_value("title") == "Hello")
	assert(map.get_value("missing", "fallback") == "fallback")
	assert(map.keys() == PackedStringArray(["title", "prompt"]))
	assert(map.values() == PackedStringArray(["Hello", "Explain this"]))
	pass


func ArrayMapString_replace_and_remove_test() -> void:
	var map := ArrayMapString.new()
	map.put("first", "one")
	map.put("second", "two")
	assert(map.put("first", "updated") == "one")
	assert(map.size() == 2)
	assert(map.keys() == PackedStringArray(["first", "second"]))
	assert(map.remove("first") == "updated")
	assert(not map.has("first"))
	assert(map.remove("missing", "fallback") == "fallback")
	assert(map.keys() == PackedStringArray(["second"]))
	map.clear()
	assert(map.is_empty())
	pass
