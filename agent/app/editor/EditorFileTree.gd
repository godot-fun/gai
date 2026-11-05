class_name EditorFileTree
extends Tree

## Workspace file tree. Folders load their children the first time they expand.
## Entries follow [member GitIgnore.ignore_rules] ([GlobUtils.GitIgnoreMatcher], same as glob / grep / completion),
## and hide Godot `.uid` / `.import` sidecar files.

enum MenuAction { NEW_FILE, NEW_FOLDER, COPY, PASTE, DELETE }
enum CreateKind { FILE, FOLDER }

var root_path: String = ""
var copied_path: String = ""
var context_path: String = ""
var pending_create_kind: CreateKind = CreateKind.FILE
var menu: PopupMenu
var name_dialog: ConfirmationDialog
var name_edit: LineEdit
var delete_dialog: ConfirmationDialog


func _ready() -> void:
	hide_root = true
	column_titles_visible = false
	hide_folding = false
	allow_reselect = false
	select_mode = Tree.SELECT_ROW
	item_collapsed.connect(on_item_collapsed)
	item_activated.connect(on_item_activated)
	gui_input.connect(on_gui_input)
	EditorEvents.events.file_created.connect(on_file_created)
	EditorEvents.events.files_changed.connect(on_files_changed)
	pass


func ensure_context_ui() -> void:
	if menu != null:
		return
	build_menu()
	build_dialogs()
	pass


func build_menu() -> void:
	menu = PopupMenu.new()
	menu.id_pressed.connect(on_menu_action)
	add_child(menu)
	pass


func build_dialogs() -> void:
	name_dialog = ConfirmationDialog.new()
	name_dialog.exclusive = true
	name_dialog.min_size.x = ControlSize.image_lg
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size.x = ControlSize.image_sm
	name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_edit.text_submitted.connect(func(_text: String) -> void: name_dialog.get_ok_button().pressed.emit())
	name_dialog.get_label().get_parent().add_child(name_edit)
	name_dialog.confirmed.connect(on_name_confirmed)
	add_child(name_dialog)
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.exclusive = true
	delete_dialog.min_size = Vector2i(420, 140)
	delete_dialog.confirmed.connect(delete_context_entry)
	add_child(delete_dialog)
	pass


func apply_menu_theme() -> void:
	ensure_context_ui()
	PopupMenuStyle.apply(menu)
	LineEditStyle.apply(name_edit)
	ConfirmationDialogStyle.apply(name_dialog)
	ConfirmationDialogStyle.apply(delete_dialog)
	pass


func apply_locale() -> void:
	ensure_context_ui()
	name_dialog.ok_button_text = I18n.t("common.create")
	name_dialog.cancel_button_text = I18n.t("common.cancel")
	delete_dialog.title = I18n.t("editor.delete_title")
	delete_dialog.ok_button_text = I18n.t("common.delete")
	delete_dialog.cancel_button_text = I18n.t("common.cancel")
	pass


func reload(path: String) -> void:
	root_path = FileUtils.normalize_path(path)
	clear()
	var root := create_item()
	populate(root, root_path)
	pass


func on_file_created(path: String) -> void:
	refresh_directory(path.get_base_dir())
	pass


func on_files_changed(parent_path: String) -> void:
	refresh_directory(parent_path)
	pass


func refresh_directory(path: String) -> void:
	var normalized := FileUtils.normalize_path(path)
	var item := get_root() if normalized == root_path else find_item_by_path(get_root(), normalized)
	if item == null:
		return
	if item != get_root() and not bool(item.get_meta("loaded", false)):
		return
	var collapsed := item.collapsed
	var child := item.get_first_child()
	while child != null:
		var next := child.get_next()
		child.free()
		child = next
	populate(item, normalized)
	if item != get_root():
		item.set_meta("loaded", true)
		item.collapsed = collapsed
	pass


func find_item_by_path(parent: TreeItem, path: String) -> TreeItem:
	if parent == null:
		return null
	var child := parent.get_first_child()
	while child != null:
		if not bool(child.get_meta("placeholder", false)):
			if FileUtils.normalize_path(str(child.get_metadata(0))) == path:
				return child
			var found := find_item_by_path(child, path)
			if found != null:
				return found
		child = child.get_next()
	return null


func select_path(path: String) -> void:
	var item := find_item_by_path(get_root(), FileUtils.normalize_path(path))
	if item != null:
		item.select(0)
	pass


func on_item_collapsed(item: TreeItem) -> void:
	# create_item() returns null while this signal is running, so load on the next frame.
	if item == null or item.collapsed or bool(item.get_meta("loaded", false)):
		return
	ensure_loaded.call_deferred(item)
	pass


## Deletes the selected file or folder and drops its row.
func delete_selected() -> bool:
	var item := get_selected()
	if item == null or bool(item.get_meta("placeholder", false)):
		return false
	var path := FileUtils.normalize_path(str(item.get_metadata(0)))
	if path.is_empty() or not FileUtils.is_relative_to(path, root_path):
		return false
	var error := FileUtils.delete_file_or_directory(path)
	if error != OK:
		Log.error("editor delete failed path:[{}] err:[{}]", path, error_string(error))
		Alert.alert(I18n.t("editor.delete_failed"), Colors.error)
		return false
	EditorEvents.events.file_deleted.emit(path)
	EditorEvents.events.files_changed.emit(path.get_base_dir())
	var parent := get_root() if path.get_base_dir() == root_path else find_item_by_path(get_root(), path.get_base_dir())
	if parent != null and parent.get_first_child() != null:
		parent.get_first_child().select(0)
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
	EditorEvents.events.file_selected.emit(path)
	pass


func on_gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_RIGHT:
		return
	ensure_context_ui()
	var item := get_item_at_position(mouse.position)
	if item != null and not bool(item.get_meta("placeholder", false)):
		item.select(0)
		context_path = FileUtils.normalize_path(str(item.get_metadata(0)))
	else:
		context_path = ""
	show_context_menu(Vector2i(mouse.position))
	accept_event()
	pass


func target_directory(path: String) -> String:
	if path.is_empty():
		return root_path
	if DirAccess.dir_exists_absolute(path):
		return path
	return path.get_base_dir()


func copy_selected() -> bool:
	var item := get_selected()
	if item == null or bool(item.get_meta("placeholder", false)):
		return false
	var path := FileUtils.normalize_path(str(item.get_metadata(0)))
	if path.is_empty() or not FileUtils.is_relative_to(path, root_path) or not FileUtils.exists(path):
		return false
	copied_path = path
	return true


func show_context_menu(local_position: Vector2i) -> void:
	menu.clear()
	menu.add_item(I18n.t("editor.new_file"), MenuAction.NEW_FILE)
	menu.add_item(I18n.t("editor.new_folder"), MenuAction.NEW_FOLDER)
	menu.add_separator()
	menu.add_item(I18n.t("common.copy"), MenuAction.COPY)
	menu.set_item_disabled(menu.item_count - 1, context_path.is_empty())
	menu.add_item(I18n.t("editor.paste"), MenuAction.PASTE)
	menu.set_item_disabled(menu.item_count - 1, copied_path.is_empty() or not FileUtils.exists(copied_path))
	menu.add_separator()
	menu.add_item(I18n.t("common.delete"), MenuAction.DELETE)
	menu.set_item_disabled(menu.item_count - 1, context_path.is_empty())
	PopupMenuStyle.apply(menu)
	var popup_position := Vector2i(global_position) + local_position
	menu.popup(Rect2i(popup_position, Vector2i.ZERO))
	pass


func on_menu_action(action: int) -> void:
	match action:
		MenuAction.NEW_FILE:
			prompt_create(CreateKind.FILE)
		MenuAction.NEW_FOLDER:
			prompt_create(CreateKind.FOLDER)
		MenuAction.COPY:
			copy_selected()
		MenuAction.PASTE:
			paste_copied()
		MenuAction.DELETE:
			prompt_delete()
	pass


func prompt_create(kind: CreateKind) -> void:
	pending_create_kind = kind
	name_dialog.title = I18n.t("editor.new_folder") if kind == CreateKind.FOLDER else I18n.t("editor.new_file")
	name_dialog.dialog_text = I18n.t("editor.name_prompt")
	name_edit.text = ""
	name_dialog.popup_centered()
	name_edit.grab_focus.call_deferred()
	pass


func on_name_confirmed() -> void:
	var entry_name := name_edit.text.strip_edges()
	if not FileUtils.is_valid_file_name(entry_name):
		Alert.alert(I18n.t("editor.invalid_name"), Colors.error)
		return
	var directory := target_directory(context_path)
	var path := FileUtils.normalize_path(directory.path_join(entry_name))
	if FileUtils.exists(path):
		Alert.alert(I18n.t("editor.name_exists"), Colors.error)
		return
	var error := DirAccess.make_dir_recursive_absolute(path) if pending_create_kind == CreateKind.FOLDER else FileUtils.write_string_to_file(path, "")
	if error != OK:
		Alert.alert(I18n.t("editor.create_failed"), Colors.error)
		return
	EditorEvents.events.file_created.emit(path)
	select_path(path)
	Alert.alert(StringUtils.format(I18n.t("editor.created"), entry_name), Colors.success)
	pass


func paste_copied() -> void:
	if copied_path.is_empty() or not FileUtils.exists(copied_path):
		Alert.alert(I18n.t("editor.copy_source_missing"), Colors.error)
		return
	var directory := target_directory(context_path)
	var target := FileUtils.normalize_path(directory.path_join(copied_path.get_file()))
	if FileUtils.exists(target):
		Alert.alert(I18n.t("editor.name_exists"), Colors.error)
		return
	var error := FileUtils.copy(copied_path, target)
	if error != OK:
		Alert.alert(I18n.t("editor.paste_failed"), Colors.error)
		return
	EditorEvents.events.file_created.emit(target)
	select_path(target)
	Alert.alert(StringUtils.format(I18n.t("editor.pasted"), target.get_file()), Colors.success)
	pass


func prompt_delete() -> void:
	delete_dialog.dialog_text = StringUtils.format(I18n.t("editor.delete_confirm"), context_path.get_file())
	delete_dialog.popup_centered()
	pass


func delete_context_entry() -> void:
	var selected := get_selected()
	if selected == null or FileUtils.normalize_path(str(selected.get_metadata(0))) != context_path:
		return
	delete_selected()
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
	var root_prefix := root_path
	if not root_prefix.ends_with("/"):
		root_prefix += "/"
	var names: Array[String] = []
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var full_path := FileUtils.normalize_path(dir_path.path_join(entry_name))
			var relative := full_path
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
	var full_path := FileUtils.normalize_path(dir_path.path_join(entry_name))
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
