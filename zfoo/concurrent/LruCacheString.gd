## A thread-safe bounded least-recently-used cache with String keys and non-null Variant values.
## Intended for small caches: recency updates use an array and are O(capacity).
## Every access takes [member mutex], so one cache can be shared by the main thread and worker tasks
## ([member GlobUtils.regex_cache] is read by walks on the worker pool and on the single-thread executor).
class_name LruCacheString
extends RefCounted

var maximum_size: int
var cache_map: Dictionary[String, Variant] = {}
## The first key is least recently used; the final key is most recently used.
var access_order: Array[String] = []
var mutex: Mutex = Mutex.new()


func _init(_maximum_size: int) -> void:
	assert(_maximum_size >= 1)
	maximum_size = _maximum_size
	pass


## Inserts a new value and marks the key as most recently used.
## Existing keys are rejected. Returns the removed LRU entry, or [code]null[/code] if none.
func put_if_absent(key: String, value: Variant) -> PairString:
	if value == null:
		Log.error("LruCacheString put_if_absent rejected key:[{}] value:[null]", key)
		return null
	mutex.lock()
	if cache_map.has(key):
		mutex.unlock()
		Log.error("LruCacheString put_if_absent failed for key:[{}] value:[{}] because the key already exists", key, value)
		return null
	var old_entry := put_locked(key, value)
	mutex.unlock()
	return old_entry


## Returns the cached value for [param key], or inserts [param value] and returns it.
## The lookup and the insert share one lock, so two threads that build the same entry converge on the one
## stored first instead of failing on an existing key; the returned value is the stored one.
func get_or_put(key: String, value: Variant) -> Variant:
	if value == null:
		Log.error("LruCacheString get_or_put rejected key:[{}] value:[null]", key)
		return null
	mutex.lock()
	var stored: Variant = cache_map.get(key)
	if stored == null:
		put_locked(key, value)
		stored = value
	else:
		touch_locked(key)
	mutex.unlock()
	return stored


## Returns a value and marks its key as most recently used.
func get_value(key: String, default_value: Variant = null) -> Variant:
	mutex.lock()
	if not cache_map.has(key):
		mutex.unlock()
		return default_value
	touch_locked(key)
	var value: Variant = cache_map[key]
	mutex.unlock()
	return value


func has(key: String) -> bool:
	# Membership checks intentionally do not count as value access.
	mutex.lock()
	var found := cache_map.has(key)
	mutex.unlock()
	return found


## Removes a key and returns its previous value, or [code]null[/code].
func remove(key: String) -> Variant:
	mutex.lock()
	if not cache_map.has(key):
		mutex.unlock()
		return null
	var old_value: Variant = cache_map[key]
	cache_map.erase(key)
	access_order.erase(key)
	mutex.unlock()
	return old_value


func clear() -> void:
	# Both containers must be cleared to prevent stale order entries after reuse.
	mutex.lock()
	cache_map.clear()
	access_order.clear()
	mutex.unlock()
	pass


func size() -> int:
	mutex.lock()
	var count := cache_map.size()
	mutex.unlock()
	return count


## Stores one entry and evicts the least recently used one past [member maximum_size]. Callers hold
## [member mutex]; the caller of [method put_if_absent] gets the evicted entry back.
func put_locked(key: String, value: Variant) -> PairString:
	var old_entry: PairString = null
	cache_map[key] = value
	access_order.append(key)
	if cache_map.size() > maximum_size:
		var oldest_key: String = access_order.pop_front()
		old_entry = PairString.new(oldest_key, cache_map[oldest_key])
		cache_map.erase(oldest_key)
	return old_entry


## Marks an existing key as most recently used. Callers hold [member mutex].
func touch_locked(key: String) -> void:
	access_order.erase(key)
	access_order.append(key)
	pass
