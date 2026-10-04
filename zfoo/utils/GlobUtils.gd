## Glob matching and recursive file discovery with a bounded compiled-RegEx cache.
## Paths are normalized to forward slashes before matching.
class_name GlobUtils
extends Object

## Keeps repeated ignore rules cheap without allowing unbounded process-lifetime growth.
const REGEX_CACHE_MAX_SIZE: int = 256

static var regex_cache := LruCacheString.new(REGEX_CACHE_MAX_SIZE)


## Finds files under [param search_root] whose relative path matches [param glob_pattern].
## Set [param recursive] to [code]false[/code] to search only the root folder.
## Uses breadth-first traversal and skips files larger than [param max_file_bytes]; [code]0[/code] disables the limit.
static func glob(search_root: String, glob_pattern: String, recursive: bool = true, max_file_bytes: int = 0, skip_glob_rules: Array[String] = []) -> Array[String]:
	var files: Array[String] = []
	var pattern := glob_pattern.strip_edges().replace("\\", "/")
	var pattern_has_path := pattern.contains("/")
	if FileAccess.file_exists(search_root):
		var file_name := search_root.replace("\\", "/").get_file()
		if (pattern.is_empty() or glob_match(pattern, file_name, false)) and (max_file_bytes <= 0 or FileAccess.get_size(search_root) <= max_file_bytes):
			files.append(search_root)
		return files
	if not DirAccess.dir_exists_absolute(search_root):
		return files

	var normalized_root := search_root.replace("\\", "/")
	var root_prefix := normalized_root if normalized_root.ends_with("/") else normalized_root + "/"
	var folders: Array[String] = [search_root]
	var folder_index := 0
	# A moving index provides FIFO/BFS behavior without the O(n) cost of pop_front().
	while folder_index < folders.size():
		var folder_path := folders[folder_index]
		folder_index += 1
		var dir := DirAccess.open(folder_path)
		if dir == null:
			continue
		for file_name in dir.get_files():
			var file_path := folder_path.path_join(file_name)
			if max_file_bytes > 0 and FileAccess.get_size(file_path) > max_file_bytes:
				continue
			var normalized_path := file_path.replace("\\", "/")
			var relative_path := normalized_path.substr(root_prefix.length())
			var match_path := relative_path if pattern_has_path else file_name
			if pattern.is_empty() or glob_match(pattern, match_path, false):
				files.append(file_path)
		if recursive:
			for dir_name in dir.get_directories():
				var child_path := folder_path.path_join(dir_name)
				var normalized_child := child_path.replace("\\", "/")
				var relative_child := normalized_child.substr(root_prefix.length())
				if not glob_match_any(skip_glob_rules, relative_child):
					folders.append(child_path)
		# Periodically discard consumed queue entries so a large tree is not retained forever.
		if folder_index >= 1024 and folder_index * 2 >= folders.size():
			folders = folders.slice(folder_index)
			folder_index = 0
	files.sort()
	return files


## Matches a path against a glob or one ignore-file line.
## Set [param parse_ignore_syntax] to [code]false[/code] so leading `#` and `!` stay literal.
## A rule without `/` matches a name at any depth; a trailing `/` also covers descendants.
static func glob_match(glob_rule: String, path_or_file: String, parse_ignore_syntax: bool = true) -> bool:
	var rule := glob_rule.strip_edges()
	if rule.is_empty() or (parse_ignore_syntax and rule.begins_with("#")):
		return false
	if parse_ignore_syntax and rule.begins_with("!"):
		rule = rule.substr(1).strip_edges()
		if rule.is_empty():
			return false

	rule = rule.replace("\\", "/").strip_edges()
	var path := path_or_file.replace("\\", "/").strip_edges()
	if rule.is_empty() or path.is_empty():
		return false

	var regex := get_or_compile_regex(rule)
	return regex != null and regex.search(path) != null


## Returns true when [param path_or_file] matches any ignore-file rule.
static func glob_match_any(glob_rules: Array[String], path_or_file: String) -> bool:
	for glob_rule in glob_rules:
		if glob_match(glob_rule, path_or_file):
			return true
	return false


## Compiles one normalized glob rule and infers directory semantics from a trailing `/`.
## Cache hits refresh the expression's LRU position.
static func get_or_compile_regex(glob_rule: String) -> RegEx:
	var directory_rule := glob_rule.ends_with("/")
	var rule := glob_rule.trim_suffix("/").strip_edges() if directory_rule else glob_rule
	if rule.is_empty():
		return null
	var has_slash := rule.contains("/")
	var has_wildcard := rule.contains("*") or rule.contains("?")
	var cache_key := ("1" if directory_rule else "0") + rule
	var cached_regex := regex_cache.get_value(cache_key) as RegEx
	if cached_regex != null:
		return cached_regex

	# Rules without a slash may match a complete path segment at any depth.
	var expression := "^(?:.*/)?" if not has_slash else "^"
	var index := 0
	while index < rule.length():
		var character := rule[index]
		if character == "*":
			if index + 1 < rule.length() and rule[index + 1] == "*":
				# `**/` spans zero or more directories; a terminal `**` spans any text.
				index += 1
				if index + 1 < rule.length() and rule[index + 1] == "/":
					expression += "(?:[^/]+/)*"
					index += 1
				else:
					expression += ".*"
			else:
				expression += "[^/]*"
		elif character == "?":
			expression += "[^/.]"
		elif character in [".", "+", "(", ")", "|", "^", "$", "[", "]", "{", "}", "\\"]:
			expression += "\\" + character
		else:
			expression += character
		index += 1

	# Name rules, directory rules, and literal paths all include their descendants.
	if not has_slash or directory_rule or not has_wildcard:
		expression += "(?:/.*)?"
	expression += "$"

	var regex := RegEx.new()
	if regex.compile(expression) != OK:
		return null
	regex_cache.put(cache_key, regex)
	return regex
