class_name AgentSessionScope
extends RefCounted

## Which folder this workspace's chat sessions live in — `get_dir` is what session paths ask for.
##
## A folder is named after the workspace's identity — the remote, or the repository folder name, plus
## the path inside the repository; the absolute path outside one. So one repository keeps one history
## across machines and Steam Cloud syncs it once, and two workspaces of it stay apart.
##
## Two clones of that repository on the *same* machine are two working trees though: one shared history
## would let a chat continue in one clone while the tools run in the other, so [method resolve_dir]
## gives the second one a folder of its own.
##
## `workspace.gai` records which root filled a folder, and that record decides ownership: a folder
## whose root is still on this machine is never given away. That is what keeps a workspace on the
## folder it already filled when its remote changes, and keeps a surviving clone off a deleted
## sibling's folder. The folder is resolved once per workspace switch, so a change made inside a
## running session is picked up after a restart; it never moves under the user.
##
## The manifest also carries when the workspace last opened the folder, and startup deletes a folder
## no workspace has opened for half a year — see [method cleanup].


## Sessions folder under the cloud dir.
const SESSIONS_SUBDIR := "sessions"
## Records which root filled the folder — see [method resolve_dir].
const MANIFEST_FILE := "workspace.gai"

## The folder of the current workspace, the result of [method resolve_dir]. Written once at load and
## again after every switch, so a session path lookup is a plain field read.
static var resolved_dir := StringUtils.EMPTY


static func _static_init() -> void:
	# A switch always changes the root, so it is the only thing that re-resolves the folder.
	gdf.events.workspace_changed.connect(on_workspace_changed)
	resolved_dir = resolve_dir()
	# Deleting a folder of sessions takes a while, so the stale ones go on the background executor
	# instead of blocking startup — queued rather than pooled, because ExecutorHelper drains its queue
	# on gdf.shutdown().
	ExecutorHelper.execute(cleanup)
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


## Resolves, and first time creates, the folder of the current workspace.
##
## A folder that already recorded this root answers the lookup, which is the whole cost once a
## workspace has been opened before. Only a workspace without one needs its identity, and only then can
## the folder it would take belong to another clone of the same repository on this machine.
static func resolve_dir() -> String:
	var root := Workspace.get_root()
	var sessions_root := Workspace.get_cloud_data_dir(SESSIONS_SUBDIR)
	# A folder that recorded this root is this workspace's folder, whatever its repository looks like
	# now — a remote added or changed must not move it.
	for existing: String in FileUtils.get_all_directories_in_folder(sessions_root):
		var existing_manifest := read_manifest(existing)
		if existing_manifest != null and existing_manifest.root == root:
			Log.info("session scope root:[{}] dir:[{}]", root, existing)
			return existing

	# No folder yet, so name one after the repository identity — the remote, or the repository folder
	# name, plus the path inside it, which keeps two workspaces of one repository apart.
	var repo := GitHelper.read_repo_info(root)
	var repository_root := repo.toplevel if StringUtils.is_not_blank(repo.toplevel) else root
	var remote_key := get_remote_identity(repo.remote_url)
	var base := remote_key if StringUtils.is_not_blank(remote_key) else repository_root.get_file().to_lower()
	# Outside a repository the absolute path is all that is left as an identity.
	var identity := root.to_lower()
	if StringUtils.is_not_blank(repo.toplevel):
		identity = base + "/" + repo.prefix.to_lower().trim_suffix("/")
	# A readable slug plus the whole identity hash: the slug says what the folder is, the hash keeps two
	# workspaces of one repository apart.
	var slug := FileUtils.sanitize_filename(base).to_lower()
	var session_dir := sessions_root.path_join(slug + "-" + identity.md5_text())
	# That folder can already belong to another clone of the same repository on this machine — a second
	# working tree gets a folder of its own instead of continuing that clone's chat while the tools run
	# here. A recorded root that is gone is a deleted clone, or another machine's path, so the folder is
	# free to take over.
	var owner_manifest := read_manifest(session_dir)
	if owner_manifest != null and owner_manifest.root != root and DirAccess.dir_exists_absolute(owner_manifest.root):
		identity = identity + "#" + root.to_lower().md5_text().left(8)
		session_dir = sessions_root.path_join(slug + "-" + identity.md5_text())
	write_manifest(session_dir, root, base.get_file())
	Log.info("session scope root:[{}] identity:[{}] dir:[{}]", root, identity, session_dir)
	return session_dir


# ---------------------------------------------------------------------------
# Remote identity
# ---------------------------------------------------------------------------

## What a remote URL denotes, as the repository identity `host/path`. Credentials are dropped on
## purpose — a token must never reach a file name or a log line — and so is the scheme, so one URL
## answers one identity on every machine that cloned it.
##
## The result is not a canonical form: `git@host:x/y` and `ssh://host:22/x/y` name the same remote but
## keep their own identity, because a clone keeps using the URL it was cloned with. Local paths keep
## theirs too, so a path remote stays on the machine that named it instead of colliding through sync.
static func get_remote_identity(url: String) -> String:
	var text := url.strip_edges().to_lower()
	var scheme_end := text.find("://")
	if scheme_end >= 0:
		text = text.substr(scheme_end + 3)
	# `user@host:path` and `user@host/path` both carry the host after the credentials.
	text = text.substr(text.rfind("@") + 1)
	text = text.trim_suffix("/").trim_suffix(".git").trim_suffix("/")
	# `host:path` is the scp form — the path starts after the first colon, when it comes before any
	# slash. A single character before the colon is a Windows drive, not a host.
	var colon := text.find(":")
	var slash := text.find("/")
	if colon > 1 and (slash < 0 or colon < slash):
		text = text.left(colon) + "/" + text.substr(colon + 1)
	return text if text.contains("/") else StringUtils.EMPTY


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

## What a session folder records about itself — the folder name cannot be read back, so this file is
## what [method resolve_dir] matches ownership against.
##
## `{"name": "gai", "root": "C:/github/gai", "create_time": 1795866226887, "update_time": 1795866226887}`
class Manifest:
	var name := StringUtils.EMPTY
	## Absolute workspace root that filled this folder — a folder belongs to one workspace.
	var root := StringUtils.EMPTY
	## When the folder was filled, in milliseconds.
	var create_time := 0
	## When a workspace last opened the folder, in milliseconds — the age [method cleanup] goes by.
	var update_time := 0


## Reads the manifest of [param session_dir], or null when the folder has none.
static func read_manifest(session_dir: String) -> Manifest:
	var text := FileUtils.read_file_to_string(session_dir.path_join(MANIFEST_FILE))
	if StringUtils.is_blank(text):
		return null
	return JsonUtils.json_to_object(text, Manifest) as Manifest


## Records [param root] as the workspace owning [param session_dir]. The creation time is stamped once,
## when the manifest is first written; every rewrite stamps the update time [method cleanup] reads.
static func write_manifest(session_dir: String, root: String, name: String) -> void:
	var now := TimeUtils.current_time_millis()
	var manifest := read_manifest(session_dir)
	if manifest == null:
		manifest = Manifest.new()
		manifest.create_time = now
	manifest.name = name
	manifest.root = root
	manifest.update_time = now
	var write_error := FileUtils.write_string_to_file(session_dir.path_join(MANIFEST_FILE), JsonUtils.object_to_json(manifest))
	if write_error != OK:
		Log.error("session scope manifest write failed dir:[{}] error:[{}]", session_dir, error_string(write_error))
	pass


# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

## Deletes the session folders no workspace has opened for half a year, so a history nothing comes back
## to does not keep syncing forever.
##
## The folder of [member resolved_dir] always stays. So does a folder without a manifest or without a
## readable time — only a folder whose manifest proves it stale is removed. A workspace switch while the
## background run is under way is harmless: the folder it moves to was just stamped as opened.
##
## [method _static_init] queues it on the background executor at startup, so a machine that long
## stopped working on a project pays for the deletion while it starts rather than by waiting for it.
static func cleanup() -> void:
	var sessions_root := Workspace.get_cloud_data_dir(SESSIONS_SUBDIR)
	var stale_before := TimeUtils.current_time_millis() - 90 * TimeUtils.MILLIS_PER_DAY
	for existing: String in FileUtils.get_all_directories_in_folder(sessions_root):
		var manifest := read_manifest(existing)
		if existing == resolved_dir or manifest == null or manifest.update_time <= 0 or manifest.update_time > stale_before:
			continue
		var delete_error := FileUtils.delete_file_or_directory(existing)
		if delete_error != OK:
			Log.error("session scope stale folder delete failed dir:[{}] error:[{}]", existing, error_string(delete_error))
			continue
		Log.info("session scope deleted stale folder dir:[{}] last_opened:[{}]", existing, TimeUtils.time_to_datetime_string(manifest.update_time))
	pass
