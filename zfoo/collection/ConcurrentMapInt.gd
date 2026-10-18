## A thread-safe map with int keys and non-null Variant values.
## Collection-returning methods return snapshots rather than internal storage.
class_name ConcurrentMapInt
extends RefCounted

var _map: Dictionary[int, Variant] = {}
var _mutex: Mutex = Mutex.new()


## Inserts or replaces a value and returns the previous value, or null when absent.
func put(key: int, value: Variant) -> Variant:
	if value == null:
		Log.error("ConcurrentMapInt put rejected key:[{}] value:[null]", key)
		return null
	_mutex.lock()
	var old_value: Variant = _map.get(key, null)
	_map[key] = value
	_mutex.unlock()
	return old_value


## Inserts a value only when the key is absent. Returns the existing value when present.
func put_if_absent(key: int, value: Variant) -> Variant:
	if value == null:
		Log.error("ConcurrentMapInt put_if_absent rejected key:[{}] value:[null]", key)
		return null
	_mutex.lock()
	if _map.has(key):
		var existing_value: Variant = _map[key]
		_mutex.unlock()
		return existing_value
	_map[key] = value
	_mutex.unlock()
	return null


func get_value(key: int, default_value: Variant = null) -> Variant:
	_mutex.lock()
	var value: Variant = _map.get(key, default_value)
	_mutex.unlock()
	return value


func has(key: int) -> bool:
	_mutex.lock()
	var contains_key := _map.has(key)
	_mutex.unlock()
	return contains_key


## Removes a key and returns its previous value, or null when absent.
func remove(key: int) -> Variant:
	_mutex.lock()
	if not _map.has(key):
		_mutex.unlock()
		return null
	var old_value: Variant = _map[key]
	_map.erase(key)
	_mutex.unlock()
	return old_value


func clear() -> void:
	_mutex.lock()
	_map.clear()
	_mutex.unlock()
	pass


func size() -> int:
	_mutex.lock()
	var map_size := _map.size()
	_mutex.unlock()
	return map_size


func is_empty() -> bool:
	_mutex.lock()
	var empty := _map.is_empty()
	_mutex.unlock()
	return empty


func keys() -> Array[int]:
	_mutex.lock()
	var result: Array[int] = []
	result.assign(_map.keys())
	_mutex.unlock()
	return result


func values() -> Array[Variant]:
	_mutex.lock()
	var result: Array[Variant] = []
	result.assign(_map.values())
	_mutex.unlock()
	return result


func snapshot() -> Dictionary[int, Variant]:
	_mutex.lock()
	var result: Dictionary[int, Variant] = _map.duplicate()
	_mutex.unlock()
	return result
