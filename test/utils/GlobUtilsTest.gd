## GlobUtils — file discovery, glob matching, RegEx cache, and .gitignore skip semantics.


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
	assert(GlobUtils.glob_match(".dependency\\", r".dependency\cache\x"))
	assert(GlobUtils.glob_match(".cursor/skills/humanizer", r".cursor\skills\humanizer\a.gd"))
	pass


func glob_match_repo_gitignore_positive_cases_test() -> void:
	var cases: Array = [
		[".gai/", ".gai/cache/state.json"],
		[".dependency/", "src/.dependency/vendor/lib.bin"],
		["web/node_modules/", "web/node_modules/react/index.js"],
		["web/dist/", "web/dist/assets/app.js"],
		["web/build/", "web/build/app.js"],
		["web/coverage/", "web/coverage/lcov.info"],
		["web/.cache/", "web/.cache/build.json"],
		["web/.npm/", "web/.npm/cache.json"],
		[".cloakbrowser/", ".cloakbrowser/session.json"],
		[".user_data/", ".user_data/cache/state.json"],
		["web/.eslintcache", "web/.eslintcache"],
		["web/*.tsbuildinfo", "web/app.tsbuildinfo"],
		["web/.env", "web/.env"],
		["web/.env.*", "web/.env.production"],
		["!web/.env.example", "web/.env.example"],
		["npm-debug.log*", "npm-debug.log.123"],
		["yarn-debug.log*", "yarn-debug.log"],
		["yarn-error.log*", "yarn-error.log.1"],
		["pnpm-debug.log*", "pnpm-debug.log"],
		[".cursor/", ".cursor/skills/humanizer/SKILL.md"],
		["__pycache__/", ".ai/common/__pycache__/output_utils.cpython-314.pyc"],
		["*.pyc", "cpp/__pycache__/methods.pyc"],
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
		[".vs", "editor/.vs/FileContentIndex/cache.vsidx"],
		["*.suo", "solution/user.suo"],
		["*.ntvs*", "solution/project.ntvs_analysis"],
		["*.njsproj", "web/app.njsproj"],
		["*.sln", "game.sln"],
		["*.slnx", "gai.slnx"],
		[".DS_Store", "mac/folder/.DS_Store"],
		["Thumbs.db", "image/Thumbs.db"],
		["desktop.ini", "asset/desktop.ini"],
		["*.bak", "src/main.gd.bak"],
		["*.orig", "src/main.gd.orig"],
		["*.rej", "patch.rej"],
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


func gitignore_is_ignored_last_rule_wins_test() -> void:
	var rules: Array[String] = ["*.tmp", "!keep.tmp", "build/", "!build/public/"]
	assert(GlobUtils.gitignore_is_ignored(rules, "scratch.tmp"))
	assert(not GlobUtils.gitignore_is_ignored(rules, "keep.tmp"))
	assert(GlobUtils.gitignore_is_ignored(rules, "build/out.txt"))
	assert(not GlobUtils.gitignore_is_ignored(rules, "build/public/index.html"))
	pass


func gitignore_is_ignored_repo_order_test() -> void:
	var rules: Array[String] = []
	for line in FileUtils.read_file_to_lines("res://.gitignore"):
		var rule := line.strip_edges()
		if not rule.is_empty() and not rule.begins_with("#"):
			rules.append(rule)
	assert(GlobUtils.gitignore_is_ignored(rules, ".godot/imported/icon.ctex"))
	assert(not GlobUtils.gitignore_is_ignored(rules, ".godot/extension_list.cfg"))
	assert(not GlobUtils.gitignore_is_ignored(rules, "script/main.gd"))
	pass


func glob_gitignore_skips_files_test() -> void:
	var root := create_fixture_tree()
	FileUtils.write_string_to_file(root.path_join("scratch.tmp"), "x\n")
	FileUtils.write_string_to_file(root.path_join("keep.tmp"), "x\n")
	var rules: Array[String] = ["*.tmp", "!keep.tmp"]
	var rel := relative_paths(root, GlobUtils.glob(root, "**/*", true, 0, rules))
	assert(not rel.has("scratch.tmp"))
	assert(rel.has("keep.tmp"))
	remove_fixture_tree(root)
	pass


func glob_match_anchored_root_pattern_test() -> void:
	assert(GlobUtils.glob_match("/debug.log", "debug.log"))
	assert(not GlobUtils.glob_match("/debug.log", "tools/debug.log"))
	assert(GlobUtils.glob_match("/build/", "build/out.txt"))
	assert(not GlobUtils.glob_match("/build/", "other/build/out.txt"))
	pass


## `include_directories` turns the same walk into a browsable tree: folders come back with a trailing
## `/`, right before the entries they hold, and the skip rules prune them with their whole subtree.
func glob_include_directories_test() -> void:
	var root := create_fixture_tree()
	var tree := relative_paths(root, GlobUtils.glob(root, "", true, 0, [".git"], true))
	assert(tree == ["root.gd", "src/", "src/a.gd", "src/b.txt", "src/nested/", "src/nested/c.gd"], str(tree))
	# The default stays file-only, so GlobTool and GrepTool keep seeing exactly what they saw before.
	var files := relative_paths(root, GlobUtils.glob(root, "", true, 0, [".git"]))
	assert(files == ["root.gd", "src/a.gd", "src/b.txt", "src/nested/c.gd"], str(files))
	remove_fixture_tree(root)
	pass


func glob_include_directories_skip_rules_test() -> void:
	var root := create_fixture_tree()
	DirAccess.make_dir_recursive_absolute(root.path_join(".cursor/skills/humanizer"))
	FileUtils.write_string_to_file(root.path_join(".cursor/skills/humanizer/skip.gd"), "extends Node\n")
	DirAccess.make_dir_recursive_absolute(root.path_join("node_modules/pkg"))
	FileUtils.write_string_to_file(root.path_join("node_modules/pkg/index.js"), "x\n")
	var tree := relative_paths(root, GlobUtils.glob(root, "", true, 0, [".git", ".cursor/skills/humanizer", "node_modules/"], true))
	# A path rule, a name rule and a directory rule all drop the folder, its rows and its subtree; its
	# parents stay rows, because only the ignored folder is missing.
	assert(tree.has(".cursor/skills/"), str(tree))
	assert(not tree.has(".cursor/skills/humanizer/"), str(tree))
	assert(not tree.has(".cursor/skills/humanizer/skip.gd"))
	assert(not tree.has("node_modules/"))
	assert(not tree.has("node_modules/pkg/index.js"))
	assert(tree.has("src/nested/"))
	remove_fixture_tree(root)
	pass


func glob_caps_test() -> void:
	var root := create_fixture_tree()
	# `max_entries` stops the walk itself; its 4096 default is far past a fixture-sized tree.
	assert(GlobUtils.glob(root, "", true, 0, [".git"], true, 2).size() == 2)
	assert(GlobUtils.glob(root, "", true, 0, [".git"], true).size() == 6)
	assert(GlobUtils.glob(root.path_join("missing"), "", true, 0, [".git"], true).is_empty())
	remove_fixture_tree(root)
	pass


# ---------------------------------------------------------------------------
# .gitignore — [method GlobUtils.gitignore_is_ignored] and [method GlobUtils.glob] skip rules
#
# Syntax coverage in this section:
# - Comments (#) and blank lines; line trim
# - Negation (!) and last-match-wins ordering
# - `*` (one segment), `?`, `**`, `**/`, `/**`, `**/*.ext`, `prefix/**`
# - Trailing `/` directory rules; name rules without `/` (any depth)
# - Leading `/` root-anchored rules
# - Slash patterns relative to repo root (not parent-prefix)
# - Literal `[` `]` `{` `}` (no char-class / brace expansion)
# - Escaped regex metacharacters in patterns (`.`, `+`, `(`, `)`, `$`, …)
# - `tmp*`, `*.tmp.*`, `npm-debug.log*`-style suffix stars
# - Path-shaped `!` opens ignored dirs during [method GlobUtils.glob] walks
# - [method GlobUtils.glob] + ignore + search pattern + include_directories
# - Full `res://.gitignore` rule list spot checks
# ---------------------------------------------------------------------------

func gitignore_no_matching_rule_test() -> void:
	var rules: Array[String] = ["*.tmp", "build/"]
	assert(not GlobUtils.gitignore_is_ignored(rules, "src/main.gd"))
	assert(not GlobUtils.gitignore_is_ignored(rules, "readme.md"))
	assert(not GlobUtils.gitignore_is_ignored(rules, ""))
	pass


func gitignore_skips_comments_and_blank_lines_test() -> void:
	var rules: Array[String] = ["", "  ", "# ignore build", "*.log", "# *.gd", "   # tail"]
	assert(GlobUtils.gitignore_is_ignored(rules, "app.log"))
	assert(not GlobUtils.gitignore_is_ignored(rules, "app.gd"))
	pass


func gitignore_last_match_wins_sequence_test() -> void:
	var rules: Array[String] = ["src/**", "!src/a.gd"]
	assert(not GlobUtils.gitignore_is_ignored(rules, "root.gd"))
	assert(not GlobUtils.gitignore_is_ignored(rules, "tools/helper.gd"))
	assert(not GlobUtils.gitignore_is_ignored(rules, "src/a.gd"))
	assert(GlobUtils.gitignore_is_ignored(rules, "src/nested/c.gd"))
	pass


func gitignore_negation_unignores_only_when_last_test() -> void:
	var rules: Array[String] = ["*.tmp", "!keep.tmp", "*.tmp"]
	assert(GlobUtils.gitignore_is_ignored(rules, "keep.tmp"))
	assert(GlobUtils.gitignore_is_ignored(rules, "drop.tmp"))
	rules = ["*.tmp", "!keep.tmp"]
	assert(not GlobUtils.gitignore_is_ignored(rules, "keep.tmp"))
	pass


func gitignore_env_and_secret_patterns_test() -> void:
	var rules: Array[String] = [".env", ".env.*", "!.env.example", "!.env.sample"]
	assert(GlobUtils.gitignore_is_ignored(rules, ".env"))
	assert(GlobUtils.gitignore_is_ignored(rules, ".env.local"))
	assert(GlobUtils.gitignore_is_ignored(rules, "web/.env.production"))
	assert(not GlobUtils.gitignore_is_ignored(rules, ".env.example"))
	assert(not GlobUtils.gitignore_is_ignored(rules, "config/.env.sample"))
	pass


func gitignore_root_anchored_rules_test() -> void:
	var rules: Array[String] = ["/debug.log", "/build/"]
	assert(GlobUtils.gitignore_is_ignored(rules, "debug.log"))
	assert(not GlobUtils.gitignore_is_ignored(rules, "tools/debug.log"))
	assert(GlobUtils.gitignore_is_ignored(rules, "build/out.txt"))
	assert(not GlobUtils.gitignore_is_ignored(rules, "other/build/out.txt"))
	pass


func gitignore_is_ignored_table_test() -> void:
	assert(GlobUtils.gitignore_is_ignored(["*.tmp"], "a.tmp"))
	assert(not GlobUtils.gitignore_is_ignored(["*.tmp"], "a.txt"))
	assert(GlobUtils.gitignore_is_ignored(["node_modules/"], "node_modules/pkg/index.js"))
	assert(not GlobUtils.gitignore_is_ignored(["/node_modules/"], "vendor/node_modules/x"))
	assert(GlobUtils.gitignore_is_ignored(["/node_modules/"], "node_modules/pkg/index.js"))
	assert(GlobUtils.gitignore_is_ignored(["docs/", "!docs/public/"], "docs/internal.md"))
	assert(not GlobUtils.gitignore_is_ignored(["docs/", "!docs/public/"], "docs/public/page.html"))
	assert(GlobUtils.gitignore_is_ignored(["**/*.log", "!debug.log"], "app.log"))
	assert(not GlobUtils.gitignore_is_ignored(["**/*.log", "!debug.log"], "debug.log"))
	assert(not GlobUtils.gitignore_is_ignored(["# comment only"], "anything"))
	pass


func gitignore_comments_and_negation_test() -> void:
	var lines: Array[String] = ["# header", "", "*.bin", "!keep.bin", "build/"]
	assert(GlobUtils.gitignore_is_ignored(lines, "drop.bin"))
	assert(not GlobUtils.gitignore_is_ignored(lines, "keep.bin"))
	assert(GlobUtils.gitignore_is_ignored(lines, "build/out.txt"))
	pass


func glob_gitignore_enter_ignored_dir_test() -> void:
	var root := create_fixture_tree()
	DirAccess.make_dir_recursive_absolute(root.path_join(".godot"))
	FileUtils.write_string_to_file(root.path_join(".godot/extension_list.cfg"), "cfg\n")
	FileUtils.write_string_to_file(root.path_join(".godot/editor.log"), "log\n")
	DirAccess.make_dir_recursive_absolute(root.path_join("node_modules/pkg"))
	FileUtils.write_string_to_file(root.path_join("node_modules/pkg/index.js"), "js\n")
	var rules: Array[String] = [".godot/**", "!.godot/extension_list.cfg", "node_modules/"]
	var rel := relative_paths(root, GlobUtils.glob(root, "**/*", true, 0, rules))
	assert(rel.has(".godot/extension_list.cfg"), str(rel))
	assert(not rel.has(".godot/editor.log"), str(rel))
	assert(not rel.has("node_modules/pkg/index.js"), str(rel))
	assert(rel.has("src/a.gd"), str(rel))
	remove_fixture_tree(root)
	pass


func glob_gitignore_negated_file_under_wildcard_test() -> void:
	var root := create_fixture_tree()
	DirAccess.make_dir_recursive_absolute(root.path_join("vendor/cache"))
	FileUtils.write_string_to_file(root.path_join("vendor/keep.txt"), "ok\n")
	FileUtils.write_string_to_file(root.path_join("vendor/cache/drop.bin"), "bin\n")
	var rules: Array[String] = ["vendor/**", "!vendor/keep.txt"]
	var rel := relative_paths(root, GlobUtils.glob(root, "**/*", true, 0, rules))
	assert(rel.has("vendor/keep.txt"), str(rel))
	assert(not rel.has("vendor/cache/drop.bin"), str(rel))
	remove_fixture_tree(root)
	pass


func glob_gitignore_skips_ignored_at_any_depth_test() -> void:
	var root := create_fixture_tree()
	DirAccess.make_dir_recursive_absolute(root.path_join("vendor/cache"))
	FileUtils.write_string_to_file(root.path_join("vendor/cache/scratch.tmp"), "x\n")
	FileUtils.write_string_to_file(root.path_join("src/nested/note.tmp"), "x\n")
	var rel := relative_paths(root, GlobUtils.glob(root, "**/*", true, 0, ["*.tmp"]))
	assert(not rel.has("vendor/cache/scratch.tmp"))
	assert(not rel.has("src/nested/note.tmp"))
	assert(rel.has("src/a.gd"))
	remove_fixture_tree(root)
	pass


func glob_gitignore_public_subfolder_exception_test() -> void:
	var root := create_fixture_tree()
	DirAccess.make_dir_recursive_absolute(root.path_join("build/public"))
	DirAccess.make_dir_recursive_absolute(root.path_join("build/private"))
	FileUtils.write_string_to_file(root.path_join("build/public/index.html"), "<html></html>\n")
	FileUtils.write_string_to_file(root.path_join("build/private/secret.txt"), "x\n")
	var rules: Array[String] = ["build/", "!build/public/"]
	var rel := relative_paths(root, GlobUtils.glob(root, "**/*", true, 0, rules))
	assert(rel.has("build/public/index.html"), str(rel))
	assert(not rel.has("build/private/secret.txt"), str(rel))
	remove_fixture_tree(root)
	pass


func glob_gitignore_with_search_pattern_test() -> void:
	var root := create_fixture_tree()
	FileUtils.write_string_to_file(root.path_join("scratch.tmp"), "x\n")
	FileUtils.write_string_to_file(root.path_join("keep.gd"), "extends Node\n")
	var rel := relative_paths(root, GlobUtils.glob(root, "**/*.gd", true, 0, ["*.tmp", "src/"]))
	assert(rel == ["keep.gd", "root.gd"], str(rel))
	remove_fixture_tree(root)
	pass


func gitignore_is_ignored_differs_from_glob_match_any_test() -> void:
	var rules: Array[String] = ["*.tmp", "!keep.tmp"]
	assert(GlobUtils.glob_match_any(rules, "keep.tmp"))
	assert(not GlobUtils.gitignore_is_ignored(rules, "keep.tmp"))
	assert(GlobUtils.glob_match_any(rules, "drop.tmp"))
	assert(GlobUtils.gitignore_is_ignored(rules, "drop.tmp"))
	pass


## `**` terminal, `**/` directory spans, and `**/*.ext` anywhere in the tree.
func gitignore_double_star_pattern_test() -> void:
	assert_gitignore(["**"], "any/path/deep/file.txt", true)
	assert_gitignore(["**"], "file-at-root.txt", true)
	assert_gitignore(["**/*.log"], "app.log", true)
	assert_gitignore(["**/*.log"], "var/log/app.log", true)
	assert_gitignore(["**/*.log"], "app.txt", false)
	assert_gitignore(["foo/**"], "foo/bar/baz.txt", true)
	assert_gitignore(["foo/**"], "notfoo/bar/baz.txt", false)
	assert_gitignore(["foo/**/"], "foo/bar/baz.txt", true)
	assert_gitignore(["**/bar/*.gd"], "src/bar/a.gd", true)
	assert_gitignore(["**/bar/*.gd"], "src/bar/nested/a.gd", false)
	assert(GlobUtils.glob_match("cpp/**/*.obj", "cpp/src/foo.obj"))
	assert(not GlobUtils.glob_match("cpp/**/*.obj", "cpp/foo.txt"))
	pass


## `*` stays within one path segment; prefix globs like `tmp*` match basenames.
func gitignore_single_star_segment_test() -> void:
	assert_gitignore(["*.tmp"], "scratch.tmp", true)
	assert_gitignore(["*.tmp"], "dir/scratch.tmp", true)
	assert_gitignore(["*.tmp"], "scratch.tmp.bak", false)
	assert_gitignore(["tmp*"], "tmp", true)
	assert_gitignore(["tmp*"], "tmpcache", true)
	assert_gitignore(["tmp*"], "dir/tmpcache", true)
	assert_gitignore(["tmp*"], "notmp", false)
	assert_gitignore(["*~"], "readme~", true)
	assert_gitignore(["*~"], "sub/readme~", true)
	assert_gitignore(["*~"], "readme.txt", false)
	assert_gitignore(["foo*bar"], "fooZZbar", true)
	assert_gitignore(["foo*bar"], "prefix/fooZZbar", true)
	assert_gitignore(["foo*bar"], "foo/bar", false)
	pass


func gitignore_question_mark_pattern_test() -> void:
	assert_gitignore(["?.txt"], "a.txt", true)
	assert_gitignore(["?.txt"], "ab.txt", false)
	assert_gitignore(["file?.gd"], "file1.gd", true)
	assert_gitignore(["file?.gd"], "file12.gd", false)
	assert_gitignore(["*.sw?"], "lib.swf", true)
	assert_gitignore(["*.sw?"], "lib.sw", false)
	pass


## Trailing `/` marks a directory rule; contents inherit ignore during walks.
func gitignore_trailing_slash_directory_rule_test() -> void:
	assert(GlobUtils.glob_match("build/", "build"))
	assert(GlobUtils.glob_match("build/", "build/out.txt"))
	assert_gitignore(["build/"], "build/out.txt", true)
	assert_gitignore(["build/"], "build", true)
	assert_gitignore(["build/"], "other/build/out.txt", true)
	assert_gitignore(["/build/"], "build/out.txt", true)
	assert_gitignore(["/build/"], "other/build/out.txt", false)
	pass


func gitignore_leading_slash_anchor_extended_test() -> void:
	assert_gitignore(["/Makefile"], "Makefile", true)
	assert_gitignore(["/Makefile"], "src/Makefile", false)
	assert_gitignore(["/tools"], "tools/run.sh", true)
	assert_gitignore(["/tools"], "vendor/tools/run.sh", false)
	assert_gitignore(["/dist"], "dist/app.js", true)
	assert_gitignore(["/dist"], "web/dist/app.js", false)
	pass


## A pattern with no slash matches that path segment at any depth.
func gitignore_basename_without_slash_any_depth_test() -> void:
	assert_gitignore(["TODO"], "TODO", true)
	assert_gitignore(["TODO"], "notes/TODO", true)
	assert_gitignore(["TODO"], "notes/sub/TODO", true)
	assert_gitignore(["TODO"], "MYTODO", false)
	assert_gitignore(["tags"], "src/tags", true)
	assert_gitignore(["tags"], "notags", false)
	assert_gitignore([".idea"], "editor/.idea/workspace.xml", true)
	pass


## A pattern with internal slashes is anchored to the repository root, not parent prefixes.
func gitignore_slash_pattern_root_relative_test() -> void:
	assert_gitignore(["web/.env"], "web/.env", true)
	assert_gitignore(["web/.env"], "copy/web/.env", false)
	assert_gitignore(["agent/tools/*.gd"], "agent/tools/GlobTool.gd", true)
	assert_gitignore(["agent/tools/*.gd"], "agent/tools/nested/GlobTool.gd", false)
	assert_gitignore([".cursor/skills/humanizer"], ".cursor/skills/humanizer/a.gd", true)
	assert_gitignore([".cursor/skills/humanizer"], "prefix/.cursor/skills/humanizer/a.gd", false)
	pass


func gitignore_negation_extended_test() -> void:
	assert_gitignore(["*.log", "!important.log"], "debug.log", true)
	assert_gitignore(["*.log", "!important.log"], "important.log", false)
	assert_gitignore(["*", "!/README.md"], "README.md", false)
	assert_gitignore(["*", "!/README.md"], "src/foo.gd", true)
	assert_gitignore(["!"], "anything", false)
	assert_gitignore(["!", "   "], "anything", false)
	assert_gitignore(["  ! .keep  ", "*.tmp"], ".keep", false)
	assert_gitignore(["  ! .keep  ", "*.tmp"], "drop.tmp", true)
	pass


func gitignore_reignore_after_unignore_test() -> void:
	var rules: Array[String] = ["*.bin", "!keep.bin", "*.bin"]
	assert_gitignore(rules, "keep.bin", true)
	assert_gitignore(rules, "drop.bin", true)
	rules = ["!keep.bin", "*.bin"]
	assert_gitignore(rules, "keep.bin", true)
	assert_gitignore(rules, "drop.bin", true)
	pass


func gitignore_rule_whitespace_trim_test() -> void:
	assert_gitignore(["   *.log   "], "app.log", true)
	assert_gitignore(["  build/  "], "build/x", true)
	assert_gitignore(["*.txt", "!rescue.txt"], "rescue.txt", false)
	pass


## Brackets and braces are matched literally, not as glob character classes or expansions.
func gitignore_unsupported_glob_extensions_are_literal_test() -> void:
	assert(GlobUtils.glob_match("[abc].txt", "[abc].txt"))
	assert(not GlobUtils.glob_match("[abc].txt", "a.txt"))
	assert(GlobUtils.glob_match("{a,b}.txt", "{a,b}.txt"))
	assert(not GlobUtils.glob_match("{a,b}.txt", "a.txt"))
	assert_gitignore(["*.[ct]"], "file.[ct]", true)
	assert_gitignore(["*.[ct]"], "file.c", false)
	pass


func gitignore_special_regex_metacharacters_in_path_test() -> void:
	assert(GlobUtils.glob_match("mono_crash.*.json", "mono_crash.2026.json"))
	assert(GlobUtils.glob_match("file (1).txt", "file (1).txt"))
	assert(GlobUtils.glob_match("price+$100.txt", "subdir/price+$100.txt"))
	assert_gitignore(["(copy).txt"], "photos/(copy).txt", true)
	pass


func gitignore_log_suffix_star_patterns_test() -> void:
	assert_gitignore(["npm-debug.log*"], "npm-debug.log", true)
	assert_gitignore(["npm-debug.log*"], "npm-debug.log.12345", true)
	assert_gitignore(["npm-debug.log*"], "npm-debug.logs", true)
	assert_gitignore(["npm-debug.log*"], "other/npm-debug.log", true)
	assert_gitignore(["npm-debug.log*"], "npm-debug.txt", false)
	pass


func gitignore_cpp_and_godot_repo_style_rules_test() -> void:
	var rules: Array[String] = [
		"cpp/**/*.obj",
		"cpp/.sconsign.dblite.*",
		"cpp/bin/**/~*",
		".godot/**",
		"!.godot/extension_list.cfg",
		".import/",
		"export.cfg",
		"*.tmp.*",
	]
	assert_gitignore(rules, "cpp/src/foo.obj", true)
	assert_gitignore(rules, "cpp/.sconsign.dblite.9", true)
	assert_gitignore(rules, "cpp/bin/windows/~plugin.dll", true)
	assert_gitignore(rules, "cpp/bin/windows/plugin.dll", false)
	assert_gitignore(rules, ".godot/imported/x.ctex", true)
	assert_gitignore(rules, ".godot/extension_list.cfg", false)
	assert_gitignore(rules, "addons/.import/x", true)
	assert_gitignore(rules, "sub/export.cfg", true)
	assert_gitignore(rules, "scratch.tmp.bak", true)
	assert_gitignore(rules, "scratch.tmp", false)
	pass


func gitignore_is_ignored_full_repo_gitignore_test() -> void:
	var rules := load_repo_gitignore_rules()
	var ignored_paths: Array[String] = [
		"web/node_modules/react/index.js",
		"web/.env.production",
		"__pycache__/module.pyc",
		"cpp/src/game.obj",
		".godot/imported/icon.ctex",
		"obj/debug.tmp",
		"obj/scratch.tmp.extra",
		"npm-debug.log.1",
		"web/app.tsbuildinfo",
		"export.cfg.bak",
	]
	for path in ignored_paths:
		assert(GlobUtils.gitignore_is_ignored(rules, path), path)
	var visible_paths: Array[String] = [
		"script/main.gd",
		"README.md",
		"web/.env.example",
		".godot/extension_list.cfg",
		"cpp/bin/windows/gai_cpp.windows.template_debug.x86_64.dll",
	]
	for path in visible_paths:
		assert(not GlobUtils.gitignore_is_ignored(rules, path), path)
	pass


func glob_gitignore_enter_dir_exceptions_test() -> void:
	var root := create_fixture_tree()
	DirAccess.make_dir_recursive_absolute(root.path_join("vendor/pub"))
	DirAccess.make_dir_recursive_absolute(root.path_join("vendor/cache"))
	DirAccess.make_dir_recursive_absolute(root.path_join("cache"))
	DirAccess.make_dir_recursive_absolute(root.path_join("blocked"))
	FileUtils.write_string_to_file(root.path_join("vendor/keep.txt"), "ok\n")
	FileUtils.write_string_to_file(root.path_join("vendor/pub/readme.txt"), "ok\n")
	FileUtils.write_string_to_file(root.path_join("vendor/cache/x.bin"), "bin\n")
	FileUtils.write_string_to_file(root.path_join("cache/stale.tmp"), "tmp\n")
	FileUtils.write_string_to_file(root.path_join("blocked/important.dat"), "dat\n")
	var vendor_rel := relative_paths(root, GlobUtils.glob(root, "**/*", true, 0, ["vendor/**", "!vendor/keep.txt", "!vendor/pub/"]))
	assert(vendor_rel.has("vendor/keep.txt") and vendor_rel.has("vendor/pub/readme.txt"), str(vendor_rel))
	assert(not vendor_rel.has("vendor/cache/x.bin"), str(vendor_rel))
	assert(relative_paths(root, GlobUtils.glob(root, "**/*", true, 0, ["cache/"])).has("src/a.gd"))
	assert(not relative_paths(root, GlobUtils.glob(root, "**/*", true, 0, ["cache/"])).has("cache/stale.tmp"))
	assert(not relative_paths(root, GlobUtils.glob(root, "**/*", true, 0, ["blocked/", "!important.dat"])).has("blocked/important.dat"))
	remove_fixture_tree(root)
	pass


func glob_gitignore_include_directories_honors_ignore_test() -> void:
	var root := create_fixture_tree()
	DirAccess.make_dir_recursive_absolute(root.path_join("build/public"))
	DirAccess.make_dir_recursive_absolute(root.path_join("build/private"))
	FileUtils.write_string_to_file(root.path_join("build/public/index.html"), "html\n")
	FileUtils.write_string_to_file(root.path_join("build/private/secret.txt"), "x\n")
	var rules: Array[String] = ["build/", "!build/public/"]
	var tree := relative_paths(root, GlobUtils.glob(root, "", true, 0, rules, true))
	assert(tree.has("build/public/"), str(tree))
	assert(not tree.has("build/private/"), str(tree))
	assert(tree.has("build/public/index.html"))
	assert(not tree.has("build/private/secret.txt"))
	remove_fixture_tree(root)
	pass


func glob_gitignore_nested_negated_directory_test() -> void:
	var root := create_fixture_tree()
	DirAccess.make_dir_recursive_absolute(root.path_join("pkg/internal"))
	DirAccess.make_dir_recursive_absolute(root.path_join("pkg/public"))
	FileUtils.write_string_to_file(root.path_join("pkg/internal/secret.gd"), "extends Node\n")
	FileUtils.write_string_to_file(root.path_join("pkg/public/open.gd"), "extends Node\n")
	var rules: Array[String] = ["pkg/", "!pkg/public/", "!pkg/public/*.gd"]
	var rel := relative_paths(root, GlobUtils.glob(root, "**/*", true, 0, rules))
	assert(rel.has("pkg/public/open.gd"), str(rel))
	assert(not rel.has("pkg/internal/secret.gd"), str(rel))
	remove_fixture_tree(root)
	pass


func gitignore_backslash_path_normalization_test() -> void:
	assert(GlobUtils.gitignore_is_ignored(["*.tmp"], r"dir\scratch.tmp"))
	assert(GlobUtils.gitignore_is_ignored(["vendor/cache/"], r"vendor\cache\bin.dat"))
	pass


func gitignore_web_env_and_tsbuildinfo_test() -> void:
	var rules: Array[String] = ["web/.env", "web/.env.*", "!web/.env.example", "web/*.tsbuildinfo"]
	assert_gitignore(rules, "web/.env", true)
	assert_gitignore(rules, "web/.env.local", true)
	assert_gitignore(rules, "web/.env.example", false)
	assert_gitignore(rules, "web/app.tsbuildinfo", true)
	assert_gitignore(rules, "other/web/.env", false)
	pass


func gitignore_pyc_and_pycache_test() -> void:
	var rules: Array[String] = ["__pycache__/", "*.pyc"]
	assert_gitignore(rules, ".ai/common/__pycache__/mod.pyc", true)
	assert_gitignore(rules, "tools/script.pyc", true)
	assert_gitignore(rules, "tools/script.py", false)
	pass


func gitignore_translation_and_mono_crash_test() -> void:
	var rules: Array[String] = ["*.translation", "mono_crash.*.json"]
	assert_gitignore(rules, "locale/menu.translation", true)
	assert_gitignore(rules, "locale/menu.csv", false)
	assert_gitignore(rules, "logs/mono_crash.2026.01.json", true)
	assert_gitignore(rules, "logs/mono_crash.json", false)
	pass


func gitignore_only_comment_block_test() -> void:
	var rules: Array[String] = ["# everything ignored below is commented out", "# *.gd"]
	assert(not GlobUtils.gitignore_is_ignored(rules, "main.gd"))
	assert(not GlobUtils.gitignore_is_ignored(rules, "any/path"))
	pass


func glob_gitignore_empty_skip_list_is_no_op_test() -> void:
	var root := create_fixture_tree()
	var rel := relative_paths(root, GlobUtils.glob(root, "**/*.gd", true, 0, []))
	assert(rel.size() == 3)
	remove_fixture_tree(root)
	pass


func gitignore_is_ignored_comprehensive_matrix_test() -> void:
	var cases: Array = [
		[["*"], "anywhere.txt", true],
		[["*"], "deep/nested/anywhere.txt", true],
		[["/*.txt"], "readme.txt", true],
		[["/*.txt"], "docs/readme.txt", false],
		[["foo/"], "foo", true],
		[["foo/"], "bar/foo/x", true],
		[["foo"], "bar/foo", true],
		[["foo"], "foobar", false],
		[["**/"], "a/b/c", true],
		[["a/**/b"], "a/x/y/b", true],
		[["a/**/b"], "a/b", true],
		[["a/**/b"], "a/x/b/c", false],
		[["#", "*.gd"], "main.gd", true],
		[["# comment", "*.gd"], "main.gd", true],
		[["*.gd", "!main.gd", "src/*.gd"], "main.gd", false],
		[["*.gd", "!main.gd", "src/*.gd"], "src/main.gd", true],
	]
	for row in cases:
		var rules: Array[String] = []
		for rule in row[0]:
			rules.append(str(rule))
		assert_gitignore(rules, row[1], row[2])
	pass


static func assert_gitignore(rules: Variant, relative_path: String, want_ignored: bool) -> void:
	var typed_rules: Array[String] = []
	if rules is Array[String]:
		typed_rules = rules
	else:
		for rule in rules as Array:
			typed_rules.append(str(rule))
	assert(GlobUtils.gitignore_is_ignored(typed_rules, relative_path) == want_ignored,
		"path=[" + relative_path + "] want_ignored=" + str(want_ignored) + " rules=" + str(typed_rules))
	pass


static func load_repo_gitignore_rules() -> Array[String]:
	var rules: Array[String] = []
	for line in FileUtils.read_file_to_lines("res://.gitignore"):
		var rule := line.strip_edges()
		if not rule.is_empty() and not rule.begins_with("#"):
			rules.append(rule)
	return rules


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
