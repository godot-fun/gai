const THREAD_COUNT: int = 8
const ITEMS_PER_THREAD: int = 1000

var concurrent_map: ConcurrentMapInt


func concurrent_map_basic_operations_test() -> void:
	var map := ConcurrentMapInt.new()
	assert(map.is_empty())
	assert(map.put(1, "first") == null)
	assert(map.put(1, "second") == "first")
	assert(map.get_value(1) == "second")
	assert(map.get_value(99, "fallback") == "fallback")
	assert(map.has(1))
	assert(map.size() == 1)
	assert(map.remove(1) == "second")
	assert(map.remove(1) == null)
	assert(map.is_empty())
	pass


func concurrent_map_put_if_absent_test() -> void:
	var map := ConcurrentMapInt.new()
	assert(map.put_if_absent(7, "first") == null)
	assert(map.put_if_absent(7, "ignored") == "first")
	assert(map.get_value(7) == "first")
	assert(map.size() == 1)
	pass


func concurrent_map_supports_false_value_test() -> void:
	var map := ConcurrentMapInt.new()
	map.put(3, false)
	assert(map.has(3))
	assert(map.get_value(3, "fallback") == false)
	assert(map.put_if_absent(3, "ignored") == false)
	assert(map.has(3))
	assert(map.get_value(3) == false)
	pass


func concurrent_map_returns_collection_snapshots_test() -> void:
	var map := ConcurrentMapInt.new()
	map.put(1, "one")
	map.put(2, "two")
	var map_keys := map.keys()
	var map_values := map.values()
	var copied_map := map.snapshot()
	map_keys.clear()
	map_values.clear()
	copied_map.clear()
	assert(map.size() == 2)
	assert(map.get_value(1) == "one")
	assert(map.get_value(2) == "two")
	map.clear()
	assert(map.is_empty())
	pass


func concurrent_map_parallel_access_test() -> void:
	concurrent_map = ConcurrentMapInt.new()
	var threads: Array[Thread] = []
	for worker_index in THREAD_COUNT:
		var thread := Thread.new()
		assert(thread.start(Callable(self, "parallel_put_worker").bind(worker_index)) == OK)
		threads.append(thread)
	wait_for_threads(threads)
	assert(concurrent_map.size() == THREAD_COUNT * ITEMS_PER_THREAD)
	for key in THREAD_COUNT * ITEMS_PER_THREAD:
		assert(concurrent_map.get_value(key) == key)

	threads.clear()
	for worker_index in THREAD_COUNT:
		var thread := Thread.new()
		assert(thread.start(Callable(self, "parallel_remove_worker").bind(worker_index)) == OK)
		threads.append(thread)
	wait_for_threads(threads)
	assert(concurrent_map.size() == THREAD_COUNT * ITEMS_PER_THREAD / 2)
	for key in THREAD_COUNT * ITEMS_PER_THREAD:
		assert(concurrent_map.has(key) == (key % 2 == 1))
	pass


func parallel_put_worker(worker_index: int) -> void:
	var first_key := worker_index * ITEMS_PER_THREAD
	for offset in ITEMS_PER_THREAD:
		var key := first_key + offset
		concurrent_map.put(key, key)
		assert(concurrent_map.get_value(key) == key)
	pass


func parallel_remove_worker(worker_index: int) -> void:
	var first_key := worker_index * ITEMS_PER_THREAD
	for offset in ITEMS_PER_THREAD:
		var key := first_key + offset
		if key % 2 == 0:
			assert(concurrent_map.remove(key) == key)
	pass


func wait_for_threads(threads: Array[Thread]) -> void:
	for thread in threads:
		thread.wait_to_finish()
	pass
