class_name ImageHelper
extends Object

const bmp := "bmp"
const dds := "dds"
const exr := "exr"
const jpg := "jpg"
const jpeg := "jpeg"
const ktx := "ktx"
const png := "png"
const svg := "svg"
const tga := "tga"
const webp := "webp"
const EXTENSIONS: PackedStringArray = [bmp, dds, exr, jpg, jpeg, ktx, png, svg, tga, webp]


static func load_external_image(path: String) -> ImageTexture:
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null


static func get_image_format(path: String, default_format: String = png) -> String:
	var path_without_query := path.get_slice("?", 0).get_slice("#", 0)
	var extension := StringUtils.substring_after_last(path_without_query.to_lower(), ".")
	return extension if EXTENSIONS.has(extension) else default_format


## Saves [param bytes] using the encoder selected by [param path]'s extension.
## When [param path] has no extension, recognized source bytes are written unchanged.
static func save_image(bytes: PackedByteArray, path: String) -> Error:
	if bytes.is_empty():
		return ERR_INVALID_DATA
	var path_format := get_image_format(path, "")
	var image := decode_image(bytes)
	if image == null:
		return ERR_FILE_UNRECOGNIZED
	match path_format:
		jpg, jpeg:
			return image.save_jpg(path)
		png:
			return image.save_png(path)
		webp:
			return image.save_webp(path)
		_:
			var source_format := detect_image_format(bytes)
			if source_format.is_empty():
				return ERR_FILE_UNRECOGNIZED
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				return FileAccess.get_open_error()
			file.store_buffer(bytes)
			return OK


static func detect_image_format(bytes: PackedByteArray) -> String:
	if bytes.size() >= 3 and bytes[0] == 0xff and bytes[1] == 0xd8 and bytes[2] == 0xff:
		return jpg
	if bytes.size() >= 8 and bytes.slice(0, 8) == PackedByteArray([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]):
		return png
	if bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		return webp
	var header := bytes.slice(0, mini(bytes.size(), 4096)).get_string_from_utf8().strip_edges()
	if header.trim_prefix("\ufeff").find("<svg") >= 0:
		return svg
	return ""


static func decode_image(bytes: PackedByteArray) -> Image:
	var image := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	match detect_image_format(bytes):
		jpg: error = image.load_jpg_from_buffer(bytes)
		png: error = image.load_png_from_buffer(bytes)
		webp: error = image.load_webp_from_buffer(bytes)
		svg: error = image.load_svg_from_buffer(bytes)
	if error == OK:
		return image

	if image.load_jpg_from_buffer(bytes) == OK:
		return image
	image = Image.new()
	if image.load_png_from_buffer(bytes) == OK:
		return image
	image = Image.new()
	if image.load_webp_from_buffer(bytes) == OK:
		return image
	image = Image.new()
	if image.load_svg_from_buffer(bytes) == OK:
		return image
	image = Image.new()
	if image.load_bmp_from_buffer(bytes) == OK:
		return image
	image = Image.new()
	if image.load_tga_from_buffer(bytes) == OK:
		return image
	image = Image.new()
	if image.load_dds_from_buffer(bytes) == OK:
		return image
	image = Image.new()
	if image.load_exr_from_buffer(bytes) == OK:
		return image
	image = Image.new()
	if image.load_ktx_from_buffer(bytes) == OK:
		return image
	return null

# ----------------------------------------------------------------------------------------------------------------------
## Fits an existing JPEG inside [param max_size] without upscaling; other formats are converted to JPEG.
## JPEGs already inside the bounds return their original bytes unchanged.
## Returns an empty byte array when decoding fails or [param max_size] is invalid.
static func convert_to_jpg_with_max_size(image_bytes: PackedByteArray, max_size: Vector2i, quality: float = 0.90) -> PackedByteArray:
	if max_size.x <= 0 or max_size.y <= 0:
		return PackedByteArray()
	var image := decode_image(image_bytes)
	if image == null or image.is_empty():
		return PackedByteArray()
	if not resize_image_to_max_size(image, max_size) and detect_image_format(image_bytes) == jpg:
		return image_bytes
	return image.save_jpg_to_buffer(clampf(quality, 0.0, 1.0))


## Fits an existing PNG inside [param max_size] without upscaling; other formats are converted to PNG.
## PNGs already inside the bounds return their original bytes unchanged.
static func convert_to_png_with_max_size(image_bytes: PackedByteArray, max_size: Vector2i) -> PackedByteArray:
	if max_size.x <= 0 or max_size.y <= 0:
		return PackedByteArray()
	var image := decode_image(image_bytes)
	if image == null or image.is_empty():
		return PackedByteArray()
	if not resize_image_to_max_size(image, max_size) and detect_image_format(image_bytes) == png:
		return image_bytes
	return image.save_png_to_buffer()


## Fits an existing WebP inside [param max_size] without upscaling; other formats are converted to WebP.
## WebPs already inside the bounds return their original bytes unchanged.
## Returns an empty byte array when decoding fails or [param max_size] is invalid.
static func convert_to_webp_with_max_size(image_bytes: PackedByteArray, max_size: Vector2i, quality: float = 0.90) -> PackedByteArray:
	if max_size.x <= 0 or max_size.y <= 0:
		return PackedByteArray()
	var image := decode_image(image_bytes)
	if image == null or image.is_empty():
		return PackedByteArray()
	if not resize_image_to_max_size(image, max_size) and detect_image_format(image_bytes) == webp:
		return image_bytes
	return image.save_webp_to_buffer(clampf(quality, 0.0, 1.0))


## Resizes [param image] proportionally only when it exceeds [param max_size].
## Returns true when the image dimensions changed.
static func resize_image_to_max_size(image: Image, max_size: Vector2i) -> bool:
	if image == null or image.is_empty() or max_size.x <= 0 or max_size.y <= 0:
		return false
	var scale := minf(1.0, minf(float(max_size.x) / image.get_width(), float(max_size.y) / image.get_height()))
	if scale >= 1.0:
		return false
	image.resize(maxi(1, roundi(image.get_width() * scale)), maxi(1, roundi(image.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	return true


# ----------------------------------------------------------------------------------------------------------------------
## Creates a theme-aware image card shown while remote content is loading.
static func create_placeholder_texture(width: int = 160, height: int = 90) -> ImageTexture:
	var background := Colors.control_surface.to_html(false)
	var border := Colors.subtle_border.to_html(false)
	var icon := Colors.secondary_text.to_html(false)
	var svg_template := """
	<svg xmlns="http://www.w3.org/2000/svg" width="{}" height="{}" viewBox="0 0 160 90">
	<rect x="0.5" y="0.5" width="159" height="89" rx="8" fill="#{}" stroke="#{}"/>
	<g fill="none" stroke="#{}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
		<rect x="61" y="29" width="38" height="32" rx="4"/>
		<circle cx="88" cy="39" r="3" fill="#{}" stroke="none"/>
		<path d="M65 56l10-10 7 7 5-5 8 8"/>
	</g>
	</svg>"""
	var svg := StringUtils.format(svg_template, width, height, background, border, icon, icon)
	var image := Image.new()
	if image.load_svg_from_buffer(svg.to_utf8_buffer()) != OK:
		image = Image.create(width, height, false, Image.FORMAT_RGBA8)
		image.fill(Colors.control_surface)
	return ImageTexture.create_from_image(image)
