func lru_cache_int_evicts_least_recently_used_test() -> void:
	var cache := LruCacheInt.new(2)
	cache.put_if_absent(1, "one")
	cache.put_if_absent(2, "two")
	assert(cache.get_value(1) == "one")
	cache.put_if_absent(3, "three")
	assert(cache.has(1))
	assert(not cache.has(2))
	assert(cache.get_value(3) == "three")
	assert(cache.size() == 2)
	pass


func lru_cache_int_remove_clear_test() -> void:
	var cache := LruCacheInt.new(2)
	assert(cache.put_if_absent(1, "first") == null)
	assert(cache.get_value(99, "fallback") == "fallback")
	assert(cache.remove(1) == "first")
	assert(cache.remove(1) == null)
	cache.put_if_absent(2, 2)
	cache.clear()
	assert(cache.size() == 0)
	cache.put_if_absent(3, 3)
	cache.put_if_absent(4, 4)
	assert(cache.size() == 2)
	assert(cache.has(3))
	assert(cache.has(4))
	pass


func lru_cache_int_capacity_one_test() -> void:
	var cache := LruCacheInt.new(1)
	cache.put_if_absent(1, "first")
	assert(cache.size() == 1)
	cache.put_if_absent(2, "second")
	assert(cache.size() == 1)
	assert(not cache.has(1))
	assert(cache.get_value(2) == "second")
	pass


func lru_cache_int_exact_capacity_does_not_evict_test() -> void:
	var cache := LruCacheInt.new(3)
	cache.put_if_absent(1, 1)
	cache.put_if_absent(2, 2)
	cache.put_if_absent(3, 3)
	assert(cache.size() == 3)
	assert(cache.has(1))
	assert(cache.has(2))
	assert(cache.has(3))
	pass


func lru_cache_int_get_refreshes_recency_test() -> void:
	var cache := LruCacheInt.new(2)
	cache.put_if_absent(1, "one")
	cache.put_if_absent(2, "two")
	assert(cache.get_value(1) == "one")
	cache.put_if_absent(3, "three")
	assert(cache.get_value(1) == "one")
	assert(not cache.has(2))
	assert(cache.has(3))
	pass


func lru_cache_int_missing_get_does_not_change_recency_test() -> void:
	var cache := LruCacheInt.new(2)
	cache.put_if_absent(1, "one")
	cache.put_if_absent(2, "two")
	assert(cache.get_value(99) == null)
	cache.put_if_absent(3, "three")
	assert(not cache.has(1))
	assert(cache.has(2))
	assert(cache.has(3))
	pass


func lru_cache_int_remove_releases_capacity_test() -> void:
	var cache := LruCacheInt.new(2)
	cache.put_if_absent(1, "one")
	cache.put_if_absent(2, "two")
	assert(cache.remove(1) == "one")
	cache.put_if_absent(3, "three")
	assert(cache.size() == 2)
	assert(cache.has(2))
	assert(cache.has(3))
	pass


func lru_cache_int_supports_zero_negative_and_false_value_test() -> void:
	var cache := LruCacheInt.new(3)
	cache.put_if_absent(0, false)
	cache.put_if_absent(-1, "negative")
	assert(cache.has(0))
	assert(cache.get_value(0, "fallback") == false)
	assert(cache.get_value(-1) == "negative")
	pass


func lru_cache_int_has_does_not_refresh_recency_test() -> void:
	var cache := LruCacheInt.new(2)
	cache.put_if_absent(1, "one")
	cache.put_if_absent(2, "two")
	assert(cache.has(1))
	cache.put_if_absent(3, "three")
	assert(not cache.has(1))
	assert(cache.has(2))
	assert(cache.has(3))
	pass


func lru_cache_int_put_if_absent_returns_evicted_entry_test() -> void:
	var cache := LruCacheInt.new(2)
	cache.put_if_absent(1, "one")
	cache.put_if_absent(2, "two")
	var evicted := cache.put_if_absent(3, "three")
	assert(evicted.key == 1)
	assert(evicted.value == "one")
	assert(not cache.has(1))
	pass
