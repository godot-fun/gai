class_name EditorDocument
extends RefCounted

## One open text file. [member text] is the buffer; [member saved_text] is the last version written to disk.

const SKIPPED_NAMES: PackedStringArray = [".git", ".godot", ".gai"]
const SAMPLE_BYTES: int = 8192

var path: String = ""
var text: String = ""
var saved_text: String = ""


func is_dirty() -> bool:
	return text != saved_text


func file_name() -> String:
	return path.get_file()


func save() -> Error:
	var error := FileUtils.write_string_to_file(path, text)
	if error != OK:
		return error
	saved_text = text
	return OK


static func normalize(path: String) -> String:
	return FileUtils.normalize_path(path)


static func same_path(a: String, b: String) -> bool:
	var left := normalize(a)
	var right := normalize(b)
	if OSUtils.is_windows():
		return left.to_lower() == right.to_lower()
	return left == right


static func is_skipped_name(entry_name: String) -> bool:
	return entry_name == "." or entry_name == ".." or SKIPPED_NAMES.has(entry_name)


## Text and config files open. Audio, image, and video do not. Other files open when the sample has no NUL bytes.
static func can_edit(path: String) -> bool:
	var normalized := normalize(path)
	if normalized.is_empty() or not FileAccess.file_exists(normalized):
		return false
	if DirAccess.dir_exists_absolute(normalized):
		return false
	var category := FileColors.category_for_path(normalized)
	if category == FileColors.Category.AUDIO or category == FileColors.Category.IMAGE or category == FileColors.Category.VIDEO:
		return false
	return not contains_nul(normalized)


static func read(path: String) -> EditorDocument:
	var normalized := normalize(path)
	if not can_edit(normalized):
		return null
	var document := EditorDocument.new()
	document.path = normalized
	document.text = FileUtils.read_file_to_string(normalized)
	document.saved_text = document.text
	return document


static func contains_nul(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return true
	var length := mini(file.get_length(), SAMPLE_BYTES)
	if length <= 0:
		return false
	return file.get_buffer(length).find(0) >= 0
