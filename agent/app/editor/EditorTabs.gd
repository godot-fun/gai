class_name EditorTabs
extends RefCounted

## Open files in the editor. [method active] is the file shown in the editor pane.

const SAMPLE_BYTES: int = 8192

var files: Array[EditorDocument] = []
var active_index: int = -1


func active() -> EditorDocument:
	if active_index < 0 or active_index >= files.size():
		return null
	return files[active_index]


func find_index(path: String) -> int:
	for index in files.size():
		if EditorDocument.same_path(files[index].path, path):
			return index
	return -1


func open_file(path: String) -> EditorDocument:
	var existing := find_index(path)
	if existing >= 0:
		active_index = existing
		return files[existing]
	var file := EditorDocument.read(path)
	if file == null:
		return null
	files.append(file)
	active_index = files.size() - 1
	return file


func close_at(index: int) -> void:
	if index < 0 or index >= files.size():
		return
	files.remove_at(index)
	if files.is_empty():
		active_index = -1
		return
	if active_index > index:
		active_index -= 1
	elif active_index == index:
		active_index = mini(index, files.size() - 1)
	pass


func dirty_files() -> Array[EditorDocument]:
	var dirty: Array[EditorDocument] = []
	for file in files:
		if file.is_dirty():
			dirty.append(file)
	return dirty


## Text and config files open. Audio, image, and video do not. Other files open when the sample has no NUL bytes.
static func can_open(path: String) -> bool:
	var normalized := EditorDocument.normalize(path)
	if normalized.is_empty() or not FileAccess.file_exists(normalized):
		return false
	if DirAccess.dir_exists_absolute(normalized):
		return false
	var category := FileColors.category_for_path(normalized)
	if category == FileColors.Category.AUDIO or category == FileColors.Category.IMAGE or category == FileColors.Category.VIDEO:
		return false
	return not contains_nul(normalized)


static func contains_nul(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return true
	var length := mini(file.get_length(), SAMPLE_BYTES)
	if length <= 0:
		return false
	return file.get_buffer(length).find(0) >= 0
