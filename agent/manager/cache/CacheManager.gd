class_name CacheManager
extends Object

const DIFF_CACHE_SUBDIR := ".gai/cache/diff"
const MAX_DIFF_CACHE_BYTES := 128 * FileUtils.BYTES_PER_MB
const WEB_SCREENSHOT_SUBDIR := ".gai/cache/screenshot"
const MAX_WEB_SCREENSHOT_CACHE_BYTES := 512 * FileUtils.BYTES_PER_MB
const CLIPBOARD_SUBDIR := ".gai/cache/clipboard"
const MAX_CLIPBOARD_CACHE_BYTES := 512 * FileUtils.BYTES_PER_MB
const MARKDOWN_IMAGE_SUBDIR := ".gai/cache/markdown"
const MAX_MARKDOWN_IMAGE_CACHE_BYTES := 512 * FileUtils.BYTES_PER_MB


static func _static_init() -> void:
	WorkerThreadPool.add_task(func() -> void: cleanup_caches())
	pass


static func get_diff_cache_dir() -> String:
	return AgentWorkspace.get_root().path_join(DIFF_CACHE_SUBDIR)


static func get_web_screenshot_cache_dir() -> String:
	return AgentWorkspace.get_root().path_join(WEB_SCREENSHOT_SUBDIR)


static func get_clipboard_cache_dir() -> String:
	return AgentWorkspace.get_root().path_join(CLIPBOARD_SUBDIR)


static func get_markdown_image_cache_dir() -> String:
	return AgentWorkspace.get_root().path_join(MARKDOWN_IMAGE_SUBDIR)


static func get_markdown_remote_image_cache_path(image_url: String) -> String:
	var format := ImageHelper.get_image_format(image_url)
	return get_markdown_image_cache_dir().path_join(StringUtils.format("http_{}.{}", image_url.sha256_text(), format))


static func cleanup_caches() -> void:
	FileUtils.cleanup_cache_folder(get_diff_cache_dir(), MAX_DIFF_CACHE_BYTES)
	FileUtils.cleanup_cache_folder(get_web_screenshot_cache_dir(), MAX_WEB_SCREENSHOT_CACHE_BYTES)
	FileUtils.cleanup_cache_folder(get_clipboard_cache_dir(), MAX_CLIPBOARD_CACHE_BYTES)
	FileUtils.cleanup_cache_folder(get_markdown_image_cache_dir(), MAX_MARKDOWN_IMAGE_CACHE_BYTES)
	pass
