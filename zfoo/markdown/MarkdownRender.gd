class_name MarkdownRender
extends Object

const IMAGE_CACHE_DIR := "user://markdown"
const MAX_IMAGE_CACHE_BYTES := 512 * FileUtils.BYTES_PER_MB
const MAX_REMOTE_IMAGE_BYTES := 20 * FileUtils.BYTES_PER_MB


static func _static_init() -> void:
	WorkerThreadPool.add_task(func() -> void: FileUtils.cleanup_cache_folder(IMAGE_CACHE_DIR, MAX_IMAGE_CACHE_BYTES))
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Markdown media rendering
## Appends parsed BBCode and image tags in source order. Local images are inserted
## immediately; remote images use a keyed placeholder that is replaced after download.
static func render_markdown_with_images(label: RichTextLabel, result: MarkdownParseResult) -> void:
	label.clear()
	var cursor := 0
	for index in result.images.size():
		var image_start := result.bbcode.find("[img]", cursor)
		var image_end := result.bbcode.find("[/img]", image_start + 5)
		if image_start < 0 or image_end < 0:
			break
		label.append_text(result.bbcode.substr(cursor, image_start - cursor))
		append_markdown_image(label, result.images[index])
		cursor = image_end + 6
	label.append_text(result.bbcode.substr(cursor))
	pass


static func append_markdown_image(label: RichTextLabel, markdown_image: MarkdownParseResult.MarkdownImage) -> void:
	var image_url := markdown_image.image_url
	var is_video := VideoHelper.is_video_path(image_url)
	label.push_meta(image_url, RichTextLabel.META_UNDERLINE_NEVER)
	var placeholder := VideoHelper.create_placeholder_texture() if is_video else ImageHelper.create_placeholder_texture()
	label.add_image(placeholder, 0, 0, Color.WHITE, 5, Rect2(), image_url, false, markdown_image.alt_text)
	label.pop()
	if is_video:
		return
	if HttpUtils.is_valid_http_url(image_url):
		var cache_path := StringUtils.format("http_{}.{}", IMAGE_CACHE_DIR.path_join(image_url.sha256_text()), ImageHelper.get_image_format(image_url))
		if FileAccess.file_exists(cache_path):
			load_image_into_label(label, image_url, cache_path)
			return
		if label.has_meta(image_download_meta_key(image_url)):
			return
		set_image_downloading(label, image_url, true)
		download_remote_image(label, image_url, cache_path)
		return
	load_image_into_label(label, image_url, image_url)
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Image loading and display
static func load_image_into_label(label: RichTextLabel, image_url: String, path: String) -> void:
	var texture: Texture2D = await ResourceHelper.async_load(path)
	if texture == null or not is_instance_valid(label):
		return
	update_label_image(label, image_url, texture)
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Remote image download and cache
static func download_remote_image(label: RichTextLabel, image_url: String, cache_path: String) -> void:
	var texture := await download_remote_image_texture(image_url, cache_path)
	if not is_instance_valid(label):
		return
	set_image_downloading(label, image_url, false)
	if texture != null:
		update_label_image(label, image_url, texture)
	pass


static func update_label_image(label: RichTextLabel, image_url: String, texture: Texture2D) -> void:
	var display_size := get_image_display_size(texture)
	label.update_image(image_url, RichTextLabel.UPDATE_TEXTURE | RichTextLabel.UPDATE_SIZE, texture, display_size.x, display_size.y)
	pass


static func get_image_display_size(texture: Texture2D) -> Vector2i:
	var source_size := texture.get_size()
	if source_size.x <= ControlSize.image_lg:
		return Vector2i(source_size.round())
	var scale := ControlSize.image_lg / source_size.x
	return Vector2i(maxi(1, roundi(source_size.x * scale)), maxi(1, roundi(source_size.y * scale)))


static func download_remote_image_texture(image_url: String, cache_path: String) -> Texture2D:
	var response := await HttpHelper.async_get(image_url)
	if not response.success or response.code < 200 or response.code >= 300 or response.body.is_empty():
		Log.error("markdown image download failed url:[{}] code:[{}]", image_url, response.code)
		return null
	if response.body.size() > MAX_REMOTE_IMAGE_BYTES:
		Log.error("markdown image is too large url:[{}] bytes:[{}]", image_url, response.body.size())
		return null
	var image := ImageHelper.decode_image(response.body)
	if image == null:
		Log.error("markdown image decode failed url:[{}]", image_url)
		return null
	var cache_error := save_cached_image(image, cache_path)
	if cache_error != OK:
		Log.error("markdown image cache failed path:[{}] err:[{}]", cache_path, cache_error)
		return null
	var texture: Texture2D = await ResourceHelper.async_load(cache_path)
	return texture


static func save_cached_image(image: Image, cache_path: String) -> int:
	var absolute_dir := ProjectSettings.globalize_path(IMAGE_CACHE_DIR)
	var error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	return image.save_png(ProjectSettings.globalize_path(cache_path))


static func set_image_downloading(label: RichTextLabel, image_url: String, downloading: bool) -> void:
	var meta_key := image_download_meta_key(image_url)
	if downloading:
		label.set_meta(meta_key, true)
		return
	label.remove_meta(meta_key)
	pass


static func image_download_meta_key(image_url: String) -> StringName:
	return StringName("image_" + image_url.sha256_text())

