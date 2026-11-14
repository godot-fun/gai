extends RefCounted

## The provider's path type, aliased so the fixtures below read as the paths they describe.
const MentionPath := ChatInputFileCompletion.MentionPath

## `@file` behavior: mention bounds, row text, matching order and the workspace scan. The popup flow
## (accept replaces the token, folder drills in) lives in ChatInputCompletionTest.


func mention_start_test() -> void:
	assert(ChatInputFileCompletion.mention_start("@") == 0)
	assert(ChatInputFileCompletion.mention_start("@agent/ui") == 0)
	assert(ChatInputFileCompletion.mention_start("read @agent/ui") == 5)
	assert(ChatInputFileCompletion.mention_start("read (@agent/ui") == 6)
	# Chinese is typed without a blank before the reference, and CJK punctuation opens it too.
	assert(ChatInputFileCompletion.mention_start("请看@agent/") == 2)
	assert(ChatInputFileCompletion.mention_start("请看（@agent/") == 3)
	# A CJK path keeps its `@`, an ASCII word keeps its own, and `/skill` is the other provider.
	assert(ChatInputFileCompletion.mention_start("mail@example.com") == -1)
	assert(ChatInputFileCompletion.mention_start("@文档/笔记.md") == 0)
	assert(ChatInputFileCompletion.mention_start("") == -1)
	assert(ChatInputFileCompletion.mention_start("/skill") == -1)
	pass


func token_end_test() -> void:
	assert(ChatInputFileCompletion.token_end("@agent/ui", 3) == 9)
	assert(ChatInputFileCompletion.token_end("@agent/ui 请看", 3) == 9)
	assert(ChatInputFileCompletion.token_end("(@a)", 2) == 3)
	assert(ChatInputFileCompletion.token_end("@a，b", 2) == 2)
	pass


func matching_entries_test() -> void:
	var entries: Array[MentionPath] = [
		MentionPath.folder("agent/"),
		MentionPath.folder("agent/ui/"),
		MentionPath.file("agent/ui/ChatInputAttachment.gd"),
		MentionPath.folder("docs/"),
		MentionPath.file("docs/notes.md"),
	]
	assert(ChatInputFileCompletion.matching_entries(entries, "").size() == 5)
	# The folder the token already names leads its own level, so it stays selectable instead of only
	# being drilled through.
	var agent_rows: Array[MentionPath] = ChatInputFileCompletion.matching_entries(entries, "agent/")
	assert(agent_rows.size() == 3)
	assert(agent_rows[0].path == "agent/")
	assert(agent_rows[1].path == "agent/ui/")
	assert(agent_rows[2].path == "agent/ui/ChatInputAttachment.gd")
	# The folder name matches first, then the file that only contains the query in its path.
	var ui: Array[MentionPath] = ChatInputFileCompletion.matching_entries(entries, "ui")
	assert(ui.size() == 2)
	assert(ui[0].path == "agent/ui/")
	assert(ui[1].path == "agent/ui/ChatInputAttachment.gd")
	assert(ChatInputFileCompletion.matching_entries(entries, "ui/chat")[0].path == "agent/ui/ChatInputAttachment.gd")
	assert(ChatInputFileCompletion.matching_entries(entries, "notes")[0].path == "docs/notes.md")
	# A typed Windows separator is the same query as a slash, and the shallower folder wins.
	assert(ChatInputFileCompletion.matching_entries(entries, "agent\\ui")[0].path == "agent/ui/")
	# A fully typed path is still a row, so it can be accepted rather than vanishing from the list.
	assert(ChatInputFileCompletion.matching_entries(entries, "agent/ui/")[0].path == "agent/ui/")
	assert(ChatInputFileCompletion.matching_entries(entries, "docs/notes.md")[0].path == "docs/notes.md")
	# Matching folds case without lower-casing the rows; the spelling stays whatever the disk has.
	assert(ChatInputFileCompletion.matching_entries(entries, "AGENT/UI/")[0].path == "agent/ui/")
	assert(ChatInputFileCompletion.matching_entries(entries, "NOTES")[0].path == "docs/notes.md")
	assert(ChatInputFileCompletion.matching_entries(entries, "missing").is_empty())
	assert(ChatInputFileCompletion.matching_entries(entries, "", 1).size() == 1)
	# Inside one bucket the shallower path comes first, so a root file beats a nested namesake.
	var nested: Array[MentionPath] = [
		MentionPath.file("docs/notes.md"),
		MentionPath.file("notes.md"),
	]
	assert(ChatInputFileCompletion.matching_entries(nested, "notes")[0].path == "notes.md")
	pass


func display_text_test() -> void:
	assert(ChatInputFileCompletion.build_display_text(MentionPath.file("notes.md")) == "notes.md")
	assert(ChatInputFileCompletion.build_display_text(MentionPath.folder("agent/ui/"))
		== "ui/" + ChatInputFileCompletion.DISPLAY_SEPARATOR + "agent/")
	assert(ChatInputFileCompletion.build_display_text(MentionPath.file("agent/ui/ChatInputAttachment.gd"))
		== "ChatInputAttachment.gd" + ChatInputFileCompletion.DISPLAY_SEPARATOR + "agent/ui/")
	pass


## A child folder drills (no trailing blank, so the mention stays live), the folder the token already
## names becomes a folder link, and a file always becomes a file link — both links close the mention.
func insert_text_test() -> void:
	var completion := ChatInputFileCompletion.new()
	completion.indexed_root = "C:/repo"
	assert(completion.build_insert_text(MentionPath.folder("agent/ui/"), "agent") == "@agent/ui/")
	assert(completion.build_insert_text(MentionPath.folder("agent/ui/"), "agent\\ui/") == "[ui/](<C:/repo/agent/ui/>) ")
	assert(completion.build_insert_text(MentionPath.folder("agent/ui/"), "agent/ui") == "@agent/ui/")
	# The query folds case, the inserted text keeps the spelling the index has.
	assert(completion.build_insert_text(MentionPath.folder("Agent/UI/"), "agent") == "@Agent/UI/")
	assert(completion.build_insert_text(MentionPath.folder("Agent/UI/"), "agent/ui/") == "[UI/](<C:/repo/Agent/UI/>) ")
	assert(completion.build_insert_text(MentionPath.file("agent/ui/ChatInputAttachment.gd"), "agent/ui")
		== "[ChatInputAttachment.gd](<C:/repo/agent/ui/ChatInputAttachment.gd>) ")
	pass


## The index is what the popup lists: relative paths with `/`, folders suffixed, noise folders dropped,
## and a stable alphabetical order.
func refresh_index_test() -> void:
	var root := make_scratch_workspace("scan")
	write_file(root.path_join("docs/notes.md"))
	# An empty folder is still a row: the walk collects folders, not just the paths of files.
	DirAccess.make_dir_recursive_absolute(root.path_join("output/images"))
	var scanned: Array[MentionPath] = await indexed_entries(root)
	var paths: Array[String] = []
	for scanned_entry: MentionPath in scanned:
		paths.append(scanned_entry.path)
	assert(paths == ["docs/", "docs/notes.md", "notes.md", "output/", "output/images/"], str(paths))
	assert(scanned[0].dir)
	assert(not scanned[1].dir)
	# Folders from [member GitIgnore.ignore_rules] are pruned with their subtree: `.git/` and
	# `node_modules/` come from the built-in blocks, `target/` is a build folder the old hand-written
	# list never knew about.
	for ignored: String in [".git/objects", "node_modules/pkg", "target/debug"]:
		DirAccess.make_dir_recursive_absolute(root.path_join(ignored))
		write_file(root.path_join(ignored + "/dropped.txt"))
	var rescan: Array[String] = []
	for scanned_entry: MentionPath in await indexed_entries(root):
		rescan.append(scanned_entry.path)
	assert(rescan == paths, str(rescan))
	pass


func refresh_index_empty_workspace_test() -> void:
	var prior_workspace := AgentWorkspace.get_root()
	var root := FileUtils.normalize_path("user://chat_input_file_completion/empty")
	DirAccess.make_dir_recursive_absolute(root)
	assert((await indexed_entries(root)).is_empty())
	AgentWorkspace.set_root(prior_workspace)
	pass


func indexed_entries(root: String) -> Array[MentionPath]:
	var prior_workspace := AgentWorkspace.get_root()
	assert(AgentWorkspace.set_root(root))
	var completion := ChatInputFileCompletion.new()
	await completion.async_refresh_index()
	var indexed := completion.entries
	AgentWorkspace.set_root(prior_workspace)
	return indexed


func make_scratch_workspace(name: String) -> String:
	var root := FileUtils.normalize_path("user://chat_input_file_completion/" + name)
	DirAccess.make_dir_recursive_absolute(root.path_join("docs"))
	write_file(root.path_join("notes.md"))
	return root


func write_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("x")
	file.close()
	pass
