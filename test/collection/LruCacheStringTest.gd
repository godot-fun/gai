func lru_cache_string_evicts_least_recently_used_test() -> void:
	var cache := LruCacheString.new(2)
	cache.put("a", 1)
	cache.put("b", 2)
	assert(cache.get_value("a") == 1)
	cache.put("c", 3)
	assert(cache.has("a"))
	assert(not cache.has("b"))
	assert(cache.get_value("c") == 3)
	assert(cache.size() == 2)
	pass


func lru_cache_string_replace_remove_clear_test() -> void:
	var cache := LruCacheString.new(2)
	assert(cache.put("a", "first") == null)
	assert(cache.put("a", "second") == "first")
	assert(cache.get_value("missing", "fallback") == "fallback")
	assert(cache.remove("a") == "second")
	assert(cache.remove("a") == null)
	cache.put("b", 2)
	cache.clear()
	assert(cache.size() == 0)
	cache.put("c", 3)
	cache.put("d", 4)
	assert(cache.size() == 2)
	assert(cache.has("c"))
	assert(cache.has("d"))
	pass


func lru_cache_string_capacity_one_test() -> void:
	var cache := LruCacheString.new(1)
	cache.put("first", 1)
	assert(cache.size() == 1)
	cache.put("second", 2)
	assert(cache.size() == 1)
	assert(not cache.has("first"))
	assert(cache.get_value("second") == 2)
	pass


func lru_cache_string_exact_capacity_does_not_evict_test() -> void:
	var cache := LruCacheString.new(3)
	cache.put("a", 1)
	cache.put("b", 2)
	cache.put("c", 3)
	assert(cache.size() == 3)
	assert(cache.has("a"))
	assert(cache.has("b"))
	assert(cache.has("c"))
	pass


func lru_cache_string_replace_refreshes_recency_test() -> void:
	var cache := LruCacheString.new(2)
	cache.put("a", 1)
	cache.put("b", 2)
	assert(cache.put("a", 10) == 1)
	cache.put("c", 3)
	assert(cache.get_value("a") == 10)
	assert(not cache.has("b"))
	assert(cache.has("c"))
	pass


func lru_cache_string_missing_get_does_not_change_recency_test() -> void:
	var cache := LruCacheString.new(2)
	cache.put("a", 1)
	cache.put("b", 2)
	assert(cache.get_value("missing") == null)
	cache.put("c", 3)
	assert(not cache.has("a"))
	assert(cache.has("b"))
	assert(cache.has("c"))
	pass


func lru_cache_string_remove_releases_capacity_test() -> void:
	var cache := LruCacheString.new(2)
	cache.put("a", 1)
	cache.put("b", 2)
	assert(cache.remove("a") == 1)
	cache.put("c", 3)
	assert(cache.size() == 2)
	assert(cache.has("b"))
	assert(cache.has("c"))
	pass


func lru_cache_string_supports_empty_key_and_null_value_test() -> void:
	var cache := LruCacheString.new(2)
	cache.put("", null)
	assert(cache.has(""))
	assert(cache.get_value("", "fallback") == null)
	assert(cache.put("", "value") == null)
	assert(cache.get_value("") == "value")
	pass
