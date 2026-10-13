## GitUtils — git availability probe.


static func GitUtils_is_git_installed_test() -> void:
	# The probe returns a plain bool and stays stable across calls.
	var installed := GitHelper.is_git_installed()
	assert(installed is bool)
	assert(GitHelper.is_git_installed() == installed)
	# An independent shell probe must agree with the direct executable call.
	var probe := OSUtils.execute(OSUtils.build_shell_argv("git --version"), false)
	assert(installed == (probe.exit_code == 0))
	if installed:
		assert(probe.output.build_string().contains("git version"))
	pass


static func GitUtils_Git_command_context_test() -> void:
	if not GitHelper.is_git_installed():
		return
	var git := GitHelper.Git.new("repo path/.git", "repo path")
	assert(git.git_dir == "repo path/.git")
	assert(git.work_tree == "repo path")
	assert(git.config == GitHelper.GIT_CONFIG)
	pass


static func GitUtils_get_download_url_test() -> void:
	var url := GitHelper.get_download_url()
	assert(url.begins_with("https://git-scm.com/"))
	if OSUtils.is_windows():
		assert(url == "https://git-scm.com/install/windows")
	elif OSUtils.is_mac():
		assert(url == "https://git-scm.com/install/mac")
	elif OSUtils.is_linux():
		assert(url == "https://git-scm.com/install/linux")
	else:
		assert(url == "https://git-scm.com/downloads")
	pass
