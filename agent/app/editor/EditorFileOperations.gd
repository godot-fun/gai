class_name EditorFileOperations
extends Object

## Pure filesystem operations shared by the editor file-tree actions.


static func copy_entry(source: String, target: String) -> Error:
	var normalized_source := FileUtils.normalize_path(source)
	var normalized_target := FileUtils.normalize_path(target)
	if DirAccess.dir_exists_absolute(normalized_source):
		if FileUtils.is_relative_to(normalized_target, normalized_source):
			return ERR_INVALID_PARAMETER
		return copy_directory(normalized_source, normalized_target)
	if not FileAccess.file_exists(normalized_source):
		return ERR_FILE_NOT_FOUND
	return DirAccess.copy_absolute(normalized_source, normalized_target)


static func copy_directory(source: String, target: String) -> Error:
	var make_error := DirAccess.make_dir_recursive_absolute(target)
	if make_error != OK:
		return make_error
	var directory := DirAccess.open(source)
	if directory == null:
		return DirAccess.get_open_error()
	for file_name in directory.get_files():
		var copy_error := DirAccess.copy_absolute(source.path_join(file_name), target.path_join(file_name))
		if copy_error != OK:
			return copy_error
	for directory_name in directory.get_directories():
		var copy_error := copy_directory(source.path_join(directory_name), target.path_join(directory_name))
		if copy_error != OK:
			return copy_error
	return OK


static func unique_copy_path(source: String, target_directory: String) -> String:
	var file_name := source.get_file()
	var is_directory := DirAccess.dir_exists_absolute(source)
	var extension := "" if is_directory else file_name.get_extension()
	var stem := file_name if extension.is_empty() else file_name.trim_suffix("." + extension)
	var suffix := "" if extension.is_empty() else "." + extension
	var candidate := FileUtils.normalize_path(target_directory.path_join(file_name))
	if not entry_exists(candidate):
		return candidate
	var number := 1
	while true:
		var copy_label := " copy" if number == 1 else " copy " + str(number)
		candidate = FileUtils.normalize_path(target_directory.path_join(stem + copy_label + suffix))
		if not entry_exists(candidate):
			return candidate
		number += 1
	return ""


static func valid_entry_name(entry_name: String) -> bool:
	var trimmed := entry_name.strip_edges()
	if trimmed.is_empty() or trimmed == "." or trimmed == "..":
		return false
	for invalid in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		if invalid in trimmed:
			return false
	return true


static func entry_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
