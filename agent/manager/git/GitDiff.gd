class_name GitDiff
extends Object

const DIFF_CACHE_SUBDIR := ".gai/cache/diff"
const MAX_DIFF_CACHE_BYTES := 16 * FileUtils.BYTES_PER_MB
const DELTA_EXECUTABLE_PATH := ".dependency/delta/delta.exe"

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
	var patch_path := await async_cache_diff(git, reference)
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
static func async_diff_file_stats(git: GitUtils.Git, reference: String) -> PackedStringArray:
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


## Caches the completed agent run patch so later workspace changes cannot alter this bubble's diff.
static func async_cache_diff(git: GitUtils.Git, reference: String) -> String:
	if StringUtils.is_blank(reference):
		return StringUtils.EMPTY
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
	var delta_path := FileUtils.globalize_writable_path(DELTA_EXECUTABLE_PATH)
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
