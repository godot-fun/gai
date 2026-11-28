extends RefCounted

## Session folder scope — the folder is chosen by the repository on disk, so one repository cloned
## into differently named local folders has to resolve to one folder, and a workspace that gains a
## remote has to keep the folder it already filled.
##
## Every test restores the workspace root before asserting, so a failing assertion cannot leak a
## temporary root into the tests that run after it.

const REPO_REMOTE_A := "user://scope_remote_a"
const REPO_REMOTE_B := "user://scope_remote_b"
const REPO_LOCAL := "user://scope_local"
const REPO_SUBFOLDERS := "user://scope_subfolders"
const REPO_ADOPT := "user://scope_adopt"
const REPO_CACHE := "user://scope_cache"
const REPO_CACHE_OTHER := "user://scope_cache_other"

## Outside the project on purpose: `user://` sits inside the repository here, so a folder under it
## would be identified as a workspace of this project instead of a folder without Git.
const PLAIN_DIR_NAME := "gai_scope_plain"


# ---------------------------------------------------------------------------
# Remote identity — every spelling of one repository answers one string
# ---------------------------------------------------------------------------

static func get_remote_identity_spellings_match_test() -> void:
	assert(AgentSessionScope.get_remote_identity("git@GitHub.com:zfoo/gai-agent.git") == "github.com/zfoo/gai-agent")
	assert(AgentSessionScope.get_remote_identity("https://github.com/zfoo/gai-agent.git") == "github.com/zfoo/gai-agent")
	assert(AgentSessionScope.get_remote_identity("ssh://git@github.com:22/zfoo/gai-agent") == "github.com/zfoo/gai-agent")
	assert(AgentSessionScope.get_remote_identity("git://github.com/zfoo/gai-agent.git") == "github.com/zfoo/gai-agent")
	assert(AgentSessionScope.get_remote_identity("https://github.com/zfoo/gai-agent/") == "github.com/zfoo/gai-agent")
	pass


static func get_remote_identity_drops_credentials_test() -> void:
	var identity := AgentSessionScope.get_remote_identity("https://x-access-token:ghp_secret@github.com/zfoo/gai-agent.git")
	assert(identity == "github.com/zfoo/gai-agent")
	assert(not identity.contains("secret"))
	pass


## A local path remote is machine specific, so it must never become an identity shared through sync.
static func get_remote_identity_rejects_local_paths_test() -> void:
	assert(AgentSessionScope.get_remote_identity("C:/repos/gai-agent.git").is_empty())
	assert(AgentSessionScope.get_remote_identity("../gai-agent.git").is_empty())
	assert(AgentSessionScope.get_remote_identity("/repos/gai-agent.git").is_empty())
	assert(AgentSessionScope.get_remote_identity(StringUtils.EMPTY).is_empty())
	assert(AgentSessionScope.get_remote_identity("no-separator").is_empty())
	pass


# ---------------------------------------------------------------------------
# Folder resolution — real repositories under user://
# ---------------------------------------------------------------------------

## One repository, two differently named clones: one folder, so both clones see the same history.
static func session_scope_follows_the_remote_test() -> void:
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
	assert(second_dir == first_dir)
	remove_dir(first_dir)
	remove_dir(first)
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


## A repository that gains a remote keeps the folder it already filled, and the identity it used to
## have stays in the manifest as an alias.
static func session_scope_adopts_the_existing_folder_test() -> void:
	assert(GitHelper.is_git_installed())
	var previous_root := Workspace.get_root()
	var repo := make_repo(REPO_ADOPT, StringUtils.EMPTY)
	assert(Workspace.set_root(repo))
	var before := AgentSessionScope.get_dir()
	assert(before.get_file().begins_with("scope_adopt-"))
	OSUtils.execute(PackedStringArray(["git", "-C", repo, "remote", "add", "origin", "git@github.com:zfoo/scope-adopt.git"]), false)
	# The identity is resolved once per workspace switch; resolving again simulates the next launch.
	AgentSessionScope.resolved_dir = AgentSessionScope.resolve_dir()
	var after := AgentSessionScope.get_dir()
	assert(Workspace.set_root(previous_root))
	assert(after == before)
	var manifest := AgentSessionScope.read_manifest(after)
	assert(manifest != null)
	assert(manifest.identity == "github.com/zfoo/scope-adopt/")
	assert(manifest.aliases.has("scope_adopt/"))
	assert(manifest.created > 0)
	assert(not manifest.root.contains("token"))
	remove_dir(before)
	remove_dir(repo)
	pass


## Switching workspace re-resolves eagerly: the cache holds the new workspace's folder right after the
## event, so two workspaces never share a folder and the first lookup never pays for the Git calls.
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
