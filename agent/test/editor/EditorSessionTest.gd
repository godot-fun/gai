extends RefCounted

const TREE_DIR := "user://editor_file_tree_test"
const SESSION_DIR := "user://editor_tabs_test"


static func editor_document_skips_hidden_names_test() -> void:
	assert(EditorDocument.is_skipped_name("."))
	assert(EditorDocument.is_skipped_name(".."))
	assert(EditorDocument.is_skipped_name(".git"))
	assert(EditorDocument.is_skipped_name(".godot"))
	assert(EditorDocument.is_skipped_name(".gai"))
	assert(not EditorDocument.is_skipped_name("src"))
	assert(not EditorDocument.is_skipped_name("readme.md"))
	pass


static func editor_document_open_and_save_test() -> void:
	var directory := FileUtils.normalize_path(ProjectSettings.globalize_path(SESSION_DIR))
	var note_path := directory.path_join("note.md")
	var other_path := directory.path_join("other.txt")
	var image_path := directory.path_join("pic.png")
	var binary_path := directory.path_join("blob.bin")
	FileUtils.write_string_to_file(note_path, "one")
	FileUtils.write_string_to_file(other_path, "two")
	FileUtils.write_string_to_file(image_path, "not-an-image")
	FileUtils.write_byte_array_to_file(binary_path, PackedByteArray([1, 0, 2]))

	assert(EditorDocument.can_edit(note_path))
	assert(not EditorDocument.can_edit(image_path))
	assert(not EditorDocument.can_edit(binary_path))
	assert(not EditorDocument.can_edit(directory.path_join("missing.md")))

	var tabs := EditorTabs.new()
	var note := tabs.open_file(note_path)
	assert(note != null)
	assert(note.text == "one")
	assert(not note.is_dirty())
	assert(tabs.active_index == 0)
	note.text = "one!"
	assert(note.is_dirty())
	assert(tabs.dirty_documents().size() == 1)

	var other := tabs.open_file(other_path)
	assert(other != null)
	assert(tabs.documents.size() == 2)
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
	assert(tabs.documents.size() == 1)
	assert(tabs.active() == other)
	tabs.close_at(0)
	assert(tabs.active() == null)
	assert(tabs.dirty_documents().is_empty())
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

	var src := tree.get_root().get_first_child()
	tree.ensure_loaded(src)
	var nested := child_names(src)
	assert(nested.size() == 2)
	assert(nested[0] == "a.md")
	assert(nested[1] == "b.txt")
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
