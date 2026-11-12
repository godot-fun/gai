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
