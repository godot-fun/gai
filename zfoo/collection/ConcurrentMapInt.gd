## A thread-safe map with int keys and non-null Variant values.
## Collection-returning methods return snapshots rather than internal storage.
class_name ConcurrentMapInt
extends RefCounted

var map: Dictionary[int, Variant] = {}
var mutex: Mutex = Mutex.new()


## Inserts or replaces a value and returns the previous value, or null when absent.
func put(key: int, value: Variant) -> Variant:
	if value == null:
		Log.error("ConcurrentMapInt put rejected key:[{}] value:[null]", key)
		return null
	mutex.lock()
	var old_value: Variant = map.get(key, null)
	map[key] = value
	mutex.unlock()
	return old_value


## Inserts a value only when the key is absent. Returns the existing value when present.
func put_if_absent(key: int, value: Variant) -> Variant:
	if value == null:
		Log.error("ConcurrentMapInt put_if_absent rejected key:[{}] value:[null]", key)
		return null
	mutex.lock()
	if map.has(key):
		var existing_value: Variant = map[key]
		mutex.unlock()
		return existing_value
	map[key] = value
	mutex.unlock()
	return null


func get_value(key: int, default_value: Variant = null) -> Variant:
	mutex.lock()
	var value: Variant = map.get(key, default_value)
	mutex.unlock()
	return value


func has(key: int) -> bool:
	mutex.lock()
	var contains_key := map.has(key)
	mutex.unlock()
	return contains_key


## Removes a key and returns its previous value, or null when absent.
func remove(key: int) -> Variant:
	mutex.lock()
	if not map.has(key):
		mutex.unlock()
		return null
	var old_value: Variant = map[key]
	map.erase(key)
	mutex.unlock()
	return old_value


func clear() -> void:
	mutex.lock()
	map.clear()
	mutex.unlock()
	pass


func size() -> int:
	mutex.lock()
	var map_size := map.size()
	mutex.unlock()
	return map_size


func is_empty() -> bool:
	mutex.lock()
	var empty := map.is_empty()
	mutex.unlock()
	return empty


func keys() -> Array[int]:
	mutex.lock()
	var result: Array[int] = []
	result.assign(map.keys())
	mutex.unlock()
	return result


func values() -> Array[Variant]:
	mutex.lock()
	var result: Array[Variant] = []
	result.assign(map.values())
	mutex.unlock()
	return result


func snapshot() -> Dictionary[int, Variant]:
	mutex.lock()
	var result: Dictionary[int, Variant] = map.duplicate()
	mutex.unlock()
	return result
