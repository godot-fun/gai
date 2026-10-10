class_name AgentCheckpoint
extends RefCounted

## Workspace snapshots for chat revert — one shared shadow git repo under `.gai/checkpoints/`.
##
## Every command uses an isolated [GitUtils.Git] context, so the user's own repository is never
## read or written. A snapshot is taken before each user turn and reverting restores that state.

const CHECKPOINTS_SUBDIR := ".gai/checkpoints"
const SHALLOW_FILE := "shallow"
const COMMIT_MESSAGE := "gai checkpoint message"
const MAX_CHECKPOINTS := 100
const CHECKPOINTS_AFTER_CLEANUP := 50

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

static func get_git_dir() -> String:
	return AgentWorkspace.get_root().path_join(CHECKPOINTS_SUBDIR)


static func ensure_repo() -> bool:
	var git_dir := get_git_dir()
	var git := GitUtils.Git.new(git_dir, AgentWorkspace.get_root())
	if DirAccess.dir_exists_absolute(git_dir):
		# Supplying --work-tree makes Git report false even for a valid bare repository.
		var check := await git.async_is_bare()
		if check.exit_code == 0 and check.output.build_string().strip_edges() == "true":
			return write_exclude_rules(git_dir)
		# A missing Git executable is an environment failure, not repository corruption.
		if check.exit_code < 0:
			Log.error("agent checkpoint validation failed to start git:[{}]", check.output.build_string())
			return false
		Log.error("agent checkpoint repository is invalid, recreating:[{}]", check.output.build_string())
		if not remove_checkpoint_repo(git_dir):
			return false
	var mkdir_error := DirAccess.make_dir_recursive_absolute(git_dir.get_base_dir())
	if mkdir_error != OK:
		Log.error("agent checkpoint parent directory create failed path:[{}] error:[{}]", git_dir.get_base_dir(), mkdir_error)
		return false
	var init := await git.async_init_bare()
	if init.exit_code != 0:
		Log.error("agent checkpoint init failed:[{}]", init.output.build_string())
		return false
	return write_exclude_rules(git_dir)


static func write_exclude_rules(git_dir: String) -> bool:
	var project_rules := FileUtils.read_file_to_string(AgentWorkspace.get_root().path_join(".gitignore"))
	var exclude_rules := project_rules
	if not exclude_rules.is_empty() and not exclude_rules.ends_with(FileUtils.NEWLINE_LF):
		exclude_rules += FileUtils.NEWLINE_LF
	## `.git` is the user's real repository — snapshots must never swallow it.
	## Mandatory rules come last so project negation rules cannot re-include these directories.
	exclude_rules += ".git/\n.gai/\n.godot/\n"
	var git_exclude_path := git_dir.path_join("info/exclude")
	if FileUtils.write_string_to_file(git_exclude_path, exclude_rules):
		return true
	Log.error("agent checkpoint exclude write failed:[{}]", git_exclude_path)
	return false


## Deletes only the exact shadow repository path after validation has declared it invalid.
static func remove_checkpoint_repo(git_dir: String) -> bool:
	var expected := AgentWorkspace.get_root().path_join(CHECKPOINTS_SUBDIR).simplify_path()
	if git_dir.simplify_path() != expected:
		Log.error("agent checkpoint refused unexpected delete path:[{}]", git_dir)
		return false
	if FileUtils.delete_file_or_directory(git_dir):
		return true
	Log.error("agent checkpoint repository delete failed:[{}]", git_dir)
	return false


static func stage_all() -> bool:
	var git := GitUtils.Git.new(get_git_dir(), AgentWorkspace.get_root())
	var add := await git.async_stage_all()
	if add.exit_code == 0:
		return true
	Log.error("agent checkpoint stage failed:[{}]", add.output.build_string())
	return false


# ---------------------------------------------------------------------------
# Snapshot / restore
# ---------------------------------------------------------------------------

## Commits the current workspace state and returns the commit id; empty when unavailable.
static func async_snapshot() -> String:
	if not await ensure_repo() or not await stage_all():
		return StringUtils.EMPTY
	var git := GitUtils.Git.new(get_git_dir(), AgentWorkspace.get_root())
	var previous_head := await git.async_get_head()
	if previous_head.exit_code == 0:
		var diff := await git.async_has_staged_changes()
		if diff.exit_code == 0:
			return previous_head.output.build_string().strip_edges()
		if diff.exit_code > 1:
			Log.error("agent checkpoint tree comparison failed:[{}]", diff.output.build_string())
			return StringUtils.EMPTY
	var commit := await git.async_commit(COMMIT_MESSAGE)
	if commit.exit_code != 0:
		Log.error("agent checkpoint commit failed:[{}]", commit.output.build_string())
		return StringUtils.EMPTY
	var head := await git.async_get_head()
	if head.exit_code != 0:
		Log.error("agent checkpoint head lookup failed:[{}]", head.output.build_string())
		return StringUtils.EMPTY
	var sha := head.output.build_string().strip_edges()
	await async_cleanup(false)
	return sha


## When history exceeds [constant MAX_CHECKPOINTS], keeps the newest [constant CHECKPOINTS_AFTER_CLEANUP] commits.
static func async_cleanup(force_gc: bool = true) -> void:
	if not await ensure_repo():
		return
	var git := GitUtils.Git.new(get_git_dir(), AgentWorkspace.get_root())
	var history := await git.async_list_commits(MAX_CHECKPOINTS + 1)
	if history.exit_code != 0:
		# An initialized repository without its first commit has nothing to clean.
		return
	var commits := history.output.build_string().strip_edges().split(FileUtils.NEWLINE_LF, false)
	var truncated := commits.size() > MAX_CHECKPOINTS
	if truncated:
		var boundary := commits[CHECKPOINTS_AFTER_CLEANUP - 1].strip_edges()
		if not FileUtils.write_string_to_file(get_git_dir().path_join(SHALLOW_FILE), boundary + FileUtils.NEWLINE_LF):
			Log.error("agent checkpoint shallow boundary write failed:[{}]", boundary)
			return
	if not truncated and not force_gc:
		return
	var reflog := await git.async_expire_reflogs()
	if reflog.exit_code != 0:
		Log.error("agent checkpoint reflog cleanup failed:[{}]", reflog.output.build_string())
		return
	var gc := await git.async_gc_prune_now()
	if gc.exit_code != 0:
		Log.error("agent checkpoint gc failed:[{}]", gc.output.build_string())
	pass


## Reverts the workspace to [param sha]: files changed since then are put back, files created since are removed.
## Returns false when Git cannot complete the restore; callers must keep chat history intact on failure.
static func async_restore(sha: String) -> bool:
	if StringUtils.is_blank(sha) or not await ensure_repo():
		return false
	if not await stage_all():
		return false
	var git := GitUtils.Git.new(get_git_dir(), AgentWorkspace.get_root())
	var diff := await git.async_get_staged_name_status(sha)
	if diff.exit_code != 0:
		Log.error("agent checkpoint restore diff failed:[{}]", diff.output.build_string())
		return false
	# Added / copied / renamed targets did not exist at the checkpoint — revert removes them.
	var removed := PackedStringArray()
	for line in diff.output.build_string().split(FileUtils.NEWLINE_LF, false):
		var parts := line.split("\t", false)
		if parts.size() < 2:
			continue
		var status := parts[0].strip_edges()
		if status.begins_with("A") or status.begins_with("C") or status.begins_with("R"):
			removed.append(parts[parts.size() - 1].strip_edges())
	# `:/` is the worktree root regardless of the process working directory.
	var checkout := await git.async_checkout_tree(sha)
	if checkout.exit_code != 0:
		Log.error("agent checkpoint restore checkout failed:[{}]", checkout.output.build_string())
		return false
	for path in removed:
		var absolute_path := AgentWorkspace.get_root().path_join(path)
		if not FileAccess.file_exists(absolute_path):
			continue
		var error := DirAccess.remove_absolute(absolute_path)
		if error != OK:
			Log.error("agent checkpoint restore delete failed path:[{}] error:[{}]", absolute_path, error)
			return false
	return true


# ---------------------------------------------------------------------------
# Git change summary / Delta
# ---------------------------------------------------------------------------

const DIFF_CACHE_SUBDIR := ".gai/cache/diff"
const GITHUB_LIGHT_BACKGROUND := "BackgroundColour=255,255,255" # #ffffff canvas-default
const GITHUB_LIGHT_FOREGROUND := "ForegroundColour=31,35,40" # #1f2328 fg-default
const GITHUB_LIGHT_CURSOR := "CursorColour=9,105,218" # #0969da accent-fg
const GITHUB_LIGHT_SELECTION_BACKGROUND := "HighlightBackgroundColour=9,105,218" # #0969da accent-fg
const GITHUB_LIGHT_SELECTION_FOREGROUND := "HighlightForegroundColour=255,255,255"
const GITHUB_DARK_BACKGROUND := "BackgroundColour=13,17,23" # #0d1117 canvas-default
const GITHUB_DARK_FOREGROUND := "ForegroundColour=230,237,243" # #e6edf3 fg-default
const GITHUB_DARK_CURSOR := "CursorColour=88,166,255" # #58a6ff accent-fg
const GITHUB_DARK_SELECTION_BACKGROUND := "HighlightBackgroundColour=31,111,235" # #1f6feb accent-emphasis
const GITHUB_DARK_SELECTION_FOREGROUND := "HighlightForegroundColour=255,255,255"
const DELTA_DIFF_STYLES_LIGHT := "--minus-style='syntax #ffebe9' --minus-emph-style='syntax #ffcecb' --plus-style='syntax #dafbe1' --plus-emph-style='syntax #aceebb'"
const DELTA_DIFF_STYLES_DARK := "--minus-style='syntax #2d1618' --minus-emph-style='syntax #8e2d35' --plus-style='syntax #12261e' --plus-emph-style='syntax #1f6f3d'"


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
			reference = entry.checkpoint
			break
	var diff_file_stats := await async_diff_file_stats(reference)
	if diff_file_stats.is_empty():
		return
	var patch_path := await async_cache_diff(reference)
	AgentSessionManager.add_chat_entry(
			session_id,
			ChatEntry.KIND_GIT_DIFF,
			ChatEntry.TITLE_GIT_DIFF,
			FileUtils.NEWLINE_LF.join(diff_file_stats),
			{ChatEntry.DETAIL_GIT_DIFF_PATCH: patch_path},
			reference
	)
	pass


## Returns tab-separated path/additions/deletions records for an agent run Git diff.
## The shadow index is refreshed first so this also catches edits made outside file tools.
static func async_diff_file_stats(reference: String) -> PackedStringArray:
	var file_stats := PackedStringArray()
	if StringUtils.is_blank(reference) or not await ensure_repo() or not await stage_all():
		return file_stats
	var git := GitUtils.Git.new(get_git_dir(), AgentWorkspace.get_root())
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


## Caches the completed agent run patch so later workspace changes cannot alter this bubble's diff.
static func async_cache_diff(reference: String) -> String:
	if StringUtils.is_blank(reference) or not await ensure_repo() or not await stage_all():
		return StringUtils.EMPTY
	var git := GitUtils.Git.new(get_git_dir(), AgentWorkspace.get_root())
	var diff := await git.async_get_staged_diff(reference)
	if diff.exit_code != 0 or StringUtils.is_blank(diff.output.build_string()):
		return StringUtils.EMPTY
	var cache_dir := AgentWorkspace.get_root().path_join(DIFF_CACHE_SUBDIR)
	if DirAccess.make_dir_recursive_absolute(cache_dir) != OK:
		return StringUtils.EMPTY
	var patch_path := cache_dir.path_join(str(IdUtils.uuid()) + ".patch")
	if not FileUtils.write_string_to_file(patch_path, diff.output.build_string()):
		return StringUtils.EMPTY
	return patch_path


## Opens a cached agent run patch in the bundled Delta terminal viewer.
static func open_diff(patch_path: String) -> void:
	if StringUtils.is_blank(patch_path) or not FileAccess.file_exists(patch_path):
		Alert.alert("Git diff is unavailable", ColorBase.error)
		return
	var delta_path := ProjectSettings.globalize_path("res://.dependency/delta/delta.exe")
	if not FileAccess.file_exists(delta_path):
		Alert.alert("Delta executable not found", ColorBase.error)
		return
	var light_theme := ThemeColor.is_light_theme()
	var delta_color_mode := "--light" if light_theme else "--dark"
	var terminal_background := GITHUB_LIGHT_BACKGROUND if light_theme else GITHUB_DARK_BACKGROUND
	var terminal_foreground := GITHUB_LIGHT_FOREGROUND if light_theme else GITHUB_DARK_FOREGROUND
	var terminal_cursor := GITHUB_LIGHT_CURSOR if light_theme else GITHUB_DARK_CURSOR
	var selection_background := GITHUB_LIGHT_SELECTION_BACKGROUND if light_theme else GITHUB_DARK_SELECTION_BACKGROUND
	var selection_foreground := GITHUB_LIGHT_SELECTION_FOREGROUND if light_theme else GITHUB_DARK_SELECTION_FOREGROUND
	var syntax_theme := "GitHub" if light_theme else "Visual Studio Dark+"
	var diff_styles := DELTA_DIFF_STYLES_LIGHT if light_theme else DELTA_DIFF_STYLES_DARK
	var escaped_patch_path := patch_path.replace("'", "'\\''")
	var escaped_delta_path := delta_path.replace("'", "'\\''")
	var command := StringUtils.format("/usr/bin/sleep 0.2; /usr/bin/cat '{}' | '{}' --side-by-side --width=-2 --syntax-theme '{}' {} {} --paging=always; exec /bin/bash --login -i", escaped_patch_path, escaped_delta_path, syntax_theme, diff_styles, delta_color_mode)
	var encoded_command := Marshalls.raw_to_base64(command.to_utf8_buffer())
	var bash_command := StringUtils.format("/bin/bash --noprofile --norc <(printf %s {} | /usr/bin/base64 --decode)", encoded_command)
	# `--window max` expands on the monitor that owns the initial position; without
	# `--pos` Windows often places mintty on the primary (left) screen.
	var screen := DisplayServer.window_get_current_screen(DisplayServer.MAIN_WINDOW_ID)
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var mintty_pos := str(usable.position.x) + "," + str(usable.position.y)
	var mintty_path := GitUtils.find_windows_git_mintty()
	var pid := OS.create_process(
			mintty_path,
			PackedStringArray([
				"--pos", mintty_pos,
				"--window", "max",
				"--title", "Git Diff",
				"--option", terminal_background,
				"--option", terminal_foreground,
				"--option", terminal_cursor,
				"--option", selection_background,
				"--option", selection_foreground,
				"--option", "KeyFunctions=Esc:close",
				"--option", "ConfirmExit=no",
				"/usr/bin/bash", "--noprofile", "--norc", "-c", bash_command
			]),
			false
	)
	if pid <= 0:
		Alert.alert("Cannot open Delta", ColorBase.error)
	pass


## Opens only one file's section from a cached agent run patch.
static func open_file_diff(patch_path: String, relative_path: String) -> bool:
	if StringUtils.is_blank(patch_path) or not FileAccess.file_exists(patch_path):
		return false
	var file_patch_path := patch_path.get_basename() + "." + relative_path.sha256_text() + ".patch"
	if not FileAccess.file_exists(file_patch_path):
		var patch := FileAccess.get_file_as_string(patch_path)
		var file_patch := StringUtils.EMPTY
		var normalized_path := relative_path.replace("\\", "/")
		# A Git patch stores every changed file in a separate section beginning with `diff --git`.
		# The first condition handles ordinary edits where both header paths are the same. The remaining
		# conditions inspect the old/new file markers and rename metadata so added, deleted, and renamed
		# files are also found. Only the matching section is cached and later passed to Delta.
		for section in patch.split("diff --git ", false):
			var candidate := "diff --git " + section
			if candidate.begins_with("diff --git a/" + normalized_path + " b/" + normalized_path + FileUtils.NEWLINE_LF) \
					or candidate.contains(FileUtils.NEWLINE_LF + "--- a/" + normalized_path + FileUtils.NEWLINE_LF) \
					or candidate.contains(FileUtils.NEWLINE_LF + "+++ b/" + normalized_path + FileUtils.NEWLINE_LF) \
					or candidate.contains(FileUtils.NEWLINE_LF + "rename from " + normalized_path + FileUtils.NEWLINE_LF) \
					or candidate.contains(FileUtils.NEWLINE_LF + "rename to " + normalized_path + FileUtils.NEWLINE_LF):
				file_patch = candidate
				break
		if StringUtils.is_blank(file_patch) or not FileUtils.write_string_to_file(file_patch_path, file_patch):
			return false
	open_diff(file_patch_path)
	return true
