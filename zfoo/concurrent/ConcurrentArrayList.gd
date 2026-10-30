class_name ConcurrentArrayList
extends RefCounted

var list: Array[Variant] = []
var mutex: Mutex = Mutex.new()

func add(element: Variant) -> void:
	if element == null:
		Log.error("ConcurrentArrayList add rejected element:[null]")
		return
	mutex.lock()
	list.push_back(element)
	mutex.unlock()
	pass

# Retrieves and removes the head of this queue, or returns null if this queue is empty.
func pop_front() -> Variant:
	if list.is_empty():
		return null
	mutex.lock()
	var element: Variant = list.pop_front()
	mutex.unlock()
	return element

func pop_back() -> Variant:
	if list.is_empty():
		return null
	mutex.lock()
	var element: Variant = list.pop_back()
	mutex.unlock()
	return element

func clear() -> void:
	mutex.lock()
	list.clear()
	mutex.unlock()
	pass

func is_empty() -> bool:
	return list.is_empty()

func size() -> int:
	return list.size()
