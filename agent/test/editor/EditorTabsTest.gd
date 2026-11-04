extends RefCounted

const TREE_DIR := "user://editor_file_tree_test"
const FILES_DIR := "user://editor_tabs_test"


static func editor_file_icon_matches_name_and_extension_test() -> void:
	assert(EditorFileIcon.icon_path("res://player.gd", false).ends_with("godot.svg"))
	assert(EditorFileIcon.icon_path("C:/src/Player.GD", false).ends_with("godot.svg"))
	assert(EditorFileIcon.icon_path("res://scene.tscn", false).ends_with("godot-assets.svg"))
	assert(EditorFileIcon.icon_path("Dockerfile", false).ends_with("docker.svg"))
	assert(EditorFileIcon.icon_path("Makefile", false).ends_with("makefile.svg"))
	assert(EditorFileIcon.icon_path(".editorconfig", false).ends_with("editorconfig.svg"))
	assert(EditorFileIcon.icon_path(".gitignore", false).ends_with("git.svg"))
	assert(EditorFileIcon.icon_path("notes.md", false).ends_with("markdown.svg"))
	assert(EditorFileIcon.icon_path("pic.png", false).ends_with("image.svg"))
	assert(EditorFileIcon.icon_path("data.json", false).ends_with("json.svg"))
	assert(EditorFileIcon.icon_path("src", true).ends_with("folder.svg"))
	assert(EditorFileIcon.icon_path("unknown.zzz", false).ends_with("file.svg"))
	pass


static func editor_tabs_open_and_save_test() -> void:
	var directory := FileUtils.normalize_path(ProjectSettings.globalize_path(FILES_DIR))
	var note_path := directory.path_join("note.md")
	var other_path := directory.path_join("other.txt")
	var image_path := directory.path_join("pic.png")
	var binary_path := directory.path_join("blob.bin")
	FileUtils.write_string_to_file(note_path, "one")
	FileUtils.write_string_to_file(other_path, "two")
	FileUtils.write_string_to_file(image_path, "not-an-image")
	FileUtils.write_byte_array_to_file(binary_path, PackedByteArray([1, 0, 2]))

	assert(EditorTabs.can_open(note_path))
	assert(not EditorTabs.can_open(image_path))
	assert(not EditorTabs.can_open(binary_path))
	assert(not EditorTabs.can_open(directory.path_join("missing.md")))

	var tabs := EditorTabs.new()
	var note := tabs.open_file(note_path)
	assert(note != null)
	assert(note.text == "one")
	assert(not note.is_dirty())
	assert(tabs.active_index == 0)
	note.text = "one!"
	assert(note.is_dirty())
	assert(tabs.dirty_files().size() == 1)

	var other := tabs.open_file(other_path)
	assert(other != null)
	assert(tabs.files.size() == 2)
	assert(tabs.active() == other)
	var again := tabs.open_file(note_path)
	assert(again == note)
	assert(again.text == "one!")
	assert(tabs.active_index == 0)
	assert(note.save() == OK)
	assert(not note.is_dirty())
	assert(FileUtils.read_file_to_string(note_path) == "one!")
	assert(tabs.open_file(image_path) == null)
	assert(tabs.active_index == 0)

	tabs.close_at(0)
	assert(tabs.files.size() == 1)
	assert(tabs.active() == other)
	tabs.close_at(0)
	assert(tabs.active() == null)
	assert(tabs.dirty_files().is_empty())
	pass


static func editor_file_tree_lists_workspace_test() -> void:
	var root_path := FileUtils.normalize_path(ProjectSettings.globalize_path(TREE_DIR))
	DirAccess.make_dir_recursive_absolute(root_path)
	DirAccess.make_dir_recursive_absolute(root_path.path_join(".git"))
	DirAccess.make_dir_recursive_absolute(root_path.path_join(".gai"))
	DirAccess.make_dir_recursive_absolute(root_path.path_join("src/.godot"))
	FileUtils.write_string_to_file(root_path.path_join("readme.md"), "r")
	FileUtils.write_string_to_file(root_path.path_join("src/a.md"), "a")
	FileUtils.write_string_to_file(root_path.path_join("src/b.txt"), "b")

	var tree := EditorFileTree.new()
	gdf.gdf_node.add_child(tree)
	tree.reload(root_path)
	var top := child_names(tree.get_root())
	assert(top.size() == 2)
	assert(top[0] == "src")
	assert(top[1] == "readme.md")
	assert(not top.has(".git"))
	assert(not top.has(".gai"))

	var src := tree.get_root().get_first_child()
	tree.ensure_loaded(src)
	var nested := child_names(src)
	assert(nested.size() == 2)
	assert(nested[0] == "a.md")
	assert(nested[1] == "b.txt")
	tree.free()
	pass


static func editor_file_tree_opens_on_double_click_test() -> void:
	var root_path := FileUtils.normalize_path(ProjectSettings.globalize_path(TREE_DIR + "_open"))
	DirAccess.make_dir_recursive_absolute(root_path.path_join("src"))
	var note_path := FileUtils.normalize_path(root_path.path_join("note.md"))
	FileUtils.write_string_to_file(note_path, "n")

	var tree := EditorFileTree.new()
	gdf.gdf_node.add_child(tree)
	tree.reload(root_path)
	var opened: Array[String] = []
	tree.file_selected.connect(func(path: String) -> void: opened.append(path))

	var folder := tree.get_root().get_first_child()
	folder.select(0)
	assert(opened.is_empty())
	tree.on_item_activated()
	assert(opened.is_empty())
	assert(not folder.collapsed)

	var note := folder.get_next()
	note.select(0)
	assert(opened.is_empty())
	tree.on_item_activated()
	assert(opened.size() == 1)
	assert(FileUtils.normalize_path(opened[0]) == note_path)
	tree.free()
	pass


static func editor_file_tree_delete_removes_selected_file_test() -> void:
	var root_path := FileUtils.normalize_path(ProjectSettings.globalize_path(TREE_DIR + "_delete"))
	DirAccess.make_dir_recursive_absolute(root_path.path_join("src"))
	var note_path := FileUtils.normalize_path(root_path.path_join("note.md"))
	var other_path := FileUtils.normalize_path(root_path.path_join("other.md"))
	FileUtils.write_string_to_file(note_path, "n")
	FileUtils.write_string_to_file(other_path, "o")

	var tree := EditorFileTree.new()
	gdf.gdf_node.add_child(tree)
	tree.reload(root_path)
	var deleted: Array[String] = []
	tree.file_deleted.connect(func(path: String) -> void: deleted.append(path))

	var folder := tree.get_root().get_first_child()
	folder.select(0)
	assert(not tree.delete_selected())
	assert(deleted.is_empty())
	assert(DirAccess.dir_exists_absolute(root_path.path_join("src")))

	var note := folder.get_next()
	note.select(0)
	assert(tree.delete_selected())
	assert(deleted.size() == 1)
	assert(FileUtils.normalize_path(deleted[0]) == note_path)
	assert(not FileAccess.file_exists(note_path))
	assert(FileAccess.file_exists(other_path))
	assert(tree.get_selected().get_text(0) == "other.md")
	tree.free()
	pass


static func editor_file_tree_respects_gitignore_test() -> void:
	var root_path := FileUtils.normalize_path(ProjectSettings.globalize_path(TREE_DIR + "_ignore"))
	DirAccess.make_dir_recursive_absolute(root_path.path_join("node_modules/pkg"))
	DirAccess.make_dir_recursive_absolute(root_path.path_join("target/debug"))
	FileUtils.write_string_to_file(root_path.path_join("node_modules/pkg/index.js"), "x")
	FileUtils.write_string_to_file(root_path.path_join("target/debug/out.txt"), "y")
	FileUtils.write_string_to_file(root_path.path_join("visible.md"), "v")
	FileUtils.write_string_to_file(root_path.path_join("visible.md.uid"), "uid")
	FileUtils.write_string_to_file(root_path.path_join("sprite.png.import"), "import")

	var tree := EditorFileTree.new()
	gdf.gdf_node.add_child(tree)
	tree.reload(root_path)
	var top := child_names(tree.get_root())
	assert(top.size() == 1)
	assert(top[0] == "visible.md")
	tree.free()
	pass


static func child_names(item: TreeItem) -> Array[String]:
	var names: Array[String] = []
	var child := item.get_first_child()
	while child != null:
		if not child.get_meta("placeholder", false):
			names.append(child.get_text(0))
		child = child.get_next()
	return names
