class_name EditorDocument
extends RefCounted

## One file open in the editor. Text files own a buffer; view-only files only use [member path].

enum Kind { TEXT, IMAGE }

const SAMPLE_BYTES: int = 8192

var path: String = ""
var text: String = ""
var saved_text: String = ""
var kind: Kind = Kind.TEXT


func is_dirty() -> bool:
	return is_text() and text != saved_text


func is_image() -> bool:
	return kind == Kind.IMAGE


func is_text() -> bool:
	return kind == Kind.TEXT


func refresh_kind() -> void:
	kind = kind_for_path(path)
	if not is_text():
		text = ""
		saved_text = ""
	pass


func file_name() -> String:
	return path.get_file()


func save() -> Error:
	if not is_text():
		return OK
	var error := FileUtils.write_string_to_file(path, text)
	if error != OK:
		return error
	saved_text = text
	return OK


static func same_path(a: String, b: String) -> bool:
	var left := FileUtils.normalize_path(a)
	var right := FileUtils.normalize_path(b)
	if OSUtils.is_windows():
		return left.to_lower() == right.to_lower()
	return left == right


static func read(path: String) -> EditorDocument:
	var normalized := FileUtils.normalize_path(path)
	if not can_open(normalized):
		return null
	var file := EditorDocument.new()
	file.path = normalized
	file.refresh_kind()
	if file.is_text():
		file.text = FileUtils.read_file_to_string(normalized)
		file.saved_text = file.text
	return file


## Text, config, and image files open. Audio and video do not. Other files require a text-like sample.
static func can_open(path: String) -> bool:
	var normalized := FileUtils.normalize_path(path)
	if normalized.is_empty() or not FileAccess.file_exists(normalized) or DirAccess.dir_exists_absolute(normalized):
		return false
	var category := FileColors.category_for_path(normalized)
	if category == FileColors.Category.IMAGE:
		return true
	if category == FileColors.Category.AUDIO or category == FileColors.Category.VIDEO:
		return false
	return not contains_nul(normalized)


static func kind_for_path(path: String) -> Kind:
	if FileColors.category_for_path(path) == FileColors.Category.IMAGE:
		return Kind.IMAGE
	return Kind.TEXT


static func contains_nul(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return true
	var length := mini(file.get_length(), SAMPLE_BYTES)
	return length > 0 and file.get_buffer(length).find(0) >= 0
