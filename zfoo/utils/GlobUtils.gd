## Glob matching and recursive file discovery with a bounded compiled-RegEx cache.
## Paths are normalized to forward slashes before matching. Walks run on worker threads
## ([method async_glob], and [method glob] from [method ExecutorHelper.async_execute_pooled] tasks), so the
## cache below is shared across threads and [LruCacheString] guards it with its own lock.
class_name GlobUtils
extends Object

## Keeps repeated ignore rules cheap without allowing unbounded process-lifetime growth.
const REGEX_CACHE_MAX_SIZE: int = 512

## Shared by every walk: one on the worker pool and one on the single-thread executor can compile the same
## rule at the same time, so the cache is only touched through its thread-safe methods.
static var regex_cache := LruCacheString.new(REGEX_CACHE_MAX_SIZE)


# ---------------------------------------------------------------------------
# File discovery
# ---------------------------------------------------------------------------

## Finds paths under [param search_root] whose relative path matches [param glob_pattern].
## The walk runs on [method ExecutorHelper.async_execute], so a large tree never blocks the main thread.
## Call this method from the main thread; inside a worker task use [method glob] instead.
##
## Set [param recursive] to [code]false[/code] to search only the root folder.
## Uses breadth-first traversal and skips files larger than [param max_file_bytes]; [code]0[/code] disables the limit.
##
## [param skip_glob_rules] is an ordered .gitignore rule list; see the ignore section at the bottom of this file.
## Set [param include_directories] to also return matched folders with a trailing [code]/[/code].
## [param max_entries] stops the walk once that many paths are collected. Results are sorted by path.
static func async_glob(search_root: String, glob_pattern: String, recursive: bool = true, max_file_bytes: int = 0, skip_glob_rules: Array[String] = [], include_directories: bool = false, max_entries: int = 4096) -> Array[String]:
	return await ExecutorHelper.async_execute(glob.bind(search_root, glob_pattern, recursive, max_file_bytes, skip_glob_rules, include_directories, max_entries))


## Same walk as [method async_glob] on the calling thread. Use it from worker tasks
## ([method ExecutorHelper.async_execute_pooled] / [method ExecutorHelper.execute]) where
## [method async_glob] cannot wait for main-thread frames.
static func glob(search_root: String, glob_pattern: String, recursive: bool = true, max_file_bytes: int = 0, skip_glob_rules: Array[String] = [], include_directories: bool = false, max_entries: int = 4096) -> Array[String]:
	var paths: Array[String] = []
	var pattern := glob_pattern.strip_edges().replace("\\", "/")
	var pattern_has_path := pattern.contains("/")
	var skip: GitIgnoreMatcher = null
	if not skip_glob_rules.is_empty():
		skip = GitIgnoreMatcher.from_lines(skip_glob_rules)

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
			if skip != null and skip.is_ignored(relative_path, false):
				continue
			var match_path := relative_path if pattern_has_path else file_name
			if pattern.is_empty() or glob_match(pattern, match_path, false):
				paths.append(file_path)
		if recursive:
			for dir_name in dir.get_directories():
				if paths.size() >= max_entries:
					break
				var child_path := folder_path.path_join(dir_name)
				var normalized_child := child_path.replace("\\", "/")
				var relative_child := normalized_child.substr(root_prefix.length())
				if skip != null and not skip.may_enter_dir(relative_child):
					continue
				var match_child := relative_child if pattern_has_path else dir_name
				if include_directories and (pattern.is_empty() or glob_match(pattern, match_child, false)):
					if skip == null or not skip.is_ignored(relative_child, true):
						paths.append(normalized_child + "/")
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
	# Another worker may have compiled the same rule while this one did, and the cache stores whichever
	# expression won, so the cached one is the answer.
	return regex_cache.get_or_put(cache_key, regex) as RegEx


# ---------------------------------------------------------------------------
# .gitignore skip rules
# ---------------------------------------------------------------------------

## true when ignore_rules exclude relative_path. Same last-match and ! rules as GitIgnoreMatcher.
static func gitignore_is_ignored(ignore_rules: Array[String], relative_path: String, is_directory: bool = false) -> bool:
	return GitIgnoreMatcher.from_lines(ignore_rules).is_ignored(relative_path, is_directory)


class GitIgnoreRule extends RefCounted:
	## false for *.tmp; true for a negated source line !keep.tmp (un-ignore when this rule wins last).
	var negated: bool = false
	## Pattern text without leading ! (e.g. node_modules/, .env.example).
	var pattern: String = ""

	func _init(p_negated: bool, p_pattern: String) -> void:
		negated = p_negated
		pattern = p_pattern.replace("\\", "/").strip_edges()
		pass


## .gitignore-style skip lines for GlobUtils.glob / async_glob and gitignore_is_ignored.
##
## Same as Git for is_ignored: skip blanks and # lines; last match wins; ! un-ignores; glob patterns via glob_match_pattern.
##
## Walk-only difference (may_enter_dir) — only how ! interacts with already-ignored directories:
## 1. ! with no / in the pattern (e.g. !.env.example): last-match still applies on paths the walk already hit; never descends into an ignored dir just because this rule exists (.dependency/, node_modules/, … stay pruned).
## 2. ! with / in the pattern (e.g. !.godot/extension_list.cfg): may descend into that ignored directory so the exception file can appear in the glob result.
class GitIgnoreMatcher extends RefCounted:
	var rules: Array[GitIgnoreRule] = []

	static func from_lines(lines: Array[String]) -> GitIgnoreMatcher:
		var matcher := GitIgnoreMatcher.new()
		for line in lines:
			var trimmed := line.strip_edges()
			if trimmed.is_empty() or trimmed.begins_with("#"):
				continue
			var negated := trimmed.begins_with("!")
			var pattern := trimmed.substr(1).strip_edges() if negated else trimmed
			if pattern.is_empty():
				continue
			matcher.rules.append(GitIgnoreRule.new(negated, pattern))
		return matcher

	func is_ignored(relative_path: String, is_directory: bool = false) -> bool:
		var path := relative_path.replace("\\", "/").strip_edges()
		if path.is_empty():
			return false
		for index in range(rules.size() - 1, -1, -1):
			var rule := rules[index]
			if GlobUtils.glob_match_pattern(rule.pattern, path, is_directory):
				return not rule.negated
		return false

	func may_enter_dir(relative_dir: String) -> bool:
		var path := relative_dir.replace("\\", "/").strip_edges().trim_suffix("/")
		if path.is_empty() or not is_ignored(path, true):
			return true
		var head := path + "/"
		for rule in rules:
			if not rule.negated:
				continue
			var neg := rule.pattern
			if neg.begins_with("/"):
				neg = neg.substr(1).strip_edges()
			if not neg.contains("/"):
				continue
			if neg.begins_with(head) or (neg.contains("*") and GlobUtils.glob_match_pattern(neg, head + "x", false)):
				return true
		return false
