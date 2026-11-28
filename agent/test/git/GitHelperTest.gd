## Git command helper tests.

static func git_diff_texts_test() -> void:
	if not GitHelper.is_git_installed():
		return
	var result := await GitHelper.async_diff_texts("same\nold\ntail", "same\nnew\ntail")
	assert(result.exit_code == 1)
	var changed := GitDiffParser.parse(result.output.build_string()).changed_lines
	assert(changed.old_lines == [2])
	assert(changed.new_lines == [2])
	pass


static func git_diff_identical_texts_test() -> void:
	if not GitHelper.is_git_installed():
		return
	var result := await GitHelper.async_diff_texts("same\ntext", "same\ntext")
	assert(result.exit_code == 0)
	assert(result.output.build_string().is_empty())
	pass


static func download_url_uses_official_git_site_test() -> void:
	var url := GitHelper.get_download_url()
	assert(url.begins_with("https://git-scm.com/"))
	assert(url.contains("/install/") or url == "https://git-scm.com")
	pass


## A killed Git process leaves `index.lock` behind; clearing it must restore write access.
static func async_clear_stale_locks_test() -> void:
	if not GitHelper.is_git_installed():
		return
	var temp_root := FileUtils.globalize_writable_path("user://git-lock-test-" + str(IdUtils.uuid()))
	var git_dir := temp_root.path_join("repo.git")
	var work_tree := temp_root.path_join("work")
	assert(DirAccess.make_dir_recursive_absolute(work_tree) == OK)
	assert(FileUtils.write_string_to_file(work_tree.path_join("a.txt"), "first\n") == OK)
	var git := GitHelper.Git.new(git_dir, work_tree)
	assert((await git.async_init_bare()).exit_code == 0)

	var index_lock_path := git_dir.path_join("index.lock")
	assert(FileUtils.write_string_to_file(index_lock_path, StringUtils.EMPTY) == OK)
	assert((await git.async_stage_all()).exit_code != 0)

	await GitHelper.async_clear_stale_locks(git_dir)
	assert(not FileAccess.file_exists(index_lock_path))
	assert((await git.async_stage_all()).exit_code == 0)
	assert(FileUtils.delete_file_or_directory(temp_root) == OK)
	pass


## The prefix is what keeps two folders of one repository apart, so it has to be read next to the
## toplevel in the same call.
static func read_repo_info_reports_toplevel_and_prefix_test() -> void:
	if not GitHelper.is_git_installed():
		return
	var root := FileUtils.globalize_writable_path("user://git-repo-info-test-" + str(IdUtils.uuid()))
	var nested := root.path_join("agent/tools")
	assert(DirAccess.make_dir_recursive_absolute(nested) == OK)
	assert(OSUtils.execute(PackedStringArray(["git", "-C", root, "init", "--quiet"]), false).exit_code == 0)
	assert(OSUtils.execute(PackedStringArray(["git", "-C", root, "remote", "add", "origin", "git@github.com:zfoo/git-repo-info.git"]), false).exit_code == 0)

	var root_info := GitHelper.read_repo_info(root)
	assert(FileUtils.normalize_path(root_info.toplevel) == FileUtils.normalize_path(root))
	assert(root_info.prefix.is_empty())
	assert(root_info.remote_url == "git@github.com:zfoo/git-repo-info.git")

	var nested_info := GitHelper.read_repo_info(nested)
	assert(nested_info.prefix == "agent/tools/")

	assert(GitHelper.read_repo_info(OS.get_temp_dir()).toplevel.is_empty())
	remove_repo_dir(root)
	pass


## Recursive delete that also walks hidden entries — a repository lives under a hidden `.git`, which
## [method FileUtils.delete_file_or_directory] skips.
static func remove_repo_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	var files := dir.get_files()
	var directories := dir.get_directories()
	dir = null
	for file_name: String in files:
		FileAccess.set_read_only_attribute(path.path_join(file_name), false)
		DirAccess.remove_absolute(path.path_join(file_name))
	for dir_name: String in directories:
		remove_repo_dir(path.path_join(dir_name))
	DirAccess.remove_absolute(path)
	pass
