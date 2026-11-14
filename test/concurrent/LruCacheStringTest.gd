const THREAD_COUNT: int = 8
const ITEMS_PER_THREAD: int = 500
## Keys every worker races on, so the same cache entries are built from several threads.
const SHARED_KEY_COUNT: int = 64

## Shared by the parallel workers, the way a real caller shares one cache with the worker pool.
var shared_cache: LruCacheString


func lru_cache_string_evicts_least_recently_used_test() -> void:
	var cache := LruCacheString.new(2)
	cache.put_if_absent("a", 1)
	cache.put_if_absent("b", 2)
	assert(cache.get_value("a") == 1)
	cache.put_if_absent("c", 3)
	assert(cache.has("a"))
	assert(not cache.has("b"))
	assert(cache.get_value("c") == 3)
	assert(cache.size() == 2)
	pass


func lru_cache_string_remove_clear_test() -> void:
	var cache := LruCacheString.new(2)
	assert(cache.put_if_absent("a", "first") == null)
	assert(cache.get_value("missing", "fallback") == "fallback")
	assert(cache.remove("a") == "first")
	assert(cache.remove("a") == null)
	cache.put_if_absent("b", 2)
	cache.clear()
	assert(cache.size() == 0)
	cache.put_if_absent("c", 3)
	cache.put_if_absent("d", 4)
	assert(cache.size() == 2)
	assert(cache.has("c"))
	assert(cache.has("d"))
	pass


func lru_cache_string_capacity_one_test() -> void:
	var cache := LruCacheString.new(1)
	cache.put_if_absent("first", 1)
	assert(cache.size() == 1)
	cache.put_if_absent("second", 2)
	assert(cache.size() == 1)
	assert(not cache.has("first"))
	assert(cache.get_value("second") == 2)
	pass


func lru_cache_string_exact_capacity_does_not_evict_test() -> void:
	var cache := LruCacheString.new(3)
	cache.put_if_absent("a", 1)
	cache.put_if_absent("b", 2)
	cache.put_if_absent("c", 3)
	assert(cache.size() == 3)
	assert(cache.has("a"))
	assert(cache.has("b"))
	assert(cache.has("c"))
	pass


func lru_cache_string_get_refreshes_recency_test() -> void:
	var cache := LruCacheString.new(2)
	cache.put_if_absent("a", 1)
	cache.put_if_absent("b", 2)
	assert(cache.get_value("a") == 1)
	cache.put_if_absent("c", 3)
	assert(cache.get_value("a") == 1)
	assert(not cache.has("b"))
	assert(cache.has("c"))
	pass


func lru_cache_string_missing_get_does_not_change_recency_test() -> void:
	var cache := LruCacheString.new(2)
	cache.put_if_absent("a", 1)
	cache.put_if_absent("b", 2)
	assert(cache.get_value("missing") == null)
	cache.put_if_absent("c", 3)
	assert(not cache.has("a"))
	assert(cache.has("b"))
	assert(cache.has("c"))
	pass


func lru_cache_string_remove_releases_capacity_test() -> void:
	var cache := LruCacheString.new(2)
	cache.put_if_absent("a", 1)
	cache.put_if_absent("b", 2)
	assert(cache.remove("a") == 1)
	cache.put_if_absent("c", 3)
	assert(cache.size() == 2)
	assert(cache.has("b"))
	assert(cache.has("c"))
	pass


func lru_cache_string_supports_empty_key_and_false_value_test() -> void:
	var cache := LruCacheString.new(2)
	cache.put_if_absent("", false)
	assert(cache.has(""))
	assert(cache.get_value("", "fallback") == false)
	pass


func lru_cache_string_has_does_not_refresh_recency_test() -> void:
	var cache := LruCacheString.new(2)
	cache.put_if_absent("a", 1)
	cache.put_if_absent("b", 2)
	assert(cache.has("a"))
	cache.put_if_absent("c", 3)
	assert(not cache.has("a"))
	assert(cache.has("b"))
	assert(cache.has("c"))
	pass


func lru_cache_string_put_if_absent_returns_evicted_entry_test() -> void:
	var cache := LruCacheString.new(2)
	cache.put_if_absent("a", 1)
	cache.put_if_absent("b", 2)
	var evicted := cache.put_if_absent("c", 3)
	assert(evicted.key == "a")
	assert(evicted.value == 1)
	assert(not cache.has("a"))
	pass


## `get_or_put` is the compile-once path two threads can share: the second builder of a key gets the value
## stored first instead of failing on an existing key, and a new key inserts and evicts like `put_if_absent`.
func lru_cache_string_get_or_put_keeps_the_first_value_test() -> void:
	var cache := LruCacheString.new(2)
	assert(cache.get_or_put("regex", "first") == "first")
	assert(cache.get_or_put("regex", "second") == "first")
	assert(cache.get_value("regex") == "first")
	assert(cache.size() == 1)
	assert(cache.get_or_put("other", "x") == "x")
	assert(cache.get_or_put("third", "y") == "y")
	assert(not cache.has("regex"))
	assert(cache.get_or_put("third", "z") == "y")
	pass


## The cache lives in `zfoo/concurrent/` because worker tasks share one instance, so the rows and the LRU
## order are hit from several threads at once: the same keys are built concurrently, and every one of them
## still reads back a stored value instead of corrupting the array the recency order lives in.
func lru_cache_string_parallel_access_test() -> void:
	shared_cache = LruCacheString.new(SHARED_KEY_COUNT)
	var threads: Array[Thread] = []
	for worker_index in THREAD_COUNT:
		var thread := Thread.new()
		assert(thread.start(Callable(self, "parallel_cache_worker").bind(worker_index)) == OK)
		threads.append(thread)
	for thread in threads:
		thread.wait_to_finish()
	assert(shared_cache.size() == SHARED_KEY_COUNT)
	for key_index in SHARED_KEY_COUNT:
		assert(shared_cache.has(shared_key(key_index)))
		assert(shared_cache.get_value(shared_key(key_index)) != null)
	pass


func parallel_cache_worker(worker_index: int) -> void:
	for offset in ITEMS_PER_THREAD:
		var key := shared_key(offset % SHARED_KEY_COUNT)
		# The first writer of a key wins, and every later one gets that stored value back instead of an
		# error or a half-written entry.
		assert(shared_cache.get_or_put(key, worker_index * ITEMS_PER_THREAD + offset) != null)
		assert(shared_cache.get_value(key) != null)
	pass


func shared_key(key_index: int) -> String:
	return "regex_rule_" + str(key_index)
