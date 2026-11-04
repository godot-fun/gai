class_name EditorDocument
extends RefCounted

## One open text file. [member text] is the buffer; [member saved_text] is the last version written to disk.

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


static func read(path: String) -> EditorDocument:
	var normalized := normalize(path)
	if not EditorTabs.can_open(normalized):
		return null
	var file := EditorDocument.new()
	file.path = normalized
	file.text = FileUtils.read_file_to_string(normalized)
	file.saved_text = file.text
	return file
