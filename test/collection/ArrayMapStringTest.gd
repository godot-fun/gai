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
	assert(map.key_at(0) == "title")
	assert(map.value_at(0) == "Hello")
	assert(map.key_at(1) == "prompt")
	assert(map.value_at(1) == "Explain this")
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


func ArrayMapString_empty_strings_test() -> void:
	var map := ArrayMapString.new()
	map.put("", "empty key")
	map.put("empty value", "")
	assert(map.size() == 2)
	assert(map.has(""))
	assert(map.get_value("") == "empty key")
	assert(map.has("empty value"))
	assert(map.get_value("empty value", "fallback") == "")
	assert(map.keys() == PackedStringArray(["", "empty value"]))
	assert(map.values() == PackedStringArray(["empty key", ""]))
	pass


func ArrayMapString_remove_positions_test() -> void:
	var map := ArrayMapString.new()
	map.put("first", "1")
	map.put("middle", "2")
	map.put("last", "3")
	assert(map.remove("middle") == "2")
	assert(map.keys() == PackedStringArray(["first", "last"]))
	assert(map.values() == PackedStringArray(["1", "3"]))
	assert(map.remove("first") == "1")
	assert(map.remove("last") == "3")
	assert(map.is_empty())
	assert(map.keys().is_empty())
	assert(map.values().is_empty())
	pass


func ArrayMapString_insertion_order_test() -> void:
	var map := ArrayMapString.new()
	map.put("a", "1")
	map.put("b", "2")
	map.put("c", "3")
	map.put("b", "updated")
	assert(map.keys() == PackedStringArray(["a", "b", "c"]))
	assert(map.values() == PackedStringArray(["1", "updated", "3"]))
	map.remove("b")
	map.put("b", "reinserted")
	assert(map.keys() == PackedStringArray(["a", "c", "b"]))
	assert(map.values() == PackedStringArray(["1", "3", "reinserted"]))
	pass


func ArrayMapString_snapshots_are_independent_test() -> void:
	var map := ArrayMapString.new()
	map.put("a", "1")
	var keys := map.keys()
	var values := map.values()
	keys[0] = "changed"
	values[0] = "changed"
	assert(map.keys() == PackedStringArray(["a"]))
	assert(map.values() == PackedStringArray(["1"]))
	pass


func ArrayMapString_clear_and_reuse_test() -> void:
	var map := ArrayMapString.new()
	map.put("old", "value")
	map.clear()
	assert(map.size() == 0)
	assert(not map.has("old"))
	assert(map.get_value("old", "missing") == "missing")
	map.put("new", "value")
	assert(map.size() == 1)
	assert(map.get_value("new") == "value")
	assert(map.keys() == PackedStringArray(["new"]))
	pass
