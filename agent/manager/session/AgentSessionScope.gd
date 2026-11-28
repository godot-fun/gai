class_name AgentSessionScope
extends RefCounted

## Which folder this workspace's chat sessions live in — [method get_dir] is the only entry point.
##
## [Workspace] supplies the roots and [GitHelper] answers which repository the workspace belongs to,
## so the same repository cloned as `gai-agent` or `tmp-a` resolves to one folder and Steam Cloud
## keeps a single history.
##
## The folder name is a label, not the identity: `workspace.json` records the identity and the last
## known root, and an existing folder that already owns the identity is adopted — that is what keeps
## a workspace's history when its repository gains a remote or moves to another path. The identity is
## resolved once per workspace switch, so a remote changed inside a running session is picked up
## after a restart; the folder never moves under the user.


## Sessions folder under the cloud dir. Named here because this resolver owns the whole layout; the
## store constant delegates to it.
const SESSIONS_SUBDIR := "sessions"
const MANIFEST_FILE := "workspace.json"
const HASH_LENGTH := 8
const SLUG_MAX_LENGTH := 40

## Identity of a workspace outside any repository — the absolute path is all that is left.
const PATH_PREFIX := "path:"

## The folder of the current workspace, the result of [method resolve_dir]. Written once at load and
## again after every switch, so a session path lookup is a plain field read.
static var resolved_dir := StringUtils.EMPTY


static func _static_init() -> void:
	# A switch always changes the root, so it is the only thing that re-resolves the folder.
	gdf.events.workspace_changed.connect(on_workspace_changed)
	resolved_dir = resolve_dir()
	pass


## Re-resolves for the new workspace. The root has already changed when the event fires, so resolving
## here keeps the folder current instead of leaving the first session lookup to discover it.
static func on_workspace_changed(_path: String) -> void:
	resolved_dir = resolve_dir()
	pass


# ---------------------------------------------------------------------------
# Resolve
# ---------------------------------------------------------------------------

## The folder holding this workspace's sessions — read straight from [member resolved_dir], which
## [method _static_init] and [method on_workspace_changed] keep current.
static func get_dir() -> String:
	return resolved_dir
	pass


## Resolves, and first time creates, the folder of the current workspace.
static func resolve_dir() -> String:
	var root := Workspace.get_root()

	# Identity: the remote identity (or the folder name) plus the path inside the repository, so two
	# workspaces of one repository never share a folder.
	var repo := GitHelper.read_repo_info(root)
	var repository_root := repo.toplevel if StringUtils.is_not_blank(repo.toplevel) else root
	var remote_key := get_remote_identity(repo.remote_url)
	var base := remote_key if StringUtils.is_not_blank(remote_key) else repository_root.get_file().to_lower()
	var identity := PATH_PREFIX + root.to_lower()
	if StringUtils.is_not_blank(repo.toplevel):
		identity = base + "/" + repo.prefix.to_lower().trim_suffix("/")

	# The slug comes from the name, the hash from the whole identity: two workspaces of one repository
	# keep the same readable prefix and stay apart by the hash alone.
	var slug := FileUtils.sanitize_filename(base).to_lower()
	if slug.is_empty() or slug == "unnamed":
		slug = "workspace"
	var sessions_root := Workspace.get_cloud_data_dir(SESSIONS_SUBDIR)
	var dir := sessions_root.path_join(slug.left(SLUG_MAX_LENGTH).trim_suffix("_") + "-" + identity.md5_text().left(HASH_LENGTH))

	# A folder that already owns this identity wins over the computed name: adoption is what keeps a
	# workspace's history when the identity changes under it.
	if not DirAccess.dir_exists_absolute(dir):
		for existing: String in FileUtils.get_all_directories_in_folder(sessions_root):
			var existing_manifest := read_manifest(existing)
			if existing_manifest == null:
				continue
			if existing_manifest.identity == identity or existing_manifest.root == root or existing_manifest.aliases.has(identity):
				dir = existing
				break
	write_manifest(dir, identity, root, base.get_file())
	Log.info("session scope root:[{}] identity:[{}] dir:[{}]", root, identity, dir)
	return dir
	pass


# ---------------------------------------------------------------------------
# Remote identity
# ---------------------------------------------------------------------------

## What a remote URL denotes, as the repository identity `host/path`. Every spelling of one remote —
## `git@GitHub.com:zfoo/gai-agent.git`, `ssh://git@github.com:22/zfoo/gai-agent`,
## `https://token@github.com/zfoo/gai-agent.git/` — answers the same `github.com/zfoo/gai-agent`, so a
## folder key built from it is stable across machines and accounts.
##
## It is an identity, not a normalized URL: the scheme, port and credentials are dropped on purpose (a
## token must never reach a file name or a log line) and the result cannot be fetched. Local path
## remotes answer an empty string — a path is machine specific, so the caller falls back to the
## repository folder name instead.
static func get_remote_identity(url: String) -> String:
	var text := url.strip_edges().to_lower()
	if text.is_empty() or text.begins_with("/") or text.begins_with(".") or text.substr(1, 1) == ":":
		return StringUtils.EMPTY
	for prefix: String in ["https://", "http://", "ssh://", "git://", "git+ssh://"]:
		if text.begins_with(prefix):
			text = text.trim_prefix(prefix)
			break
	# Strip the credentials before any `:` handling — a token can carry a colon too.
	text = text.substr(text.rfind("@") + 1)
	# `host:path` is the scp form, `host:22/path` a port; both collapse to `host/path`, so two machines
	# reaching one server over different ports match again.
	var slash := text.find("/")
	var colon := text.find(":")
	if colon >= 0 and (slash < 0 or colon < slash):
		var after := text.substr(colon + 1)
		var digits := 0
		while digits < after.length() and after[digits].is_valid_int():
			digits += 1
		if digits > 0 and after.substr(digits, 1) == "/":
			after = after.substr(digits + 1)
		text = text.left(colon) + "/" + after
	text = text.trim_suffix("/").trim_suffix(".git").trim_suffix("/")
	return text if text.contains("/") else StringUtils.EMPTY
	pass


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

## What a session folder records about itself. The folder name is a truncated slug plus a hash, so it
## cannot be read back; this file is what makes a folder recognizable to a human and adoptable by
## [method resolve_dir] when the identity changes under it.
class Manifest:
	var name := StringUtils.EMPTY
	var root := StringUtils.EMPTY
	var identity := StringUtils.EMPTY
	## Identities this folder had before, so a later resolution still finds it.
	var aliases: Array[String] = []
	var created := 0


## Reads the manifest of [param dir], or null when the folder has none.
static func read_manifest(dir: String) -> Manifest:
	var text := FileUtils.read_file_to_string(dir.path_join(MANIFEST_FILE))
	if StringUtils.is_blank(text):
		return null
	return JsonUtils.json_to_object(text, Manifest) as Manifest
	pass


## Records the identity owning [param dir]. A changed identity moves to `aliases` instead of being
## replaced, and the creation time survives every rewrite.
static func write_manifest(dir: String, identity: String, root: String, name: String) -> void:
	var manifest := read_manifest(dir)
	if manifest == null:
		manifest = Manifest.new()
	if StringUtils.is_not_blank(manifest.identity) and manifest.identity != identity and not manifest.aliases.has(manifest.identity):
		manifest.aliases.append(manifest.identity)
	manifest.name = name
	manifest.root = root
	manifest.identity = identity
	if manifest.created <= 0:
		manifest.created = TimeUtils.now()
	var write_error := FileUtils.write_string_to_file(dir.path_join(MANIFEST_FILE), JsonUtils.object_to_json(manifest))
	if write_error != OK:
		Log.error("session scope manifest write failed dir:[{}] error:[{}]", dir, error_string(write_error))
	pass
