class_name CacheManager
extends Object

## Caches live in the app-wide data folder ([constant AppDataDir.Scope.APP]), not in the workspace:
## every entry is either content-addressed (markdown images by URL) or a UUID-named artifact
## (clipboard, screenshots, diff bundles), so one shared folder avoids re-downloading per project and
## keeps the caps below meaningful — [method cleanup_caches] only ever sees this one folder.

const DIFF_CACHE_SUBDIR := "cache/diff"
const MAX_DIFF_CACHE_BYTES := 128 * FileUtils.BYTES_PER_MB
const WEB_SCREENSHOT_SUBDIR := "cache/screenshot"
const MAX_WEB_SCREENSHOT_CACHE_BYTES := 512 * FileUtils.BYTES_PER_MB
const CLIPBOARD_SUBDIR := "cache/clipboard"
const MAX_CLIPBOARD_CACHE_BYTES := 512 * FileUtils.BYTES_PER_MB
const MARKDOWN_IMAGE_SUBDIR := "cache/markdown"
const MAX_MARKDOWN_IMAGE_CACHE_BYTES := 512 * FileUtils.BYTES_PER_MB


static func _static_init() -> void:
	# ExecutorHelper drains its queue on gdf.shutdown(); a raw worker pool task could still be running
	# when the engine exits.
	ExecutorHelper.execute(cleanup_caches)
	pass


static func get_diff_cache_dir() -> String:
	return AppDataDir.get_dir_path(DIFF_CACHE_SUBDIR, AppDataDir.Scope.APP)


static func get_web_screenshot_cache_dir() -> String:
	return AppDataDir.get_dir_path(WEB_SCREENSHOT_SUBDIR, AppDataDir.Scope.APP)


static func get_clipboard_cache_dir() -> String:
	return AppDataDir.get_dir_path(CLIPBOARD_SUBDIR, AppDataDir.Scope.APP)


static func get_markdown_image_cache_dir() -> String:
	return AppDataDir.get_dir_path(MARKDOWN_IMAGE_SUBDIR, AppDataDir.Scope.APP)


static func get_markdown_remote_image_cache_path(image_url: String) -> String:
	var format := ImageHelper.get_image_format(image_url)
	return get_markdown_image_cache_dir().path_join(StringUtils.format("http_{}.{}", image_url.sha256_text(), format))


static func cleanup_caches() -> void:
	FileUtils.cleanup_cache_folder(get_diff_cache_dir(), MAX_DIFF_CACHE_BYTES)
	FileUtils.cleanup_cache_folder(get_web_screenshot_cache_dir(), MAX_WEB_SCREENSHOT_CACHE_BYTES)
	FileUtils.cleanup_cache_folder(get_clipboard_cache_dir(), MAX_CLIPBOARD_CACHE_BYTES)
	FileUtils.cleanup_cache_folder(get_markdown_image_cache_dir(), MAX_MARKDOWN_IMAGE_CACHE_BYTES)
	pass
