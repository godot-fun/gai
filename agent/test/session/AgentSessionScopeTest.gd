extends RefCounted

## Session folder scope — the folder is chosen by the repository on disk: one repository keeps one
## history across machines, a second local clone of it gets a folder of its own, and a workspace that
## gains a remote has to keep the folder it already filled.
##
## Every test restores the workspace root before asserting, so a failing assertion cannot leak a
## temporary root into the tests that run after it.

const REPO_REMOTE_A := "user://scope_remote_a"
const REPO_REMOTE_B := "user://scope_remote_b"
const REPO_LOCAL := "user://scope_local"
const REPO_SUBFOLDERS := "user://scope_subfolders"
const REPO_GAINS_REMOTE := "user://scope_gains_remote"
const REPO_CACHE := "user://scope_cache"
const REPO_CACHE_OTHER := "user://scope_cache_other"

## Outside the project on purpose: `user://` sits inside the repository here, so a folder under it
## would be identified as a workspace of this project instead of a folder without Git.
const PLAIN_DIR_NAME := "gai_scope_plain"


# ---------------------------------------------------------------------------
# Remote identity — one URL, one identity
# ---------------------------------------------------------------------------

## One URL, one identity — the scheme, the credentials and the `.git` suffix never reach the folder
## name. Spellings of one remote deliberately stay apart: a clone keeps the URL it was cloned with.
static func get_remote_identity_normalizes_the_url_test() -> void:
	assert(AgentSessionScope.get_remote_identity("https://github.com/zfoo/gai.git") == "github.com/zfoo/gai")
	assert(AgentSessionScope.get_remote_identity("https://github.com/zfoo/gai/") == "github.com/zfoo/gai")
	assert(AgentSessionScope.get_remote_identity("git@github.com:zfoo/gai.git") == "github.com/zfoo/gai")
	assert(AgentSessionScope.get_remote_identity("ssh://git@github.com/zfoo/gai") == "github.com/zfoo/gai")
	assert(AgentSessionScope.get_remote_identity("no-separator").is_empty())
	assert(AgentSessionScope.get_remote_identity(StringUtils.EMPTY).is_empty())
	pass


static func get_remote_identity_drops_credentials_test() -> void:
	var identity := AgentSessionScope.get_remote_identity("https://x-access-token:ghp_secret@github.com/zfoo/gai.git")
	assert(identity == "github.com/zfoo/gai")
	assert(not identity.contains("secret"))
	pass


## A path remote is not shared across machines: it keeps its own path, so each machine stays on the
## folder it named instead of both claiming one identity.
static func get_remote_identity_keeps_a_path_remote_local_test() -> void:
	assert(AgentSessionScope.get_remote_identity("C:/repos/gai.git") == "c:/repos/gai")
	assert(AgentSessionScope.get_remote_identity("../gai.git") == "../gai")
	pass


# ---------------------------------------------------------------------------
# Folder resolution — real repositories under user://
# ---------------------------------------------------------------------------

## One repository, two differently named clones on this machine: two folders, so a chat started in one
## clone never continues while the tools run in the other.
static func session_scope_separates_local_clones_test() -> void:
	assert(GitHelper.is_git_installed())
	var previous_root := Workspace.get_root()
	var first := make_repo(REPO_REMOTE_A, "git@GitHub.com:zfoo/scope-fixture.git")
	var second := make_repo(REPO_REMOTE_B, "https://token@github.com/zfoo/scope-fixture.git")
	assert(Workspace.set_root(first))
	var first_dir := AgentSessionScope.get_dir()
	assert(Workspace.set_root(second))
	var second_dir := AgentSessionScope.get_dir()
	assert(Workspace.set_root(previous_root))
	assert(first_dir.get_file().begins_with("github_com_zfoo_scope-fixture-"))
	assert(second_dir.get_file().begins_with("github_com_zfoo_scope-fixture-"))
	assert(second_dir != first_dir)
	remove_dir(first_dir)
	remove_dir(second_dir)
	remove_dir(first)
	remove_dir(second)
	pass


## The same clone on the *other* machine: its root is a different path there, so the folder is matched
## by name and both use it, and Steam Cloud still carries one history per repository.
static func session_scope_shares_across_machines_test() -> void:
	assert(GitHelper.is_git_installed())
	var previous_root := Workspace.get_root()
	var first := make_repo(REPO_REMOTE_A, "git@github.com:zfoo/scope-machine.git")
	var second := make_repo(REPO_REMOTE_B, "git@github.com:zfoo/scope-machine.git")
	assert(Workspace.set_root(first))
	var first_dir := AgentSessionScope.get_dir()
	# The other machine recorded its own root, and that path does not exist here.
	AgentSessionScope.write_manifest(first_dir, "C:/github/gai_other_machine", "gai")
	assert(Workspace.set_root(second))
	var second_dir := AgentSessionScope.get_dir()
	assert(Workspace.set_root(previous_root))
	assert(second_dir == first_dir)
	remove_dir(first_dir)
	remove_dir(first)
	remove_dir(second)
	pass


## Deleting one clone must not move the other one's history: a folder that recorded a root keeps
## following that root instead of falling back to the folder named after the identity.
static func session_scope_keeps_the_folder_when_a_sibling_clone_is_deleted_test() -> void:
	assert(GitHelper.is_git_installed())
	var previous_root := Workspace.get_root()
	var first := make_repo(REPO_REMOTE_A, "git@github.com:zfoo/scope-sibling.git")
	var second := make_repo(REPO_REMOTE_B, "git@github.com:zfoo/scope-sibling.git")
	assert(Workspace.set_root(first))
	var first_dir := AgentSessionScope.get_dir()
	assert(Workspace.set_root(second))
	var second_dir := AgentSessionScope.get_dir()
	# Resolving again is what the next launch does.
	AgentSessionScope.resolved_dir = AgentSessionScope.resolve_dir()
	assert(AgentSessionScope.get_dir() == second_dir)
	remove_dir(first)
	AgentSessionScope.resolved_dir = AgentSessionScope.resolve_dir()
	assert(AgentSessionScope.get_dir() == second_dir)
	assert(second_dir != first_dir)
	assert(Workspace.set_root(previous_root))
	remove_dir(first_dir)
	remove_dir(second_dir)
	remove_dir(second)
	pass


## Without a remote the repository folder name is the best identity available.
static func session_scope_uses_the_repository_name_test() -> void:
	assert(GitHelper.is_git_installed())
	var previous_root := Workspace.get_root()
	var repo := make_repo(REPO_LOCAL, StringUtils.EMPTY)
	assert(Workspace.set_root(repo))
	var dir := AgentSessionScope.get_dir()
	assert(Workspace.set_root(previous_root))
	assert(dir.get_file().begins_with("scope_local-"))
	remove_dir(dir)
	remove_dir(repo)
	pass


## Two workspaces of one repository must not share a folder — the path inside the repository is part
## of the identity.
static func session_scope_separates_repository_subfolders_test() -> void:
	assert(GitHelper.is_git_installed())
	var previous_root := Workspace.get_root()
	var repo := make_repo(REPO_SUBFOLDERS, "git@github.com:zfoo/scope-subfolders.git")
	var nested := repo.path_join("app/tools")
	assert(DirAccess.make_dir_recursive_absolute(nested) == OK)
	assert(Workspace.set_root(repo))
	var repo_dir := AgentSessionScope.get_dir()
	assert(Workspace.set_root(nested))
	var nested_dir := AgentSessionScope.get_dir()
	assert(Workspace.set_root(previous_root))
	assert(repo_dir.get_file().begins_with("github_com_zfoo_scope-subfolders-"))
	assert(nested_dir.get_file().begins_with("github_com_zfoo_scope-subfolders-"))
	assert(repo_dir != nested_dir)
	remove_dir(repo_dir)
	remove_dir(nested_dir)
	remove_dir(repo)
	pass


static func session_scope_falls_back_to_the_workspace_path_test() -> void:
	var previous_root := Workspace.get_root()
	var plain := FileUtils.normalize_path(OS.get_temp_dir().path_join(PLAIN_DIR_NAME))
	remove_dir(plain)
	assert(DirAccess.make_dir_recursive_absolute(plain) == OK)
	assert(Workspace.set_root(plain))
	var dir := AgentSessionScope.get_dir()
	assert(Workspace.set_root(previous_root))
	assert(dir.get_file().begins_with(PLAIN_DIR_NAME + "-"))
	remove_dir(dir)
	remove_dir(plain)
	pass


## A repository that gains a remote keeps the folder it already filled: the manifest records the
## root, so the folder is found before the identity is ever consulted.
static func session_scope_keeps_the_folder_when_a_remote_is_added_test() -> void:
	assert(GitHelper.is_git_installed())
	var previous_root := Workspace.get_root()
	var repo := make_repo(REPO_GAINS_REMOTE, StringUtils.EMPTY)
	assert(Workspace.set_root(repo))
	var before := AgentSessionScope.get_dir()
	assert(before.get_file().begins_with("scope_gains_remote-"))
	OSUtils.execute(PackedStringArray(["git", "-C", repo, "remote", "add", "origin", "git@github.com:zfoo/scope-adopt.git"]), false)
	# Resolving again is what the next launch does.
	AgentSessionScope.resolved_dir = AgentSessionScope.resolve_dir()
	var after := AgentSessionScope.get_dir()
	assert(Workspace.set_root(previous_root))
	assert(after == before)
	var manifest := AgentSessionScope.read_manifest(after)
	assert(manifest != null)
	assert(manifest.root == repo)
	assert(manifest.create_time > 0)
	assert(manifest.update_time > 0)
	assert(not manifest.root.contains("token"))
	remove_dir(before)
	remove_dir(repo)
	pass


## Switching workspace re-resolves eagerly: the cache holds the new workspace's folder right after the
## event, so two workspaces never share a folder and the first session lookup never has to resolve one.
static func workspace_switch_resolves_the_new_folder_test() -> void:
	assert(GitHelper.is_git_installed())
	var previous_root := Workspace.get_root()
	var first := make_repo(REPO_CACHE, "git@github.com:zfoo/scope-cache-first.git")
	var second := make_repo(REPO_CACHE_OTHER, "git@github.com:zfoo/scope-cache-second.git")
	assert(Workspace.set_root(first))
	var first_dir := AgentSessionScope.get_dir()
	assert(Workspace.set_root(second))
	var second_dir := AgentSessionScope.resolved_dir
	assert(Workspace.set_root(previous_root))
	assert(first_dir.get_file().begins_with("github_com_zfoo_scope-cache-first-"))
	assert(second_dir.get_file().begins_with("github_com_zfoo_scope-cache-second-"))
	assert(second_dir != first_dir)
	remove_dir(first_dir)
	remove_dir(second_dir)
	remove_dir(first)
	remove_dir(second)
	pass


# ---------------------------------------------------------------------------
# Manifest & cleanup
# ---------------------------------------------------------------------------

## A folder no workspace has opened for half a year is deleted, while the folder of the current
## workspace stays however long it sat — the age comes from the manifest.
static func cleanup_deletes_only_stale_folders_test() -> void:
	# Touching the class runs its startup cleanup; draining the executor after it keeps the fixtures
	# below out of that background run.
	AgentSessionScope.get_dir()
	wait_startup_cleanup()
	var sessions_root := Workspace.get_cloud_data_dir(AgentSessionScope.SESSIONS_SUBDIR)
	var suffix := str(TimeUtils.current_time_millis())
	var stale := sessions_root.path_join("scope_stale-" + suffix)
	var fresh := sessions_root.path_join("scope_fresh-" + suffix)
	assert(DirAccess.make_dir_recursive_absolute(stale) == OK)
	assert(DirAccess.make_dir_recursive_absolute(fresh) == OK)
	AgentSessionScope.write_manifest(stale, stale, "stale")
	AgentSessionScope.write_manifest(fresh, fresh, "fresh")
	# A year ago is well past the half year the cleanup keeps a folder for.
	backdate_manifest(stale, TimeUtils.current_time_millis() - 365 * TimeUtils.MILLIS_PER_DAY)

	# The folder of the current workspace always stays, however long it sat unopened.
	var saved_dir := AgentSessionScope.resolved_dir
	AgentSessionScope.resolved_dir = stale
	AgentSessionScope.cleanup()
	assert(DirAccess.dir_exists_absolute(stale))

	AgentSessionScope.resolved_dir = saved_dir
	AgentSessionScope.cleanup()
	assert(not DirAccess.dir_exists_absolute(stale))
	assert(DirAccess.dir_exists_absolute(fresh))
	remove_dir(fresh)
	pass


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## Creates a real repository under `user://`: Git answers the identity, so the fixture has to be a
## repository Git itself understands.
static func make_repo(user_path: String, remote: String) -> String:
	var root := ProjectSettings.globalize_path(user_path)
	remove_dir(root)
	assert(DirAccess.make_dir_recursive_absolute(root) == OK)
	OSUtils.execute(PackedStringArray(["git", "-C", root, "init", "--quiet"]), false)
	if StringUtils.is_not_blank(remote):
		OSUtils.execute(PackedStringArray(["git", "-C", root, "remote", "add", "origin", remote]), false)
	return FileUtils.normalize_path(root)
	pass


## Waits for the cleanup [method AgentSessionScope._static_init] queued on the single-thread executor.
## The executor is FIFO, so a no-op queued behind it completes only after that background run is over.
## Spinning the main thread is deliberate: an awaited frame would keep this suite from quitting.
static func wait_startup_cleanup() -> void:
	var done := Semaphore.new()
	ExecutorHelper.execute(func() -> void: done.post())
	var deadline := Time.get_ticks_msec() + 5000
	while not done.try_wait():
		if Time.get_ticks_msec() > deadline:
			Log.error("startup session cleanup did not finish")
			return
		OS.delay_msec(5)
	pass


## Rewrites the manifest of [param session_dir] as if the workspace had last opened it at
## [param update_time] — [method AgentSessionScope.write_manifest] always stamps the current time.
static func backdate_manifest(session_dir: String, update_time: int) -> void:
	var manifest := AgentSessionScope.read_manifest(session_dir)
	assert(manifest != null)
	manifest.update_time = update_time
	var write_error := FileUtils.write_string_to_file(session_dir.path_join(AgentSessionScope.MANIFEST_FILE), JsonUtils.object_to_json(manifest))
	assert(write_error == OK)
	pass


## Recursive delete that also walks hidden entries — [method FileUtils.delete_file_or_directory] skips
## them, and a repository keeps everything under a hidden `.git`. Takes an absolute path.
static func remove_dir(path: String) -> void:
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
		remove_dir(path.path_join(dir_name))
	DirAccess.remove_absolute(path)
	pass
