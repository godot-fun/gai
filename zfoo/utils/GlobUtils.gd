## Glob matching and recursive file discovery with a bounded compiled-RegEx cache.
## Paths are normalized to forward slashes before matching.
class_name GlobUtils
extends Object

## Keeps repeated ignore rules cheap without allowing unbounded process-lifetime growth.
const REGEX_CACHE_MAX_SIZE: int = 256

static var regex_cache := LruCacheString.new(REGEX_CACHE_MAX_SIZE)


# ---------------------------------------------------------------------------
# File discovery
# ---------------------------------------------------------------------------

## Finds paths under [param search_root] whose relative path matches [param glob_pattern].
## Set [param recursive] to [code]false[/code] to search only the root folder.
## Uses breadth-first traversal and skips files larger than [param max_file_bytes]; [code]0[/code] disables the limit.
##
## [param skip_glob_rules] is an ordered .gitignore rule list; see the ignore section at the bottom of this file.
## Set [param include_directories] to also return matched folders with a trailing [code]/[/code].
## [param max_entries] stops the walk once that many paths are collected. Results are sorted by path.
static func glob(search_root: String, glob_pattern: String, recursive: bool = true, max_file_bytes: int = 0, skip_glob_rules: Array[String] = [], include_directories: bool = false, max_entries: int = 4096) -> Array[String]:
	var paths: Array[String] = []
	var pattern := glob_pattern.strip_edges().replace("\\", "/")
	var pattern_has_path := pattern.contains("/")
	var ignore_rules := gitignore_parse_rules(skip_glob_rules)
	if FileAccess.file_exists(search_root):
		var file_name := search_root.replace("\\", "/").get_file()
		if (pattern.is_empty() or glob_match(pattern, file_name, false)) and (max_file_bytes <= 0 or FileAccess.get_size(search_root) <= max_file_bytes):
			paths.append(search_root)
		return paths
	if not DirAccess.dir_exists_absolute(search_root):
		return paths

	var normalized_root := search_root.replace("\\", "/")
	var root_prefix := normalized_root if normalized_root.ends_with("/") else normalized_root + "/"
	var folders: Array[String] = [search_root]
	var folder_index := 0
	while folder_index < folders.size() and paths.size() < max_entries:
		var folder_path := folders[folder_index]
		folder_index += 1
		var dir := DirAccess.open(folder_path)
		if dir == null:
			continue
		for file_name in dir.get_files():
			if paths.size() >= max_entries:
				break
			var file_path := folder_path.path_join(file_name)
			if max_file_bytes > 0 and FileAccess.get_size(file_path) > max_file_bytes:
				continue
			var relative_path := file_path.replace("\\", "/").substr(root_prefix.length())
			if not ignore_rules.is_empty() and gitignore_last_match(ignore_rules, relative_path, false):
				continue
			var match_path := relative_path if pattern_has_path else file_name
			if pattern.is_empty() or glob_match(pattern, match_path, false):
				paths.append(file_path)
		if recursive:
			for dir_name in dir.get_directories():
				if paths.size() >= max_entries:
					break
				var child_path := folder_path.path_join(dir_name)
				var relative_child := child_path.replace("\\", "/").substr(root_prefix.length())
				if not ignore_rules.is_empty() and not gitignore_may_descend(ignore_rules, relative_child):
					continue
				var match_child := relative_child if pattern_has_path else dir_name
				if include_directories and (pattern.is_empty() or glob_match(pattern, match_child, false)):
					if ignore_rules.is_empty() or not gitignore_last_match(ignore_rules, relative_child, true):
						paths.append(child_path.replace("\\", "/") + "/")
				folders.append(child_path)
		if folder_index >= 1024 and folder_index * 2 >= folders.size():
			folders = folders.slice(folder_index)
			folder_index = 0
	paths.sort()
	return paths


# ---------------------------------------------------------------------------
# Glob pattern matching
# ---------------------------------------------------------------------------

## Returns true when [param path_or_file] matches any rule pattern (ignores negation and rule order).
## Prefer [method gitignore_is_ignored] for skip lists.
static func glob_match_any(glob_rules: Array[String], path_or_file: String) -> bool:
	for glob_rule in glob_rules:
		if glob_match(glob_rule, path_or_file):
			return true
	return false


## Matches one ignore-file or glob line against a path.
## Set [param parse_ignore_syntax] to [code]false[/code] so leading [code]#[/code] and [code]![/code] stay literal.
static func glob_match(glob_rule: String, path_or_file: String, parse_ignore_syntax: bool = true) -> bool:
	var rule := glob_rule.strip_edges()
	if rule.is_empty() or (parse_ignore_syntax and rule.begins_with("#")):
		return false
	if parse_ignore_syntax and rule.begins_with("!"):
		rule = rule.substr(1).strip_edges()
		if rule.is_empty():
			return false
	return glob_match_pattern(rule.replace("\\", "/").strip_edges(), path_or_file.replace("\\", "/").strip_edges(), false)


## Matches a normalized glob or ignore pattern (no [code]![/code] prefix) against a normalized path.
static func glob_match_pattern(pattern: String, path: String, is_directory: bool) -> bool:
	var rule := pattern.strip_edges().replace("\\", "/")
	var path_normalized := path.strip_edges().replace("\\", "/")
	if rule.is_empty() or path_normalized.is_empty():
		return false
	var directory_rule := rule.ends_with("/")
	var anchored_root := rule.begins_with("/")
	if anchored_root:
		rule = rule.substr(1).strip_edges()
		if rule.is_empty():
			return false
	var name_rule := rule.trim_suffix("/")
	if not anchored_root and not name_rule.is_empty() and not name_rule.contains("/") and not name_rule.contains("*") and not name_rule.contains("?") and not name_rule.contains("["):
		return path_normalized == name_rule or path_normalized.begins_with(name_rule + "/") or path_normalized.ends_with("/" + name_rule) or path_normalized.contains("/" + name_rule + "/")
	var regex := get_or_compile_regex(rule, directory_rule, anchored_root)
	return regex != null and regex.search(path_normalized) != null


# ---------------------------------------------------------------------------
# Glob pattern → RegEx
# ---------------------------------------------------------------------------

## Compiles one normalized glob rule and infers directory semantics from a trailing [code]/[/code].
## Cache hits refresh the expression's LRU position.
static func get_or_compile_regex(glob_rule: String, directory_rule: bool = false, anchored_root: bool = false) -> RegEx:
	var rule := glob_rule.trim_suffix("/").strip_edges() if directory_rule else glob_rule.strip_edges()
	if rule.is_empty():
		return null
	var has_slash := rule.contains("/")
	var has_wildcard := rule.contains("*") or rule.contains("?")
	var cache_key := ("a" if anchored_root else "r") + ("1" if directory_rule else "0") + rule
	var cached_regex := regex_cache.get_value(cache_key) as RegEx
	if cached_regex != null:
		return cached_regex

	var expression := "^" if anchored_root or has_slash else "^(?:.*/)?"
	var index := 0
	while index < rule.length():
		var character := rule[index]
		if character == "*":
			if index + 1 < rule.length() and rule[index + 1] == "*":
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

	if not anchored_root and (not has_slash or directory_rule or not has_wildcard):
		expression += "(?:/.*)?"
	elif anchored_root and (directory_rule or not has_wildcard):
		expression += "(?:/.*)?"
	expression += "$"

	var regex := RegEx.new()
	if regex.compile(expression) != OK:
		return null
	regex_cache.put_if_absent(cache_key, regex)
	return regex


# ---------------------------------------------------------------------------
# .gitignore skip rules — ordered lines, last match wins, `!` un-ignores
#
# Used by [method glob] ([param skip_glob_rules]) and [method gitignore_is_ignored].
# Blank lines and `#` comments are skipped. During a walk, ignored files are dropped;
# ignored directories are skipped unless a later negated rule could match a path under
# them (for example `.godot/**` together with `!.godot/extension_list.cfg`).
# ---------------------------------------------------------------------------

## [code]true[/code] when [param ignore_rules] ignore [param relative_path] (last matching rule wins).
static func gitignore_is_ignored(ignore_rules: Array[String], relative_path: String, is_directory: bool = false) -> bool:
	var path := relative_path.replace("\\", "/").strip_edges()
	if path.is_empty():
		return false
	var ignored := false
	var matched := false
	for line in ignore_rules:
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		var negated := trimmed.begins_with("!")
		var rule := trimmed.substr(1).strip_edges() if negated else trimmed
		if rule.is_empty():
			continue
		rule = rule.replace("\\", "/").strip_edges()
		if glob_match_pattern(rule, path, is_directory):
			ignored = not negated
			matched = true
	return ignored if matched else false


## Parses [param skip_glob_rules] once per [method glob] walk.
static func gitignore_parse_rules(skip_glob_rules: Array[String]) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	for line in skip_glob_rules:
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		var negated := trimmed.begins_with("!")
		var pattern := trimmed.substr(1).strip_edges() if negated else trimmed
		if pattern.is_empty():
			continue
		parsed.append({"negated": negated, "pattern": pattern.replace("\\", "/").strip_edges()})
	return parsed


## Last matching parsed rule decides whether [param relative_path] is ignored.
static func gitignore_last_match(parsed_rules: Array[Dictionary], relative_path: String, is_directory: bool) -> bool:
	var path := relative_path.replace("\\", "/").strip_edges()
	if path.is_empty():
		return false
	var ignored := false
	var matched := false
	for rule in parsed_rules:
		if glob_match_pattern(rule["pattern"], path, is_directory):
			ignored = not rule["negated"]
			matched = true
	return ignored if matched else false


## [code]true[/code] when the walk should enter [param relative_dir] despite it being ignored.
static func gitignore_may_descend(parsed_rules: Array[Dictionary], relative_dir: String) -> bool:
	var path := relative_dir.replace("\\", "/").strip_edges().trim_suffix("/")
	if path.is_empty() or not gitignore_last_match(parsed_rules, path, true):
		return true
	var prefix := path + "/"
	for rule in parsed_rules:
		if not rule["negated"]:
			continue
		var neg_rule := rule["pattern"] as String
		if neg_rule.is_empty():
			continue
		if neg_rule.begins_with("/"):
			neg_rule = neg_rule.substr(1).strip_edges()
		if not neg_rule.contains("/"):
			return true
		neg_rule = neg_rule.trim_suffix("/")
		if neg_rule.contains("*") or neg_rule.contains("?"):
			if glob_match_pattern(neg_rule, prefix + "x", false):
				return true
		elif neg_rule.begins_with(prefix) or prefix.begins_with(neg_rule.split("/")[0] + "/"):
			return true
	return false
