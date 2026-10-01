## FileUtils — file read, write, and directory helpers.


func FileUtils_globalize_writable_path_test() -> void:
	var abs_user := FileUtils.globalize_writable_path("user://fileutils_abs_test.txt")
	assert(not abs_user.begins_with("user://"))
	assert(abs_user == ProjectSettings.globalize_path("user://fileutils_abs_test.txt"))
	assert(FileUtils.globalize_writable_path("C:/tmp/a.wav") == "C:/tmp/a.wav")

	var root := ProjectSettings.globalize_path("user://fileutils_parent_" + str(TimeUtils.now()) + "_" + str(randi()))
	var file_path := root.path_join("nested/out.txt")
	assert(not DirAccess.dir_exists_absolute(file_path.get_base_dir()))
	var prepared := FileUtils.globalize_writable_path(file_path)
	assert(prepared == file_path)
	assert(DirAccess.dir_exists_absolute(file_path.get_base_dir()))
	FileUtils.delete_file_or_directory(root)
	pass


func FileUtils_read_write_test() -> void:
	var path: String = "./zfoo_test_temp.txt"
	var content: String = "hello godot!"
	FileUtils.write_string_to_file(path, content)
	var read_content := FileUtils.read_file_to_string(path)
	assert(content == read_content)
	FileUtils.delete_file_or_directory(path)
	pass


func read_file_to_string_rejects_nul_test() -> void:
	var path := ProjectSettings.globalize_path("user://fileutils_nul_test.bin")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0x61, 0x00, 0x62]))
	file = null
	assert(FileUtils.read_file_to_string(path) == StringUtils.EMPTY)
	assert(FileUtils.read_file_to_lines(path).is_empty())
	FileUtils.delete_file_or_directory(path)
	pass


func get_all_directories_in_folder_test() -> void:
	var root := create_fixture_tree()
	var top := relative_paths(root, FileUtils.get_all_directories_in_folder(root, false))
	top.sort()
	assert(top.has("src"))
	assert(top.has(".git"))
	assert(not top.has("src/nested"))
	var all := relative_paths(root, FileUtils.get_all_directories_in_folder(root, true))
	all.sort()
	assert(all.has("src/nested"))
	assert(all.has(".git/objects"))
	remove_fixture_tree(root)
	pass


func delete_file_or_directory_test() -> void:
	var root := create_fixture_tree()
	var file_path := root.path_join("src/nested/file.txt")
	FileUtils.write_string_to_file(file_path, "content")
	assert(FileUtils.delete_file_or_directory(file_path))
	assert(not FileAccess.file_exists(file_path))
	assert(FileUtils.delete_file_or_directory(root))
	assert(not DirAccess.dir_exists_absolute(root))
	assert(not FileUtils.delete_file_or_directory(root))
	pass


func cleanup_cache_folder_trims_oldest_files_test() -> void:
	var cache_dir := ProjectSettings.globalize_path("user://fileutils_cache_trim_" + str(TimeUtils.now()) + "_" + str(randi()))
	assert(DirAccess.make_dir_recursive_absolute(cache_dir) == OK)
	var oldest_path := cache_dir.path_join("oldest.bin")
	var middle_path := cache_dir.path_join("middle.bin")
	var newest_path := cache_dir.path_join("newest.bin")
	var file_paths: Array[String] = [oldest_path, middle_path, newest_path]
	for index in file_paths.size():
		var file_path := file_paths[index]
		var file := FileAccess.open(file_path, FileAccess.WRITE)
		assert(file != null)
		file.store_buffer(PackedByteArray([1, 2, 3, 4]))
		file = null
		if index < file_paths.size() - 1:
			await gdf.gdf_node.get_tree().create_timer(1.1).timeout
	FileUtils.cleanup_cache_folder(cache_dir, 8)
	assert(not FileAccess.file_exists(oldest_path))
	assert(FileAccess.file_exists(middle_path))
	assert(FileAccess.file_exists(newest_path))
	FileUtils.delete_file_or_directory(cache_dir)
	pass


static func relative_paths(search_root: String, paths: Array[String]) -> Array[String]:
	var relative: Array[String] = []
	var root := search_root.replace("\\", "/").rstrip("/")
	for path in paths:
		var normalized_path := path.replace("\\", "/")
		relative.append(normalized_path.substr(root.length() + 1))
	return relative


static func create_fixture_tree() -> String:
	var root := ProjectSettings.globalize_path("user://fileutils_dirs_" + str(TimeUtils.now()) + "_" + str(randi()))
	DirAccess.make_dir_recursive_absolute(root.path_join("src/nested"))
	DirAccess.make_dir_recursive_absolute(root.path_join(".git/objects"))
	return root


static func remove_fixture_tree(root: String) -> void:
	FileUtils.delete_file_or_directory(root)
	pass
