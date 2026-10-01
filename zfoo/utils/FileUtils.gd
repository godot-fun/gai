class_name FileUtils
extends Object

# ---------------------------------------------------------------------------
# Constants — byte/bit units and line endings
# ---------------------------------------------------------------------------

# Bytes
const ONE_BYTE: int = 1
const BYTES_PER_KB: int = 1024
const BYTES_PER_MB: int = BYTES_PER_KB * 1024
const BYTES_PER_GB: int = BYTES_PER_MB * 1024

# Bits
const BITS_PER_BYTE: int = 8
const BITS_PER_KB: int = BYTES_PER_KB * 8
const BITS_PER_MB: int = BYTES_PER_MB * 8
const BITS_PER_GB: int = BYTES_PER_GB * 8

# Line endings (text files)
const NEWLINE_LF: String = "\n"
const NEWLINE_CR: String = "\r"
const NEWLINE_CRLF: String = "\r\n"


# ---------------------------------------------------------------------------
# Line endings
# ---------------------------------------------------------------------------

static func normalize_line_endings_to_lf(s: String) -> String:
	return s.replace(NEWLINE_CRLF, NEWLINE_LF).replace(NEWLINE_CR, NEWLINE_LF)


static func count_lines(text: String) -> int:
	if text.is_empty():
		return 0
	return text.count(NEWLINE_LF) + (0 if text.ends_with(NEWLINE_LF) else 1)


# ---------------------------------------------------------------------------
# Project root
# ---------------------------------------------------------------------------

## Returns the absolute path to the folder containing project.godot.
static func get_project_root_path() -> String:
	var dir := ProjectSettings.globalize_path("res://")
	for _i in range(8):
		if FileAccess.file_exists(dir.path_join("project.godot")):
			return dir
		var parent := dir.get_base_dir()
		if parent == dir:
			break
		dir = parent
	return ProjectSettings.globalize_path("res://")


# ---------------------------------------------------------------------------
# File read / write / delete
# ---------------------------------------------------------------------------

## Converts `user://` / `res://` to an absolute path and creates the parent directory.
## Returns the absolute path, or empty string if the parent directory cannot be created.
static func globalize_writable_path(path: String) -> String:
	var absolute := path
	if path.begins_with("user://") or path.begins_with("res://"):
		absolute = ProjectSettings.globalize_path(path)
	var dir := absolute.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		if DirAccess.make_dir_recursive_absolute(dir) != OK:
			return StringUtils.EMPTY
	return absolute


## Opens a file or directory with the operating system's default application.
## If a file has no associated application, opens its containing folder instead.
static func open_file(path: String) -> int:
	if DirAccess.dir_exists_absolute(path):
		return OS.shell_open(path)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var error := OS.shell_open(path)
	if error == OK:
		return OK
	var folder_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder_path):
		return error
	return OS.shell_open(folder_path)

# Append content to the file.
static func write_string_to_file(path: String, content: String) -> bool:
	var absolute := globalize_writable_path(path)
	if absolute.is_empty():
		return false
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	var error := file.get_error()
	file = null
	return error == OK


static func read_file_to_string(filePath: String) -> String:
	if not FileAccess.file_exists(filePath):
		return StringUtils.EMPTY
	var bytes := read_file_to_byte_array(filePath)
	if bytes.is_empty():
		return StringUtils.EMPTY
	# Avoid get_as_text() — NUL bytes log "Unexpected NUL character" and become U+FFFD.
	if bytes.find(0) >= 0:
		return StringUtils.EMPTY
	var text := bytes.get_string_from_utf8()
	if text.is_empty() and bytes.size() > 0:
		return StringUtils.EMPTY
	return text


static func read_file_to_byte_array(filePath: String) -> PackedByteArray:
	# make sure our file exists on users system
	if !FileAccess.file_exists(filePath):
		return PackedByteArray()

	# allow reading only for file
	var file := FileAccess.open(filePath, FileAccess.READ)

	var buffer := file.get_buffer(file.get_length())
	file = null
	return buffer


## Reads a text file as packed lines; empty for missing, binary, or non-UTF-8 files.
static func read_file_to_lines(abs_path: String, allow_empty: bool = false) -> PackedStringArray:
	var text := read_file_to_string(abs_path)
	if text.is_empty():
		return PackedStringArray()
	return text.split(NEWLINE_LF, allow_empty)


## Deletes [param path] — a file, or a directory with everything inside it.
## Directories are removed recursively without following directory links,
## so a link is unlinked instead of emptying the folder it points at.
## Returns false when [param path] does not exist or any entry cannot be removed.
static func delete_file_or_directory(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		var dir := DirAccess.open(path)
		if dir == null:
			return false
		for file_name in dir.get_files():
			if not delete_file_or_directory(path.path_join(file_name)):
				return false
		for directory_name in dir.get_directories():
			var directory_path := path.path_join(directory_name)
			if dir.is_link(directory_name):
				if DirAccess.remove_absolute(directory_path) != OK:
					return false
				continue
			if not delete_file_or_directory(directory_path):
				return false
		dir = null
		return DirAccess.remove_absolute(path) == OK
	if not FileAccess.file_exists(path):
		return false
	# Git marks loose objects read-only on Windows.
	if FileAccess.set_read_only_attribute(path, false) != OK:
		return false
	return DirAccess.remove_absolute(path) == OK


# ---------------------------------------------------------------------------
# Directory listing
# ---------------------------------------------------------------------------

# Returns absolute paths of all files in the given folder.
# Set recursive to true to include files in subfolders.
static func get_all_files_in_folder(folderPath: String, recursive: bool = false) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(folderPath)
	if dir == null:
		return files

	for file_name in dir.get_files():
		files.append(folderPath.path_join(file_name))

	if recursive:
		for dir_name in dir.get_directories():
			files.append_array(get_all_files_in_folder(folderPath.path_join(dir_name), true))

	return files


# Returns absolute paths of subdirectories in the given folder.
# Set recursive to true to include nested subdirectories (not the root folder itself).
static func get_all_directories_in_folder(folderPath: String, recursive: bool = false) -> Array[String]:
	var dirs: Array[String] = []
	var dir := DirAccess.open(folderPath)
	if dir == null:
		return dirs
	for dir_name in dir.get_directories():
		var abs := folderPath.path_join(dir_name)
		dirs.append(abs)
		if recursive:
			dirs.append_array(get_all_directories_in_folder(abs, true))
	return dirs


# ---------------------------------------------------------------------------
# Folder file queries
# ---------------------------------------------------------------------------

# Returns the absolute path of the newest file in folderPath (non-recursive).
static func get_newest_file_in_folder(folder_path: String) -> String:
	if not DirAccess.dir_exists_absolute(folder_path):
		return ""

	var newest_path := ""
	var newest_time := -1
	for file_path in get_all_files_in_folder(folder_path, false):
		var modified := FileAccess.get_modified_time(file_path)
		if modified > newest_time:
			newest_time = modified
			newest_path = file_path
	return newest_path


## Deletes the oldest files until [param folder_path] is no larger than [param max_bytes].
## Non-recursive. Safe to run on a worker thread (file IO only).
static func cleanup_cache_folder(folder_path: String, max_bytes: int) -> void:
	if max_bytes < 0 or not DirAccess.dir_exists_absolute(folder_path):
		return
	var cache_files := get_all_files_in_folder(folder_path)
	var total_bytes := 0
	for file_path in cache_files:
		total_bytes += FileAccess.get_size(file_path)
	if total_bytes <= max_bytes:
		return
	cache_files.sort_custom(func(left: String, right: String) -> bool:
		var left_modified := FileAccess.get_modified_time(left)
		var right_modified := FileAccess.get_modified_time(right)
		return left_modified < right_modified if left_modified != right_modified else left < right
	)
	for file_path in cache_files:
		var file_size := FileAccess.get_size(file_path)
		if DirAccess.remove_absolute(file_path) == OK:
			total_bytes -= file_size
		if total_bytes <= max_bytes:
			break
	pass


# ---------------------------------------------------------------------------
# Filename sanitization
# ---------------------------------------------------------------------------

# Convert a string into a valid filename using underscores as separators.
# aa bb cc dd -> aa_bb_cc
static func sanitize_filename(name: String) -> String:
	var regex := RegEx.new()

	# Replace all non-alphanumeric characters with '_'
	regex.compile("[^a-zA-Z0-9_-]")

	var result := regex.sub(name, "_", true)

	regex.compile("_+")
	result = regex.sub(result, "_", true)

	result = result.strip_edges()
	result = result.trim_prefix("_")
	result = result.trim_suffix("_")

	if StringUtils.is_blank(result):
		result = "unnamed"

	return result
