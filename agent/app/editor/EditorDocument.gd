class_name EditorDocument
extends RefCounted

## One file open in the editor. Text files own a buffer; view-only files only use [member path].

enum Kind { TEXT, IMAGE }

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
	if not EditorTabs.can_open(normalized):
		return null
	var file := EditorDocument.new()
	file.path = normalized
	file.refresh_kind()
	if file.is_text():
		file.text = FileUtils.read_file_to_string(normalized)
		file.saved_text = file.text
	return file


static func kind_for_path(path: String) -> Kind:
	if FileColors.category_for_path(path) == FileColors.Category.IMAGE:
		return Kind.IMAGE
	return Kind.TEXT
