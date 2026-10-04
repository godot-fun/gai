## Unit tests for [RingListString]. Loaded with other scripts in this folder by [code]test/collection/CollectionTest.tscn[/code] ([UnitTest]).

## Fill, overwrite oldest when full, [method RingListString.remove_latest], and [method RingListString.clear].
func RingListString_add_test() -> void:
	var ring := RingListString.new(3)
	ring.add("a")
	ring.add("b")
	ring.add("c")
	assert(ring.size() == 3)
	assert(ring.is_full())
	assert(ring.to_array() == ["a", "b", "c"])
	ring.add("d")
	assert(ring.size() == 3)
	assert(ring.to_array() == ["b", "c", "d"])
	assert(ring.latest() == "d")
	ring.remove_latest()
	assert(ring.size() == 2)
	assert(ring.to_array() == ["b", "c"])
	assert(ring.latest() == "c")
	ring.clear()
	assert(ring.is_empty())
	assert(ring.to_array() == [])
	pass

## [method RingListString.remove_value] compacts order; missing values are ignored.
func RingListString_remove_value_test() -> void:
	var ring := RingListString.new(8)
	ring.add("one")
	ring.add("two")
	ring.add("three")
	ring.add("four")
	ring.remove_value("two")
	assert(ring.to_array() == ["one", "three", "four"])
	ring.remove_value("missing")
	assert(ring.to_array() == ["one", "three", "four"])
	ring.remove_value("one")
	assert(ring.to_array() == ["three", "four"])
	ring.clear()
	assert(ring.is_empty())
	pass
