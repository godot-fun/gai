class_name EditorTabs
extends RefCounted

## Open files in the editor. [method active] is the file shown in the editor pane.

var documents: Array[EditorDocument] = []
var active_index: int = -1


func active() -> EditorDocument:
	if active_index < 0 or active_index >= documents.size():
		return null
	return documents[active_index]


func find_index(path: String) -> int:
	for index in documents.size():
		if EditorDocument.same_path(documents[index].path, path):
			return index
	return -1


func open_file(path: String) -> EditorDocument:
	var existing := find_index(path)
	if existing >= 0:
		active_index = existing
		return documents[existing]
	var document := EditorDocument.read(path)
	if document == null:
		return null
	documents.append(document)
	active_index = documents.size() - 1
	return document


func close_at(index: int) -> void:
	if index < 0 or index >= documents.size():
		return
	documents.remove_at(index)
	if documents.is_empty():
		active_index = -1
		return
	if active_index > index:
		active_index -= 1
	elif active_index == index:
		active_index = mini(index, documents.size() - 1)
	pass


func dirty_documents() -> Array[EditorDocument]:
	var dirty: Array[EditorDocument] = []
	for document in documents:
		if document.is_dirty():
			dirty.append(document)
	return dirty
