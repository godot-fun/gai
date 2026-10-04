class_name ArrayMapString
extends RefCounted

## Compact insertion-ordered map for [String] keys and values.
##
## Keys and values are stored at matching indexes in two [PackedStringArray]s.
## This avoids the hashing overhead of [Dictionary] for small maps, while
## lookup, insertion, and removal are O(n). This container is not thread-safe.

var key_array: PackedStringArray = PackedStringArray()
var value_array: PackedStringArray = PackedStringArray()


## Inserts or replaces a value. Returns the previous value, or
## [param default_value] when the key was absent.
func put(key: String, value: String, default_value: String = "") -> String:
	var index := key_array.find(key)
	if index >= 0:
		var old_value := value_array[index]
		value_array[index] = value
		return old_value
	key_array.append(key)
	value_array.append(value)
	return default_value


func get_value(key: String, default_value: String = "") -> String:
	var index := key_array.find(key)
	if index < 0:
		return default_value
	return value_array[index]


func has(key: String) -> bool:
	return key_array.has(key)


## Removes a key and returns its previous value, or [param default_value].
func remove(key: String, default_value: String = "") -> String:
	var index := key_array.find(key)
	if index < 0:
		return default_value
	var old_value := value_array[index]
	key_array.remove_at(index)
	value_array.remove_at(index)
	return old_value


func clear() -> void:
	key_array.clear()
	value_array.clear()
	pass


func is_empty() -> bool:
	return key_array.is_empty()


func size() -> int:
	return key_array.size()


func key_at(index: int) -> String:
	return key_array[index]


func value_at(index: int) -> String:
	return value_array[index]


func keys() -> PackedStringArray:
	return key_array.duplicate()


func values() -> PackedStringArray:
	return value_array.duplicate()
