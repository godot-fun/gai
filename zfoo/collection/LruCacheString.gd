## A bounded least-recently-used cache with String keys and non-null Variant values.
## Intended for small caches: recency updates use an array and are O(capacity).
## This container is not thread-safe; synchronize externally when shared by workers.
class_name LruCacheString
extends RefCounted

var maximum_size: int
var cache_map: Dictionary[String, Variant] = {}
## The first key is least recently used; the final key is most recently used.
var access_order: Array[String] = []


func _init(_maximum_size: int) -> void:
	assert(_maximum_size >= 1)
	maximum_size = _maximum_size
	pass


## Inserts a new value and marks the key as most recently used.
## Existing keys are rejected. Returns the removed LRU entry, or [code]null[/code] if none.
func put(key: String, value: Variant) -> PairString:
	if value == null:
		Log.error("LruCacheString put rejected key:[{}] value:[null]", key)
		return null
	if cache_map.has(key):
		Log.error("LruCacheString put failed for key:[{}] value:[{}] because the key already exists", key, value)
		return null
	var old_entry: PairString = null
	cache_map[key] = value
	access_order.append(key)
	if cache_map.size() > maximum_size:
		var oldest_key: String = access_order.pop_front()
		old_entry = PairString.new(oldest_key, cache_map[oldest_key])
		cache_map.erase(oldest_key)
	return old_entry


## Returns a value and marks its key as most recently used.
func get_value(key: String, default_value: Variant = null) -> Variant:
	if not cache_map.has(key):
		return default_value
	access_order.erase(key)
	access_order.append(key)
	return cache_map[key]


func has(key: String) -> bool:
	# Membership checks intentionally do not count as value access.
	return cache_map.has(key)


## Removes a key and returns its previous value, or [code]null[/code].
func remove(key: String) -> Variant:
	if not cache_map.has(key):
		return null
	var old_value: Variant = cache_map[key]
	cache_map.erase(key)
	access_order.erase(key)
	return old_value


func clear() -> void:
	# Both containers must be cleared to prevent stale order entries after reuse.
	cache_map.clear()
	access_order.clear()
	pass


func size() -> int:
	return cache_map.size()
