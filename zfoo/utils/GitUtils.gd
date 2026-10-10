class_name GitUtils
extends Object

## Ignores machine-level Git behavior and supplies a non-interactive local identity.
const GIT_CONFIG := "-c user.name=gai -c user.email=gai@gai.local -c commit.gpgsign=false -c core.autocrlf=false -c core.filemode=false -c core.quotepath=false"


## A Git command context bound to an optional repository and work tree.
## Commands use the same string form as the Git CLI and run without a shell.
class Git:
	var git_dir: String
	var work_tree: String
	var config: String

	func _init(p_git_dir: String = "", p_work_tree: String = "", p_config: String = GitUtils.GIT_CONFIG) -> void:
		git_dir = p_git_dir
		work_tree = p_work_tree
		config = p_config
		pass

	func async_execute(command: String, include_work_tree: bool = true) -> OSUtils.ExecResult:
		var full_command := "git"
		if StringUtils.is_not_blank(git_dir):
			full_command += StringUtils.format(' --git-dir "{}"', git_dir)
		if include_work_tree and StringUtils.is_not_blank(work_tree):
			full_command += StringUtils.format(' --work-tree "{}"', work_tree)
		if StringUtils.is_not_blank(config):
			full_command += " " + config
		if StringUtils.is_not_blank(command):
			full_command += " " + command
		return await OSUtils.async_execute(OSUtils.split_command_line(full_command), false)

	func async_init_bare() -> OSUtils.ExecResult:
		return await GitUtils.async_execute(StringUtils.format('init --bare --quiet "{}"', git_dir))

	func async_is_bare() -> OSUtils.ExecResult:
		return await async_execute("rev-parse --is-bare-repository", false)

	func async_stage_all() -> OSUtils.ExecResult:
		return await async_execute("add -A")

	func async_get_head() -> OSUtils.ExecResult:
		return await async_execute("rev-parse --verify HEAD")

	func async_has_staged_changes(reference: String = "HEAD") -> OSUtils.ExecResult:
		return await async_execute(StringUtils.format("diff --cached --quiet {} --", reference))

	func async_commit(message: String) -> OSUtils.ExecResult:
		return await async_execute(StringUtils.format('commit --quiet -m "{}"', message))

	func async_list_commits(max_count: int) -> OSUtils.ExecResult:
		return await async_execute(StringUtils.format("rev-list --max-count={} HEAD", max_count))

	func async_get_staged_name_status(reference: String) -> OSUtils.ExecResult:
		return await async_execute(StringUtils.format("diff --cached --name-status {}", reference))

	func async_get_staged_numstat(reference: String) -> OSUtils.ExecResult:
		# Treat renames as one deleted and one added path so every displayed path remains clickable.
		return await async_execute(StringUtils.format("diff --cached --numstat --no-renames {} --", reference))

	func async_get_staged_diff(reference: String) -> OSUtils.ExecResult:
		return await async_execute(StringUtils.format("diff --cached --binary {} --", reference))

	func async_checkout_tree(reference: String) -> OSUtils.ExecResult:
		return await async_execute(StringUtils.format("checkout {} -- :/", reference))

	func async_expire_reflogs() -> OSUtils.ExecResult:
		return await async_execute("reflog expire --expire=now --all")

	func async_gc_prune_now() -> OSUtils.ExecResult:
		return await async_execute("gc --prune=now --quiet")


## Runs a Git command without binding it to a repository.
static func async_execute(command: String) -> OSUtils.ExecResult:
	return await Git.new().async_execute(command)


## Cached positive probe — Git availability only changes across app restarts.
static var git_installed := false

## Checks whether the git command is installed and callable in the current environment.
static func is_git_installed() -> bool:
	if git_installed:
		return true
	var result := OSUtils.execute(PackedStringArray(["git", "--version"]), false)
	git_installed = result.exit_code == 0 and result.output.build_string().contains("git version")
	return git_installed


## Official Git install page for the current platform.
static func get_download_url() -> String:
	if OSUtils.is_windows():
		return "https://git-scm.com/install/windows"
	if OSUtils.is_mac():
		return "https://git-scm.com/install/mac"
	if OSUtils.is_linux():
		return "https://git-scm.com/install/linux"
	return "https://git-scm.com"

# ----------------------------------------------------------------------------------------------------------------------
static var windows_git_bash_path := ""
static var windows_git_mintty_path := ""

static func find_windows_git_bash() -> String:
	if StringUtils.is_not_blank(windows_git_bash_path):
		return windows_git_bash_path

	var where_result := OSUtils.execute(PackedStringArray(["where.exe", "git"]), false)
	if where_result.exit_code == 0:
		var output := FileUtils.normalize_line_endings_to_lf(where_result.output.build_string())
		for line in output.split("\n", false):
			var git_path := line.strip_edges().replace("\\", "/")
			var git_directory := git_path.get_base_dir()
			var candidates: PackedStringArray = [
				git_directory.path_join("bash.exe"),
				git_directory.get_base_dir().path_join("bin/bash.exe"),
				]
			for candidate in candidates:
				if FileAccess.file_exists(candidate):
					windows_git_bash_path = candidate
					return windows_git_bash_path

	const other_paths: PackedStringArray = [
		"C:/Program Files/Git/bin/bash.exe",
		"C:/Program Files (x86)/Git/bin/bash.exe",
		]
	for path in other_paths:
		if FileAccess.file_exists(path):
			windows_git_bash_path = path
			return windows_git_bash_path
	windows_git_bash_path = "bash.exe"
	return windows_git_bash_path


## Finds the Mintty terminal bundled with Git for Windows.
static func find_windows_git_mintty() -> String:
	if StringUtils.is_not_blank(windows_git_mintty_path):
		return windows_git_mintty_path
	var bash_path := find_windows_git_bash().replace("\\", "/")
	var git_root := bash_path.get_base_dir().get_base_dir()
	var candidate := git_root.path_join("usr/bin/mintty.exe")
	if FileAccess.file_exists(candidate):
		windows_git_mintty_path = candidate
		return windows_git_mintty_path
	windows_git_mintty_path = "mintty.exe"
	return windows_git_mintty_path
