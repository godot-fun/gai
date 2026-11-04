class_name EditorFileTree
extends Tree

## Workspace file tree. Folders load their children the first time they expand.
## Entries follow [member GitIgnore.ignore_rules] ([GlobUtils.GitIgnoreMatcher], same as glob / grep / completion),
## and hide Godot `.uid` / `.import` sidecar files.

## A file row was activated with a double-click or Enter. A single click only selects the row.
signal file_selected(path: String)
## The selected file was moved to the system trash. Folders are left in place.
signal file_deleted(path: String)

var root_path: String = ""


func _ready() -> void:
	hide_root = true
	column_titles_visible = false
	hide_folding = false
	allow_reselect = false
	select_mode = Tree.SELECT_ROW
	item_collapsed.connect(on_item_collapsed)
	item_activated.connect(on_item_activated)
	pass


func reload(path: String) -> void:
	root_path = EditorDocument.normalize(path)
	clear()
	var root := create_item()
	populate(root, root_path)
	pass


func on_item_collapsed(item: TreeItem) -> void:
	# create_item() returns null while this signal is running, so load on the next frame.
	if item == null or item.collapsed or bool(item.get_meta("loaded", false)):
		return
	ensure_loaded.call_deferred(item)
	pass


func _gui_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_DELETE:
		return
	if delete_selected():
		accept_event()
	pass


## Moves the selected file to the system trash and drops its row. Directories are not removed.
func delete_selected() -> bool:
	var item := get_selected()
	if item == null or bool(item.get_meta("placeholder", false)):
		return false
	var path := str(item.get_metadata(0))
	if path.is_empty() or DirAccess.dir_exists_absolute(path) or not FileAccess.file_exists(path):
		return false
	var error := OS.move_to_trash(path)
	if error != OK:
		Log.error("editor delete failed path:[{}] err:[{}]", path, error_string(error))
		Alert.alert(I18n.t("editor.delete_failed"), Colors.error)
		return false
	var next := item.get_next()
	if next == null or bool(next.get_meta("placeholder", false)):
		next = item.get_prev()
	item.free()
	if next != null and not bool(next.get_meta("placeholder", false)):
		next.select(0)
	file_deleted.emit(path)
	Alert.alert(StringUtils.format(I18n.t("editor.delete_succeeded"), path.get_file()), Colors.success)
	return true


func on_item_activated() -> void:
	var item := get_selected()
	if item == null or item.get_meta("placeholder", false):
		return
	var path := str(item.get_metadata(0))
	if path.is_empty():
		return
	if DirAccess.dir_exists_absolute(path):
		item.collapsed = not item.collapsed
		return
	file_selected.emit(path)
	pass


func ensure_loaded(item: TreeItem) -> void:
	if item == null or item.get_meta("loaded", false):
		return
	var path := str(item.get_metadata(0))
	var placeholder := item.get_first_child()
	if placeholder != null:
		item.remove_child(placeholder)
	populate(item, path)
	item.set_meta("loaded", true)
	pass


func populate(parent: TreeItem, dir_path: String) -> void:
	var directory := DirAccess.open(dir_path)
	if directory == null:
		return
	var ignore := GlobUtils.GitIgnoreMatcher.from_lines(GitIgnore.ignore_rules)
	var root_prefix := root_path.replace("\\", "/")
	if not root_prefix.ends_with("/"):
		root_prefix += "/"
	var names: Array[String] = []
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var full_path := EditorDocument.normalize(dir_path.path_join(entry_name))
			var relative := EditorDocument.normalize(full_path).replace("\\", "/")
			if relative.begins_with(root_prefix):
				relative = relative.substr(root_prefix.length())
			var is_directory := DirAccess.dir_exists_absolute(full_path)
			var show := ignore.may_enter_dir(relative) if is_directory else not ignore.is_ignored(relative, false)
			if show and (is_directory or (not entry_name.ends_with(".uid") and not entry_name.ends_with(".import"))):
				names.append(entry_name)
		entry_name = directory.get_next()
	directory.list_dir_end()
	names.sort_custom(func(a: String, b: String) -> bool: return entry_before(dir_path, a, b))
	for entry in names:
		add_entry(parent, dir_path, entry)
	pass


func add_entry(parent: TreeItem, dir_path: String, entry_name: String) -> void:
	var item := create_item(parent)
	if item == null:
		return
	var full_path := EditorDocument.normalize(dir_path.path_join(entry_name))
	var is_directory := DirAccess.dir_exists_absolute(full_path)
	item.set_text(0, entry_name)
	item.set_tooltip_text(0, full_path)
	item.set_metadata(0, full_path)
	var icon := EditorFileIcon.texture(full_path, is_directory)
	if icon != null:
		item.set_icon(0, icon)
	if is_directory:
		var placeholder := create_item(item)
		if placeholder != null:
			placeholder.set_meta("placeholder", true)
		item.collapsed = true
	pass


static func entry_before(dir_path: String, a: String, b: String) -> bool:
	var a_dir := DirAccess.dir_exists_absolute(dir_path.path_join(a))
	var b_dir := DirAccess.dir_exists_absolute(dir_path.path_join(b))
	if a_dir != b_dir:
		return a_dir
	return a.naturalnocasecmp_to(b) < 0
