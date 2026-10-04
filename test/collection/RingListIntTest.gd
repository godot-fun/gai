## Unit tests for [RingListInt]. Loaded with other scripts in this folder by [code]test/collection/CollectionTest.tscn[/code] ([UnitTest]).

## Fill, overwrite oldest when full, [method RingListInt.remove_latest], and [method RingListInt.clear].
func RingListInt_add_test() -> void:
	var ring := RingListInt.new(3)
	ring.add(1)
	ring.add(2)
	ring.add(3)
	assert(ring.size() == 3)
	assert(ring.is_full())
	assert(ring.to_array() == [1, 2, 3])
	ring.add(4)
	assert(ring.size() == 3)
	assert(ring.to_array() == [2, 3, 4])
	assert(ring.latest() == 4)
	ring.remove_latest()
	assert(ring.size() == 2)
	assert(ring.to_array() == [2, 3])
	assert(ring.latest() == 3)
	ring.clear()
	assert(ring.is_empty())
	assert(ring.to_array() == [])
	pass

## [method RingListInt.remove_value] compacts order; missing values are ignored.
func RingListInt_remove_value_test() -> void:
	var ring := RingListInt.new(8)
	ring.add(1)
	ring.add(2)
	ring.add(3)
	ring.add(4)
	ring.remove_value(2)
	assert(ring.to_array() == [1, 3, 4])
	ring.remove_value(99)
	assert(ring.to_array() == [1, 3, 4])
	ring.remove_value(1)
	assert(ring.to_array() == [3, 4])
	ring.clear()
	assert(ring.is_empty())
	pass
