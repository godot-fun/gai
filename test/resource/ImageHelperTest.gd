func external_image_test() -> void:
	var path := ProjectSettings.globalize_path("res://icon.svg")
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
	assert(decoded.get_size() == Vector2i(2, 2))
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
	assert(ImageHelper.detect_image_format(converted) == ImageHelper.jpg)
	assert(decoded != null)
	assert(decoded.get_size() == Vector2i(1300, 650))
	assert(ImageHelper.convert_to_jpg_with_max_size(original, Vector2i(2400, 1200)) == original)
	pass


func convert_to_png_with_max_size_test() -> void:
	var source := Image.create(2400, 1200, false, Image.FORMAT_RGBA8)
	source.fill(Color.RED)
	var original := source.save_png_to_buffer()
	var converted := ImageHelper.convert_to_png_with_max_size(original, Vector2i(1300, 1300))
	var decoded := ImageHelper.decode_image(converted)
	assert(ImageHelper.detect_image_format(converted) == ImageHelper.png)
	assert(decoded != null)
	assert(decoded.get_size() == Vector2i(1300, 650))
	assert(ImageHelper.convert_to_png_with_max_size(original, Vector2i(2400, 1200)) == original)
	assert(ImageHelper.detect_image_format(ImageHelper.convert_to_png_with_max_size(source.save_jpg_to_buffer(), Vector2i(2400, 1200))) == ImageHelper.png)
	pass


func convert_svg_to_png_preserves_transparency_test() -> void:
	var svg_bytes := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"2\" height=\"2\"><rect width=\"1\" height=\"1\" fill=\"red\"/></svg>".to_utf8_buffer()
	var converted := ImageHelper.convert_to_png_with_max_size(svg_bytes, Vector2i(2, 2))
	var decoded := ImageHelper.decode_image(converted)
	assert(ImageHelper.detect_image_format(converted) == ImageHelper.png)
	assert(decoded != null)
	assert(decoded.get_pixel(1, 1).a == 0.0)
	pass


func convert_to_webp_with_max_size_test() -> void:
	var source := Image.create(2400, 1200, false, Image.FORMAT_RGBA8)
	source.fill(Color.RED)
	var original := source.save_webp_to_buffer()
	var converted := ImageHelper.convert_to_webp_with_max_size(original, Vector2i(1300, 1300))
	var decoded := ImageHelper.decode_image(converted)
	assert(ImageHelper.detect_image_format(converted) == ImageHelper.webp)
	assert(decoded != null)
	assert(decoded.get_size() == Vector2i(1300, 650))
	assert(ImageHelper.convert_to_webp_with_max_size(original, Vector2i(2400, 1200)) == original)
	pass


func get_image_format_test() -> void:
	assert(ImageHelper.get_image_format("res://image/photo.PNG") == ImageHelper.png)
	assert(ImageHelper.get_image_format("https://example.com/photo.webp") == ImageHelper.webp)
	assert(ImageHelper.get_image_format("https://example.com/photo") == ImageHelper.png)
	assert(ImageHelper.get_image_format("res://document.txt") == ImageHelper.png)
	assert(ImageHelper.get_image_format("res://document.txt", ImageHelper.webp) == ImageHelper.webp)
	pass


func detect_image_format_test() -> void:
	var source := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	assert(ImageHelper.detect_image_format(source.save_jpg_to_buffer()) == ImageHelper.jpg)
	assert(ImageHelper.detect_image_format(source.save_png_to_buffer()) == ImageHelper.png)
	assert(ImageHelper.detect_image_format(source.save_webp_to_buffer()) == ImageHelper.webp)
	assert(ImageHelper.detect_image_format("<?xml version=\"1.0\"?><svg xmlns=\"http://www.w3.org/2000/svg\"/>".to_utf8_buffer()) == ImageHelper.svg)
	assert(ImageHelper.detect_image_format(PackedByteArray([0x01, 0x02, 0x03])) == "")
	pass
