func external_image_test() -> void:
	var path: String = ProjectSettings.globalize_path("res://icon.svg")
	var texture := ResourceHelper.load_external_file(path) as ImageTexture
	assert(texture != null)
	assert(texture.get_width() > 0)
	assert(texture.get_height() > 0)
	pass


func create_placeholder_texture_test() -> void:
	var texture := ImageHelper.create_placeholder_texture()
	assert(texture != null)
	assert(texture.get_size() == Vector2(160, 90))
	pass


func image_buffer_decode_test() -> void:
	var source := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	source.fill(Color.RED)
	var decoded := ImageHelper.decode_image(source.save_jpg_to_buffer())
	assert(decoded != null)
	assert(decoded.image.get_size() == Vector2i(2, 2))
	pass


func resize_image_to_max_size_test() -> void:
	var image := Image.create(2400, 1200, false, Image.FORMAT_RGBA8)
	assert(ImageHelper.resize_image_to_max_size(image, Vector2i(1300, 1300)))
	assert(image.get_size() == Vector2i(1300, 650))
	assert(not ImageHelper.resize_image_to_max_size(image, Vector2i(1300, 1300)))
	pass


func convert_to_jpg_with_max_size_test() -> void:
	var source := Image.create(2400, 1200, false, Image.FORMAT_RGBA8)
	source.fill(Color.RED)
	var original := source.save_jpg_to_buffer()
	var converted := ImageHelper.convert_to_jpg_with_max_size(original, Vector2i(1300, 1300))
	var decoded := ImageHelper.decode_image(converted)
	assert(decoded != null)
	assert(decoded.format == ImageHelper.jpg)
	assert(decoded.image.get_size() == Vector2i(1300, 650))
	assert(ImageHelper.convert_to_jpg_with_max_size(original, Vector2i(2400, 1200)) == original)
	pass


func convert_to_png_with_max_size_test() -> void:
	var source := Image.create(2400, 1200, false, Image.FORMAT_RGBA8)
	source.fill(Color.RED)
	var original := source.save_png_to_buffer()
	var converted := ImageHelper.convert_to_png_with_max_size(original, Vector2i(1300, 1300))
	var decoded := ImageHelper.decode_image(converted)
	assert(decoded != null)
	assert(decoded.format == ImageHelper.png)
	assert(decoded.image.get_size() == Vector2i(1300, 650))
	assert(ImageHelper.convert_to_png_with_max_size(original, Vector2i(2400, 1200)) == original)
	assert(ImageHelper.decode_image(ImageHelper.convert_to_png_with_max_size(source.save_jpg_to_buffer(), Vector2i(2400, 1200))).format == ImageHelper.png)
	pass


func convert_svg_to_png_preserves_transparency_test() -> void:
	var svg_bytes := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"2\" height=\"2\"><rect width=\"1\" height=\"1\" fill=\"red\"/></svg>".to_utf8_buffer()
	var converted := ImageHelper.convert_to_png_with_max_size(svg_bytes, Vector2i(2, 2))
	var decoded := ImageHelper.decode_image(converted)
	assert(decoded != null)
	assert(decoded.format == ImageHelper.png)
	assert(decoded.image.get_pixel(1, 1).a == 0.0)
	pass


func convert_to_webp_with_max_size_test() -> void:
	var source := Image.create(2400, 1200, false, Image.FORMAT_RGBA8)
	source.fill(Color.RED)
	var original := source.save_webp_to_buffer()
	var converted := ImageHelper.convert_to_webp_with_max_size(original, Vector2i(1300, 1300))
	var decoded := ImageHelper.decode_image(converted)
	assert(decoded != null)
	assert(decoded.format == ImageHelper.webp)
	assert(decoded.image.get_size() == Vector2i(1300, 650))
	assert(ImageHelper.convert_to_webp_with_max_size(original, Vector2i(2400, 1200)) == original)
	pass


func get_image_format_test() -> void:
	assert(ImageHelper.get_image_format("res://image/photo.PNG") == ImageHelper.png)
	assert(ImageHelper.get_image_format("https://example.com/photo.webp") == ImageHelper.webp)
	assert(ImageHelper.get_image_format("https://example.com/photo.jpg?width=320#preview") == ImageHelper.jpg)
	assert(ImageHelper.get_image_format("https://example.com/photo") == ImageHelper.png)
	assert(ImageHelper.get_image_format("res://document.txt") == ImageHelper.png)
	assert(ImageHelper.get_image_format("res://document.txt", ImageHelper.webp) == ImageHelper.webp)
	pass


func save_image_test() -> void:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var base_path := "user://image_helper_save_image_test"
	for extension in [ImageHelper.jpg, ImageHelper.png, ImageHelper.webp]:
		var path: String = base_path + "." + extension
		var source_bytes := image.save_jpg_to_buffer() if extension == ImageHelper.jpg else image.save_png_to_buffer() if extension == ImageHelper.png else image.save_webp_to_buffer()
		assert(ImageHelper.save_image(source_bytes, ProjectSettings.globalize_path(path)) == OK)
		assert(ImageHelper.decode_image(FileAccess.get_file_as_bytes(path)).format == extension)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert(ImageHelper.save_image(image.save_png_to_buffer(), ProjectSettings.globalize_path(base_path + ".svg")) == ERR_FILE_UNRECOGNIZED)
	assert(ImageHelper.save_image(image.save_png_to_buffer(), ProjectSettings.globalize_path(base_path + "_no_extension")) == ERR_FILE_UNRECOGNIZED)
	pass


func decode_image_format_test() -> void:
	var source := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	assert(ImageHelper.decode_image(source.save_jpg_to_buffer()).format == ImageHelper.jpg)
	assert(ImageHelper.decode_image(source.save_png_to_buffer()).format == ImageHelper.png)
	assert(ImageHelper.decode_image(source.save_webp_to_buffer()).format == ImageHelper.webp)
	assert(ImageHelper.decode_image("<?xml version=\"1.0\"?><svg xmlns=\"http://www.w3.org/2000/svg\"/>".to_utf8_buffer()).format == ImageHelper.svg)
	assert(ImageHelper.decode_image(PackedByteArray([0x01, 0x02, 0x03])) == null)
	pass


func detect_image_format_test() -> void:
	var source := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	assert(ImageHelper.detect_image_format(source.save_jpg_to_buffer()) == ImageHelper.jpg)
	assert(ImageHelper.detect_image_format(source.save_png_to_buffer()) == ImageHelper.png)
	assert(ImageHelper.detect_image_format(source.save_webp_to_buffer()) == ImageHelper.webp)
	assert(ImageHelper.detect_image_format("<?xml version=\"1.0\"?><svg xmlns=\"http://www.w3.org/2000/svg\"/>".to_utf8_buffer()) == ImageHelper.svg)
	assert(ImageHelper.detect_image_format(PackedByteArray([0x01, 0x02, 0x03])) == "")
	pass
