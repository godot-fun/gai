class_name GitDiff
extends Object

## Agent-run diff flow:
##
##   User turn queued
##          |
##          v
##   Snapshot workspace ------> checkpoint SHA stored on the user chat entry
##          |
##          v
##   Agent changes workspace
##          |
##          v
##   Agent ends -> stage complete workspace -> diff against checkpoint
##                                      |
##                         +------------+------------+
##                         |                         |
##                    no changes               changed files
##                         |                         |
##                         v                         v
##                       stop        numstat + patch + full text snapshots
##                                                   |
##                                                   v
##                                      cache immutable `.gaidiff` bundle
##                                                   |
##                                                   v
##                                         append Git Diff chat entry
##                                                   |
##                                                   v
##                                          click file / Diff
##                                                   |
##                                                   v
##                              GitDiffViewer: cached old text +
##                              live workspace text -> edit/revert/save
##                                                   |
##                                                   v
##                              existence/hash guard prevents stale saves

const DIFF_CACHE_SUBDIR := ".gai/cache/diff"
const DIFF_CACHE_EXTENSION := "gaidiff"
const MAX_DIFF_CACHE_BYTES := 128 * FileUtils.BYTES_PER_MB


static func _static_init() -> void:
	var cache_dir := AgentWorkspace.get_root().path_join(DIFF_CACHE_SUBDIR)
	WorkerThreadPool.add_task(func() -> void: FileUtils.cleanup_cache_folder(cache_dir, MAX_DIFF_CACHE_BYTES))
	pass


## Appends a git diff chat entry when the completed agent run changed files.
static func async_append_git_diff(session_id: int) -> void:
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	# Checkpoint SHA from the most recent user turn — the snapshot taken before that run started.
	var reference := StringUtils.EMPTY
	for i in range(session.chat_entries.size() - 1, -1, -1):
		var entry: ChatEntry = session.chat_entries[i]
		if entry.kind == ChatEntry.KIND_USER:
			reference = entry.details.get(ChatEntry.DETAIL_CHECKPOINT, "")
			break
	if StringUtils.is_blank(reference):
		return
	var git := GitManager.create_git(session_id)
	if not await GitManager.ensure_repo(git) or not await GitManager.stage_all(git):
		return
	var diff_file_stats := await async_diff_file_stats(git, reference)
	if diff_file_stats.is_empty():
		return
	var patch_path := await async_cache_diff(git, reference, diff_file_stats)
	if StringUtils.is_blank(patch_path):
		return
	AgentSessionManager.add_chat_entry(
			session_id,
			ChatEntry.KIND_GIT_DIFF,
			ChatEntry.TITLE_GIT_DIFF,
			FileUtils.NEWLINE_LF.join(diff_file_stats),
			{ChatEntry.DETAIL_GIT_DIFF_PATCH: patch_path}
	)
	pass


## Returns tab-separated path/additions/deletions records for an agent run Git diff.
## The caller must refresh the shadow index first so edits made outside file tools are included.
static func async_diff_file_stats(git: GitHelper.Git, reference: String) -> PackedStringArray:
	var file_stats := PackedStringArray()
	if StringUtils.is_blank(reference):
		return file_stats
	var diff := await git.async_get_staged_numstat(reference)
	if diff.exit_code != 0:
		Log.error("agent checkpoint diff stats lookup failed:[{}]", diff.output.build_string())
		return file_stats
	for line in diff.output.build_string().split(FileUtils.NEWLINE_LF, false):
		var parts := line.split("\t", false)
		if parts.size() < 3:
			continue
		var path := parts[2].strip_edges()
		if StringUtils.is_blank(path):
			continue
		file_stats.append(path + "\t" + parts[0].strip_edges() + "\t" + parts[1].strip_edges())
	return file_stats


## Caches a JSON bundle so later workspace changes cannot alter this bubble's diff.
## The unified patch supplies change locations, while complete old/new UTF-8 snapshots make the
## viewer's right pane a real editor. Keeping both avoids reconstructing full files from partial hunks.
static func async_cache_diff(git: GitHelper.Git, reference: String, file_stats: PackedStringArray) -> String:
	if StringUtils.is_blank(reference):
		return StringUtils.EMPTY
	var diff := await git.async_get_staged_diff(reference)
	if diff.exit_code != 0:
		Log.error("agent git diff lookup failed:[{}]", diff.output.build_string())
		return StringUtils.EMPTY
	var patch := diff.output.build_string()
	if StringUtils.is_blank(patch):
		return StringUtils.EMPTY
	var cache_dir := AgentWorkspace.get_root().path_join(DIFF_CACHE_SUBDIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(cache_dir)
	if mkdir_error != OK:
		Log.error("agent git diff cache directory create failed path:[{}] error:[{}]", cache_dir, mkdir_error)
		return StringUtils.EMPTY
	var files: Array[GitDiffFile] = []
	for stat_line in file_stats:
		var parts := stat_line.split("\t", false)
		if parts.is_empty():
			continue
		var relative_path := parts[0].strip_edges().replace("\\", "/")
		var file_patch := GitDiffParser.extract_file_patch(patch, relative_path)
		# Git's binary markers catch normal cases; the byte checks below also reject NUL data and text
		# that cannot round-trip through UTF-8, preventing CodeEdit/Save from corrupting such files.
		var is_binary := file_patch.contains("GIT binary patch") or file_patch.contains("Binary files ")
		var old_result := await git.async_get_file_at_reference(reference, relative_path) if not is_binary else null
		var old_exists := old_result != null and old_result.exit_code == 0
		var old_text := old_result.output.build_string() if old_exists else StringUtils.EMPTY
		var absolute_path := AgentWorkspace.get_root().path_join(relative_path)
		var new_exists := FileAccess.file_exists(absolute_path)
		var new_bytes := FileUtils.read_file_to_byte_array(absolute_path) if new_exists else PackedByteArray()
		is_binary = is_binary or new_bytes.find(0) >= 0
		var new_text := FileUtils.read_file_to_string(absolute_path) if new_exists and not is_binary else StringUtils.EMPTY
		is_binary = is_binary or (not new_bytes.is_empty() and new_text.to_utf8_buffer() != new_bytes)
		if is_binary:
			new_text = StringUtils.EMPTY
		var status := GitDiffFile.STATUS_MODIFIED
		if not old_exists and new_exists:
			status = GitDiffFile.STATUS_ADDED
		elif old_exists and not new_exists:
			status = GitDiffFile.STATUS_DELETED
		var parsed_diff := GitDiffParser.parse(file_patch)
		var file := GitDiffFile.new()
		file.old_path = relative_path if old_exists else StringUtils.EMPTY
		file.new_path = relative_path if new_exists else StringUtils.EMPTY
		file.old_text = StringUtils.EMPTY if is_binary else old_text
		file.new_text = new_text
		file.new_hash = new_text.sha256_text()
		file.new_exists = new_exists
		file.status = status
		file.binary = is_binary
		file.changed_lines = parsed_diff.changed_lines
		files.append(file)
	var bundle := GitDiffBundle.new()
	bundle.files = files
	var patch_path := cache_dir.path_join(str(IdUtils.uuid()) + "." + DIFF_CACHE_EXTENSION)
	if not FileUtils.write_string_to_file(patch_path, JsonUtils.object_to_json(bundle)):
		Log.error("agent git diff bundle cache write failed path:[{}]", patch_path)
		return StringUtils.EMPTY
	return patch_path


## Opens a cached agent run in the side-by-side CodeEdit viewer.
static func open_diff(patch_path: String) -> void:
	if StringUtils.is_blank(patch_path) or not FileAccess.file_exists(patch_path):
		Alert.alert("Git diff is unavailable", Colors.error)
		return
	var files := load_diff_files(patch_path)
	if files.is_empty():
		Alert.alert("Git diff is unavailable", Colors.error)
		return
	GitDiffViewer.show_files(files, AgentWorkspace.get_root())
	pass


## Opens one file selected in a cached agent run.
static func open_file_diff(patch_path: String, relative_path: String) -> bool:
	if StringUtils.is_blank(patch_path) or not FileAccess.file_exists(patch_path):
		return false
	var files := load_diff_files(patch_path)
	if files.is_empty():
		return false
	var normalized_path := relative_path.replace("\\", "/")
	var found := false
	for file in files:
		if file.old_path == normalized_path or file.new_path == normalized_path:
			found = true
			break
	if not found:
		return false
	GitDiffViewer.show_files(files, AgentWorkspace.get_root(), normalized_path)
	return true


## Loads the cached JSON bundle for one agent run.
static func load_diff_files(cache_path: String) -> Array[GitDiffFile]:
	var text := FileUtils.read_file_to_string(cache_path)
	var bundle: GitDiffBundle = JsonUtils.json_to_object(text, GitDiffBundle)
	if bundle != null:
		return bundle.files
	return []
