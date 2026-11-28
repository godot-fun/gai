extends RefCounted

## CacheManager — every cache sits in the folder shared by all workspaces, outside any project.


static func cache_dirs_live_in_shared_data_test() -> void:
	var shared_root := Workspace.get_shared_data_dir()
	assert(CacheManager.get_diff_cache_dir().begins_with(shared_root))
	assert(CacheManager.get_web_screenshot_cache_dir().begins_with(shared_root))
	assert(CacheManager.get_clipboard_cache_dir().begins_with(shared_root))
	assert(CacheManager.get_markdown_image_cache_dir().begins_with(shared_root))
	pass


static func cache_dirs_stay_out_of_cloud_test() -> void:
	# Steam Cloud must never carry caches, so no cache dir may live under the cloud folder.
	var cloud_root := Workspace.get_cloud_data_dir()
	assert(not CacheManager.get_diff_cache_dir().begins_with(cloud_root))
	assert(not CacheManager.get_web_screenshot_cache_dir().begins_with(cloud_root))
	assert(not CacheManager.get_clipboard_cache_dir().begins_with(cloud_root))
	assert(not CacheManager.get_markdown_image_cache_dir().begins_with(cloud_root))
	pass
