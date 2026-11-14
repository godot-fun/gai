class_name FileDialogHelper
extends Object

## Persists the recent-directory list shared by all application FileDialogs.

const RECENT_FILE := "user://file_dialog_recent.json"
const MAX_RECENT_DIRECTORIES := 20

static var recent_directories_restored := false


## Restores recent directories once per process and saves them whenever this dialog closes.
static func apply(dialog: FileDialog) -> void:
	if not recent_directories_restored:
		restore_recent_directories()
		recent_directories_restored = true
	var visibility_callable := on_dialog_visibility_changed.bind(dialog)
	if not dialog.visibility_changed.is_connected(visibility_callable):
		dialog.visibility_changed.connect(visibility_callable)
	pass


static func restore_recent_directories() -> void:
	var recents := PackedStringArray()
	for line: String in FileUtils.read_file_to_lines(RECENT_FILE):
		var path := FileUtils.normalize_path(line.strip_edges())
		if DirAccess.dir_exists_absolute(path) and not recents.has(path):
			recents.append(path)
			if recents.size() >= MAX_RECENT_DIRECTORIES:
				break
	FileDialog.set_recent_list(recents)
	pass


static func on_dialog_visibility_changed(dialog: FileDialog) -> void:
	if not dialog.visible:
		persist_recent_directories()
	pass


static func persist_recent_directories() -> void:
	var recents := PackedStringArray()
	for recent: String in FileDialog.get_recent_list():
		var path := FileUtils.normalize_path(recent)
		if DirAccess.dir_exists_absolute(path) and not recents.has(path):
			recents.append(path)
			if recents.size() >= MAX_RECENT_DIRECTORIES:
				break
	FileUtils.write_string_to_file(RECENT_FILE, "\n".join(recents))
	pass
