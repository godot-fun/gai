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


func close_all() -> void:
	files.clear()
	active_index = -1
	pass


func close_others(index: int) -> void:
	if index < 0 or index >= files.size():
		return
	var kept := files[index]
	files.assign([kept])
	active_index = 0
	pass


## Closes a file or every open file below a deleted folder.
func close_under(path: String) -> bool:
	var removed := false
	for index in range(files.size() - 1, -1, -1):
		if FileUtils.is_relative_to(files[index].path, path):
			close_at(index)
			removed = true
	return removed


func dirty_files() -> Array[EditorDocument]:
	var dirty: Array[EditorDocument] = []
	for file in files:
		if file.is_dirty():
			dirty.append(file)
	return dirty


## Text, config, and image files open. Audio and video do not. Other files open when the sample has no NUL bytes.
static func can_open(path: String) -> bool:
	var normalized := FileUtils.normalize_path(path)
	if normalized.is_empty() or not FileAccess.file_exists(normalized):
		return false
	if DirAccess.dir_exists_absolute(normalized):
		return false
	var category := FileColors.category_for_path(normalized)
	if category == FileColors.Category.IMAGE:
		return true
	if category == FileColors.Category.AUDIO or category == FileColors.Category.VIDEO:
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


# ---------------------------------------------------------------------------
# Persist open tabs to `.gai/app/editor.gai`
# ---------------------------------------------------------------------------

const EDITOR_GAI := "app/editor.gai"


static func load() -> EditorTabs:
	var path := AgentWorkspace.get_data_path(EDITOR_GAI)
	if not FileAccess.file_exists(path):
		return EditorTabs.new()
	var tabs: Variant = JsonUtils.json_to_object(FileUtils.read_file_to_string(path), EditorTabs)
	if tabs is not EditorTabs:
		return EditorTabs.new()
	var loaded := tabs as EditorTabs
	for file in loaded.files:
		file.refresh_kind()
	if loaded.files.is_empty():
		loaded.active_index = -1
	elif loaded.active_index < 0 or loaded.active_index >= loaded.files.size():
		loaded.active_index = 0
	return loaded


func save() -> void:
	var path := AgentWorkspace.get_data_path(EDITOR_GAI)
	if files.is_empty() and not FileAccess.file_exists(path):
		return
	var error := FileUtils.write_string_to_file(path, JsonUtils.object_to_json(self))
	if error != OK:
		Log.error("editor tabs save failed path:[{}] err:[{}]", path, error)
	pass
