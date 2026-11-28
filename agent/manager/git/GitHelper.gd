class_name GitHelper
extends Object

## Ignores machine-level Git behavior and supplies a non-interactive local identity, and reads which
## repository a workspace belongs to (see [method read_repo_info]).
const GIT_CONFIG := "-c user.name=gai -c user.email=gai@gai.local -c commit.gpgsign=false -c core.autocrlf=false -c core.filemode=false -c core.quotepath=false"


## A Git command context bound to an optional repository and work tree.
## Commands use the same string form as the Git CLI and run without a shell.
## Without a [member git_dir] the context runs *inside* [member work_tree], which is how
## [method GitHelper.read_repo_info] finds out which repository a folder belongs to.
class Git:
	var git_dir: String
	var work_tree: String
	var config: String

	func _init(p_git_dir: String = "", p_work_tree: String = "", p_config: String = GitHelper.GIT_CONFIG) -> void:
		git_dir = p_git_dir
		work_tree = p_work_tree
		config = p_config
		pass

	## Builds the argument vector for one command. A bound repository names its work tree with
	## `--work-tree`; without one the folder to query has to be the process directory, and only `-C`
	## changes that — `--work-tree` alone would let `rev-parse` answer for the application's own cwd.
	func build_argv(command_args: PackedStringArray, include_work_tree: bool = true) -> PackedStringArray:
		var argv := PackedStringArray(["git"])
		if StringUtils.is_not_blank(git_dir):
			argv.append_array(PackedStringArray(["--git-dir", git_dir]))
		if include_work_tree and StringUtils.is_not_blank(work_tree):
			if StringUtils.is_blank(git_dir):
				argv.append_array(PackedStringArray(["-C", work_tree]))
			else:
				argv.append_array(PackedStringArray(["--work-tree", work_tree]))
		if StringUtils.is_not_blank(config):
			argv.append_array(OSUtils.split_command_line(config))
		argv.append_array(command_args)
		return argv
		pass

	## Synchronous twin of [method async_execute_args] — for callers on a path that cannot await,
	## such as resolving a session file path.
	func execute_args(command_args: PackedStringArray, include_work_tree: bool = true) -> OSUtils.ExecResult:
		return OSUtils.execute(build_argv(command_args, include_work_tree), false)
		pass

	func async_execute(command: String, include_work_tree: bool = true) -> OSUtils.ExecResult:
		return await async_execute_args(OSUtils.split_command_line(command), include_work_tree)

	func async_execute_args(command_args: PackedStringArray, include_work_tree: bool = true) -> OSUtils.ExecResult:
		return await OSUtils.async_execute(build_argv(command_args, include_work_tree), false)

	func async_init_bare() -> OSUtils.ExecResult:
		return await GitHelper.async_execute(StringUtils.format('init --bare --quiet "{}"', git_dir))

	func async_is_bare() -> OSUtils.ExecResult:
		return await async_execute("rev-parse --is-bare-repository", false)

	func async_stage_all() -> OSUtils.ExecResult:
		return await async_execute("add -A")

	func async_get_head() -> OSUtils.ExecResult:
		return await async_execute("rev-parse --verify HEAD")

	func async_has_staged_changes(reference: String = "HEAD") -> OSUtils.ExecResult:
		return await async_execute(StringUtils.format("diff --cached --quiet {} --", reference))

	func async_commit(message: String) -> OSUtils.ExecResult:
		return await async_execute_args(PackedStringArray(["commit", "--quiet", "-m", message]))

	func async_list_commits(max_count: int) -> OSUtils.ExecResult:
		return await async_execute(StringUtils.format("rev-list --max-count={} HEAD", max_count))

	func async_get_staged_name_status(reference: String) -> OSUtils.ExecResult:
		return await async_execute(StringUtils.format("diff --cached --name-status {}", reference))

	func async_get_staged_numstat(reference: String) -> OSUtils.ExecResult:
		# Treat renames as one deleted and one added path so every displayed path remains clickable.
		return await async_execute(StringUtils.format("diff --cached --numstat --no-renames {} --", reference))

	func async_get_staged_diff(reference: String) -> OSUtils.ExecResult:
		return await async_execute(StringUtils.format("diff --cached --binary {} --", reference))

	func async_get_file_at_reference(reference: String, relative_path: String) -> OSUtils.ExecResult:
		return await async_execute_args(PackedStringArray(["show", reference + ":" + relative_path]))

	func async_checkout_tree(reference: String) -> OSUtils.ExecResult:
		return await async_execute(StringUtils.format("checkout {} -- :/", reference))

	func async_expire_reflogs() -> OSUtils.ExecResult:
		return await async_execute("reflog expire --expire=now --all")

	func async_gc_prune_now() -> OSUtils.ExecResult:
		return await async_execute("gc --prune=now --quiet")


## Runs a Git command without binding it to a repository.
static func async_execute(command: String) -> OSUtils.ExecResult:
	return await Git.new().async_execute(command)


## Deletes `*.lock` files a killed Git process (shutdown, cancel, timeout) left behind; a leftover
## lock makes every later command fail with "cannot lock ref". Only for repositories this app owns.
## The scan and deletes run on the worker thread pool.
static func async_clear_stale_locks(git_dir: String) -> void:
	await ExecutorHelper.async_execute_pooled(func() -> void:
		for file_path in FileUtils.get_all_files_in_folder(git_dir, true):
			if file_path.ends_with(".lock"):
				DirAccess.remove_absolute(file_path))
	pass


## Compares two in-memory texts through Git without depending on a repository or index.
static func async_diff_texts(old_text: String, new_text: String) -> OSUtils.ExecResult:
	var temp_prefix := "user://git-diff/" + str(IdUtils.uuid())
	var old_user_path := temp_prefix + "-original.txt"
	var new_user_path := temp_prefix + "-current.txt"
	var old_path := ProjectSettings.globalize_path(old_user_path)
	var new_path := ProjectSettings.globalize_path(new_user_path)
	if FileUtils.write_string_to_file(old_user_path, old_text) != OK or FileUtils.write_string_to_file(new_user_path, new_text) != OK:
		DirAccess.remove_absolute(old_path)
		DirAccess.remove_absolute(new_path)
		return OSUtils.ExecResult.new()
	var argv := PackedStringArray(["git", "--no-pager", "diff", "--no-index", "--unified=0", "--no-color", "--no-ext-diff", "--text", "--", old_path, new_path])
	var result := await OSUtils.async_execute(argv, false, 30 * TimeUtils.MILLIS_PER_SECOND)
	DirAccess.remove_absolute(old_path)
	DirAccess.remove_absolute(new_path)
	return result


## A workspace inside its repository: where the repository root is, how deep the workspace sits
## inside it, and which remote it points at.
class RepoInfo:
	## Absolute repository root; empty outside a repository.
	var toplevel := StringUtils.EMPTY
	## The queried folder relative to [member toplevel]; empty at the repository root, `agent/` below it.
	var prefix := StringUtils.EMPTY
	## Raw `url` of `origin`, or of the first remote when there is no `origin`.
	var remote_url := StringUtils.EMPTY


## Reads the repository owning [param work_tree]. Two commands are enough: `rev-parse` answers both the
## toplevel and the prefix, so worktrees, submodules and included configs stay Git's problem, and
## `config --get-regexp` returns every remote url at once.
static func read_repo_info(work_tree: String) -> RepoInfo:
	var info := RepoInfo.new()
	if not is_git_installed():
		return info
	# No bound repository and no commit identity flags: this context only asks where the folder sits.
	var git := Git.new(StringUtils.EMPTY, work_tree, StringUtils.EMPTY)
	var repo := git.execute_args(PackedStringArray(["rev-parse", "--show-toplevel", "--show-prefix"]))
	if repo.exit_code != 0:
		return info
	var lines := repo.output.build_string().split(FileUtils.NEWLINE_LF, true)
	info.toplevel = lines[0].strip_edges() if not lines.is_empty() else StringUtils.EMPTY
	info.prefix = lines[1].strip_edges() if lines.size() > 1 else StringUtils.EMPTY

	# `config --get` returns the *stored* url; `remote get-url` would apply this machine's `insteadOf`
	# rewrites, and two machines that rewrite differently would end up with two identities.
	var remotes := git.execute_args(PackedStringArray(["config", "--get-regexp", "^remote\\..*\\.url$"]))
	if remotes.exit_code != 0:
		return info
	for line: String in remotes.output.build_string().split(FileUtils.NEWLINE_LF, false):
		var parts := line.strip_edges().split(" ", false, 1)
		if parts.size() < 2:
			continue
		if parts[0] == "remote.origin.url":
			info.remote_url = parts[1]
			return info
		if StringUtils.is_blank(info.remote_url):
			info.remote_url = parts[1]
	return info
	pass


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


static var windows_git_bash_launcher_path := ""

## Terminal window launcher from the same Git installation as [method find_windows_git_bash].
## `git-bash.exe` (Mintty) opens a real window, while a bare `bash.exe` started from a GUI app has
## no console to attach to, so it only serves as the last-resort fallback.
static func find_git_bash_launcher() -> String:
	if StringUtils.is_not_blank(windows_git_bash_launcher_path):
		return windows_git_bash_launcher_path
	var bash_path := find_windows_git_bash()
	var git_root := bash_path.get_base_dir().get_base_dir()
	var git_bash_launcher := git_root.path_join("git-bash.exe")
	windows_git_bash_launcher_path = git_bash_launcher if FileAccess.file_exists(git_bash_launcher) else bash_path
	return windows_git_bash_launcher_path
