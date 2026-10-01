## GlobUtils — file discovery, glob matching, ignore rules, and regex caching.


func glob_skip_rules_test() -> void:
	var root := create_fixture_tree()
	DirAccess.make_dir_recursive_absolute(root.path_join(".cursor/skills/humanizer"))
	FileUtils.write_string_to_file(root.path_join(".cursor/skills/humanizer/skip.gd"), "extends Node\n")
	var skip: Array[String] = [".git", ".cursor/skills/humanizer"]
	var rel := relative_paths(root, GlobUtils.glob(root, "**/*.gd", true, 1_048_576, skip))
	assert(not rel.has(".cursor/skills/humanizer/skip.gd"))
	remove_fixture_tree(root)
	pass


func glob_pattern_test() -> void:
	var root := create_fixture_tree()
	var gd_files := GlobUtils.glob(root, "**/*.gd", true, 1_048_576, [".git"])
	var rel := relative_paths(root, gd_files)
	assert(rel.size() == 3)
	assert(rel.has("root.gd"))
	assert(rel.has("src/a.gd"))
	assert(rel.has("src/nested/c.gd"))
	assert(not rel.has("src/b.txt"))
	remove_fixture_tree(root)
	pass


func glob_non_recursive_test() -> void:
	var root := create_fixture_tree()
	var files := relative_paths(root, GlobUtils.glob(root, "*.gd", false, 0))
	assert(files == ["root.gd"])
	remove_fixture_tree(root)
	pass


func glob_skips_dirs_test() -> void:
	var root := create_fixture_tree()
	var all := GlobUtils.glob(root, "**/*", true, 1_048_576, [".git"])
	var rel := relative_paths(root, all)
	assert(not rel.has(".git/objects/sha"))
	remove_fixture_tree(root)
	pass


func glob_max_file_bytes_test() -> void:
	var root := create_fixture_tree()
	var huge_path := root.path_join("src/huge.bin")
	FileUtils.write_string_to_file(huge_path, "x".repeat(2_000))
	var capped := GlobUtils.glob(root, "**/*", true, 1_000, [".git"])
	var rel := relative_paths(root, capped)
	assert(not rel.has("src/huge.bin"))
	assert(rel.has("src/a.gd"))
	remove_fixture_tree(root)
	pass


func glob_single_file_test() -> void:
	var root := create_fixture_tree()
	var one := root.path_join("src/a.gd")
	var matched := GlobUtils.glob(one, "*.gd")
	assert(matched.size() == 1)
	assert(matched[0] == one)
	var rejected := GlobUtils.glob(one, "*.txt")
	assert(rejected.is_empty())
	remove_fixture_tree(root)
	pass


func glob_treats_hash_and_bang_as_literal_pattern_test() -> void:
	var root := create_fixture_tree()
	DirAccess.make_dir_recursive_absolute(root.path_join("#cache"))
	DirAccess.make_dir_recursive_absolute(root.path_join("!data"))
	FileUtils.write_string_to_file(root.path_join("#cache/item.txt"), "text\n")
	FileUtils.write_string_to_file(root.path_join("!data/item.json"), "{}\n")
	var hash_matches := relative_paths(root, GlobUtils.glob(root, "#cache/*.txt"))
	var bang_matches := relative_paths(root, GlobUtils.glob(root, "!data/*.json"))
	assert(hash_matches == ["#cache/item.txt"])
	assert(bang_matches == ["!data/item.json"])
	remove_fixture_tree(root)
	pass


func glob_match_any_test() -> void:
	var rules: Array[String] = ["# AI", ".dependency/", "*.tmp", ".cursor/skills/humanizer"]
	assert(GlobUtils.glob_match_any(rules, "vendor/out.tmp"))
	assert(GlobUtils.glob_match_any(rules, ".dependency/cache/x"))
	assert(GlobUtils.glob_match_any(rules, ".cursor/skills/humanizer/a.gd"))
	assert(not GlobUtils.glob_match_any(rules, "src/main.gd"))
	assert(not GlobUtils.glob_match_any([], "any/path"))
	assert(not GlobUtils.glob_match_any(["# only comment"], "foo"))
	pass


func glob_match_comments_and_empty_test() -> void:
	assert(not GlobUtils.glob_match("", "any/path"))
	assert(not GlobUtils.glob_match("   ", "any/path"))
	assert(not GlobUtils.glob_match("# AI", ".dependency/cache"))
	assert(not GlobUtils.glob_match("  # comment", "foo"))
	assert(not GlobUtils.glob_match("# .dependency/", ".dependency/x"))
	assert(not GlobUtils.glob_match("", ""))
	pass


func glob_match_empty_path_test() -> void:
	assert(not GlobUtils.glob_match(".dependency/", ""))
	assert(not GlobUtils.glob_match("*.tmp", ""))
	assert(not GlobUtils.glob_match("foo", "   "))
	pass


func glob_match_whitespace_and_negation_test() -> void:
	assert(GlobUtils.glob_match("  .dependency/  ", ".dependency/x"))
	assert(GlobUtils.glob_match("!.agent/", ".agent/session.json"))
	assert(GlobUtils.glob_match("  ! .idea  ", "editor/.idea/ws"))
	assert(not GlobUtils.glob_match("!", "foo"))
	assert(not GlobUtils.glob_match("!   ", "foo"))
	pass


func glob_match_trailing_slash_directory_test() -> void:
	assert(GlobUtils.glob_match(".dependency/", ".dependency"))
	assert(GlobUtils.glob_match(".dependency/", ".dependency/cache/bin"))
	assert(GlobUtils.glob_match(".godot/", ".godot/imported"))
	assert(GlobUtils.glob_match(".import/", ".import/foo"))
	assert(GlobUtils.glob_match("data_*/", "data_foo"))
	assert(GlobUtils.glob_match("data_*/", "data_foo/bar/baz"))
	# Directory-name rules match that segment at any depth (same as GlobTool skip dir names).
	assert(GlobUtils.glob_match(".dependency/", "other/.dependency/x"))
	pass


func glob_match_literal_path_prefix_test() -> void:
	assert(GlobUtils.glob_match(".cursor/skills/humanizer", ".cursor/skills/humanizer"))
	assert(GlobUtils.glob_match(".cursor/skills/humanizer", ".cursor/skills/humanizer/skip.gd"))
	assert(GlobUtils.glob_match(".cursor/skills/humanizer-zh", ".cursor/skills/humanizer-zh/readme.md"))
	assert(not GlobUtils.glob_match(".cursor/skills/humanizer", ".cursor/skills/humanizer_extra/x"))
	assert(not GlobUtils.glob_match(".cursor/skills/humanizer", ".cursor/skills/other/x"))
	assert(not GlobUtils.glob_match(".cursor/skills/humanizer", "prefix/.cursor/skills/humanizer/x"))
	pass


func glob_match_literal_name_any_level_test() -> void:
	assert(GlobUtils.glob_match(".idea", ".idea"))
	assert(GlobUtils.glob_match(".idea", "editor/.idea"))
	assert(GlobUtils.glob_match(".idea", "editor/.idea/workspace.xml"))
	assert(GlobUtils.glob_match(".vscode", "tools/.vscode/settings.json"))
	assert(GlobUtils.glob_match("export.cfg", "export.cfg"))
	assert(GlobUtils.glob_match("export.cfg", "sub/export.cfg"))
	assert(GlobUtils.glob_match(".nomedia", "assets/.nomedia"))
	assert(GlobUtils.glob_match(".agent", ".agent/foo"))
	assert(not GlobUtils.glob_match(".idea", "notidea"))
	assert(not GlobUtils.glob_match("export.cfg", "export.cfg.bak"))
	pass


func glob_match_wildcard_basename_test() -> void:
	assert(GlobUtils.glob_match("*.tmp", "scratch.tmp"))
	assert(GlobUtils.glob_match("*.tmp", "build/out.tmp"))
	assert(not GlobUtils.glob_match("*.tmp", "build/out.txt"))
	assert(GlobUtils.glob_match("*.translation", "ui/menu.translation"))
	assert(not GlobUtils.glob_match("*.translation", "ui/menu.csv"))
	assert(GlobUtils.glob_match("mono_crash.*.json", "logs/mono_crash.abc.json"))
	assert(not GlobUtils.glob_match("mono_crash.*.json", "logs/crash.json"))
	assert(GlobUtils.glob_match("*.suo", "proj/foo.suo"))
	assert(GlobUtils.glob_match("*.njsproj", "app/bar.njsproj"))
	assert(GlobUtils.glob_match("*.sln", "game.sln"))
	pass


func glob_match_wildcard_single_char_test() -> void:
	# Godot String.match: ? does not match '.'
	assert(GlobUtils.glob_match("*.sw?", "lib.swf"))
	assert(not GlobUtils.glob_match("*.sw?", "lib.sw"))
	pass


func glob_match_wildcard_path_segment_test() -> void:
	assert(GlobUtils.glob_match("data_*", "data_foo"))
	assert(GlobUtils.glob_match("data_*", "data_foo/bar"))
	assert(GlobUtils.glob_match("data_*", "src/data_bar/baz"))
	assert(not GlobUtils.glob_match("data_*", "nodata_foo"))
	pass


func glob_match_wildcard_with_slash_test() -> void:
	assert(GlobUtils.glob_match("agent/*.gd", "agent/ReadTool.gd"))
	assert(not GlobUtils.glob_match("agent/*.gd", "agent/tools/ReadTool.gd"))
	assert(GlobUtils.glob_match("**/*.gd", "agent/tools/ReadTool.gd"))
	assert(GlobUtils.glob_match("**/*.gd", "ReadTool.gd"))
	assert(not GlobUtils.glob_match("**/*.gd", "agent/tools/ReadTool.txt"))
	assert(GlobUtils.glob_match("foo/*/", "foo/bar/file.txt"))
	assert(not GlobUtils.glob_match("foo/*/", "other/bar/file.txt"))
	pass


func glob_match_backslash_normalization_test() -> void:
	assert(GlobUtils.glob_match(".dependency\\", ".dependency\\cache\\x"))
	assert(GlobUtils.glob_match(".cursor/skills/humanizer", ".cursor\\skills\\humanizer\\a.gd"))
	pass


func glob_match_repo_gitignore_rules_stay_in_sync_test() -> void:
	var actual_rules: Array[String] = []
	for line in FileUtils.read_file_to_lines("res://.gitignore"):
		var rule := line.strip_edges()
		if not rule.is_empty() and not rule.begins_with("#"):
			actual_rules.append(rule)
	var expected_rules: Array[String] = [
		".gai/", ".dependency/", ".cursor/",
		"cpp/**/*.obj", "cpp/**/*.os", "cpp/**/*.o", "cpp/**/*.a", "cpp/**/*.lib",
		"cpp/**/*.exp", "cpp/**/*.ilk", "cpp/**/*.pdb",
		"cpp/.sconsign.dblite", "cpp/.sconsign.dblite.*", "cpp/bin/**/~*",
		".godot/**", "!.godot/extension_list.cfg", ".nomedia",
		".import/", "export.cfg", "export_credentials.cfg", "*.tmp",
		"*.translation", ".mono/", "data_*/", "mono_crash.*.json",
		".idea", ".vscode", "*.suo", "*.ntvs*", "*.njsproj", "*.sln", "*.sw?",
	]
	assert(actual_rules == expected_rules)
	pass


func glob_match_repo_gitignore_positive_cases_test() -> void:
	var cases: Array = [
		[".gai/", ".gai/cache/state.json"],
		[".dependency/", "src/.dependency/vendor/lib.bin"],
		[".cursor/", ".cursor/skills/humanizer/SKILL.md"],
		["cpp/**/*.obj", "cpp/src/global_hotkey.windows.template_debug.x86_64.obj"],
		["cpp/**/*.lib", "cpp/bin/windows/gai_cpp.windows.template_debug.x86_64.lib"],
		["cpp/.sconsign.dblite", "cpp/.sconsign.dblite"],
		["cpp/.sconsign.dblite.*", "cpp/.sconsign.dblite.1"],
		["cpp/bin/**/~*", "cpp/bin/windows/~gai_cpp.windows.template_debug.x86_64.dll"],
		[".godot/**", ".godot/imported/asset.ctex"],
		["!.godot/extension_list.cfg", ".godot/extension_list.cfg"],
		[".nomedia", "assets/.nomedia"],
		[".import/", "addons/.import/resource"],
		["export.cfg", "build/export.cfg"],
		["export_credentials.cfg", "export_credentials.cfg"],
		["*.tmp", "obj/debug.tmp"],
		["*.translation", "locale/menu.translation"],
		[".mono/", ".mono/metadata/assemblies"],
		["data_*/", "bin/data_debug/cache/file"],
		["mono_crash.*.json", "logs/mono_crash.2026.json"],
		[".idea", "editor/.idea/workspace.xml"],
		[".vscode", ".vscode/settings.json"],
		["*.suo", "solution/user.suo"],
		["*.ntvs*", "solution/project.ntvs_analysis"],
		["*.njsproj", "web/app.njsproj"],
		["*.sln", "game.sln"],
		["*.sw?", "library.swf"],
	]
	for row in cases:
		var rule: String = row[0]
		var path: String = row[1]
		assert(GlobUtils.glob_match(rule, path))
	pass


func glob_match_repo_gitignore_negative_cases_test() -> void:
	var cases: Array = [
		[".gai/", ".gaia/cache"],
		[".dependency/", "dependency/cache"],
		[".cursor/", "cursor/skills/SKILL.md"],
		["cpp/**/*.obj", "cpp/src/global_hotkey.cpp"],
		["cpp/**/*.lib", "cpp/bin/windows/gai_cpp.windows.template_debug.x86_64.dll"],
		["cpp/.sconsign.dblite.*", "cpp/.sconsign.dblite"],
		["cpp/bin/**/~*", "cpp/bin/windows/gai_cpp.windows.template_debug.x86_64.dll"],
		[".godot/**", ".godot_backup/imported"],
		["!.godot/extension_list.cfg", ".godot/imported/asset.ctex"],
		[".nomedia", "assets/.nomedia.txt"],
		["export.cfg", "export.cfg.bak"],
		["*.tmp", "readme.tmp.md"],
		["*.translation", "locale/translation.csv"],
		["data_*/", "bin/database/cache"],
		["mono_crash.*.json", "logs/mono_crash.json.bak"],
		[".idea", "editor/.idea_backup/workspace.xml"],
		["*.suo", "solution/user.suo.bak"],
		["*.ntvs*", "solution/project.nvts"],
		["*.njsproj", "web/app.njsproj.json"],
		["*.sln", "game.slnx"],
		["*.sw?", "library.sw"],
	]
	for row in cases:
		var rule: String = row[0]
		var path: String = row[1]
		assert(not GlobUtils.glob_match(rule, path))
	pass


func glob_match_any_repo_gitignore_test() -> void:
	var rules: Array[String] = []
	for line in FileUtils.read_file_to_lines("res://.gitignore"):
		var rule := line.strip_edges()
		if not rule.is_empty():
			rules.append(rule)
	assert(GlobUtils.glob_match_any(rules, ".godot/imported/icon.ctex"))
	assert(GlobUtils.glob_match_any(rules, "src/data_debug/cache.bin"))
	assert(GlobUtils.glob_match_any(rules, "project/game.sln"))
	assert(not GlobUtils.glob_match_any(rules, "script/main.gd"))
	assert(not GlobUtils.glob_match_any(rules, "README.md"))
	pass


static func relative_paths(search_root: String, files: Array[String]) -> Array[String]:
	var rel: Array[String] = []
	var root := search_root.replace("\\", "/").rstrip("/")
	for file_path in files:
		var normalized_path := file_path.replace("\\", "/")
		rel.append(normalized_path.substr(root.length() + 1))
	return rel


static func create_fixture_tree() -> String:
	var root := ProjectSettings.globalize_path("user://globutils_" + str(TimeUtils.now()) + "_" + str(randi()))
	DirAccess.make_dir_recursive_absolute(root.path_join("src/nested"))
	DirAccess.make_dir_recursive_absolute(root.path_join(".git/objects"))
	FileUtils.write_string_to_file(root.path_join("root.gd"), "extends Node\n")
	FileUtils.write_string_to_file(root.path_join("src/a.gd"), "extends Node\n")
	FileUtils.write_string_to_file(root.path_join("src/b.txt"), "text\n")
	FileUtils.write_string_to_file(root.path_join("src/nested/c.gd"), "extends Node\n")
	FileUtils.write_string_to_file(root.path_join(".git/objects/sha"), "git\n")
	return root


static func remove_fixture_tree(root: String) -> void:
	FileUtils.delete_file_or_directory(root)
	pass
