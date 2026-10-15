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
