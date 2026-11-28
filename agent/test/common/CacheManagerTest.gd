extends RefCounted

## CacheManager — every cache sits in the app-wide data folder, outside any workspace.


static func cache_dirs_are_app_scoped_test() -> void:
	var app_root := AppDataDir.get_dir_path("", AppDataDir.Scope.APP)
	assert(CacheManager.get_diff_cache_dir().begins_with(app_root))
	assert(CacheManager.get_web_screenshot_cache_dir().begins_with(app_root))
	assert(CacheManager.get_clipboard_cache_dir().begins_with(app_root))
	assert(CacheManager.get_markdown_image_cache_dir().begins_with(app_root))
	pass


static func cache_dirs_stay_out_of_cloud_test() -> void:
	# Steam Cloud must never carry caches, so no cache dir may live under Scope.CLOUD.
	var cloud_root := AppDataDir.get_dir_path("", AppDataDir.Scope.CLOUD)
	assert(not CacheManager.get_diff_cache_dir().begins_with(cloud_root))
	assert(not CacheManager.get_web_screenshot_cache_dir().begins_with(cloud_root))
	assert(not CacheManager.get_clipboard_cache_dir().begins_with(cloud_root))
	assert(not CacheManager.get_markdown_image_cache_dir().begins_with(cloud_root))
	pass
