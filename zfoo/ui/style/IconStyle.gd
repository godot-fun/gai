class_name IconStyle
extends Object

## Rasterizes monochrome Material glyphs with a theme color.
##
## The SVGs under [code]res://agent/asset/image/ui[/code] carry no fill of their own, so callers pick
## a color at load time. Textures are cached per glyph, size, and color, which means a new theme
## color misses the cache and every caller picks up the new tint on its next refresh — no explicit
## invalidation pass. This is shared by toolbar app icons and the editor file tree folders so both
## follow the accent color the same way.

static var cache: Dictionary = {}


## Returns [param path] tinted with [param color]. A positive [param size] centers the glyph on a
## transparent square canvas of that edge, keeping icon buttons on a stable baseline.
static func tinted(path: String, color: Color, size: int = 0) -> Texture2D:
	var key := "%s#%d#%s" % [path, size, color.to_html(false)]
	if cache.has(key):
		return cache[key]
	var texture := ImageHelper.tint_svg(path, color)
	var result: Texture2D = square(texture, size) if size > 0 else texture
	cache[key] = result
	return result


## Scales [param texture] to fit and centers it on a transparent square canvas.
static func square(texture: Texture2D, size: int) -> ImageTexture:
	if texture == null:
		return ImageTexture.new()
	var source := texture.get_image()
	if source == null or source.is_empty():
		return ImageTexture.new()
	var source_size := source.get_size()
	var scale := minf(float(size) / source_size.x, float(size) / source_size.y)
	var scaled_size := Vector2i(maxi(1, roundi(source_size.x * scale)), maxi(1, roundi(source_size.y * scale)))
	source.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var offset := Vector2i((size - scaled_size.x) / 2, (size - scaled_size.y) / 2)
	canvas.blit_rect(source, Rect2i(Vector2i.ZERO, scaled_size), offset)
	return ImageTexture.create_from_image(canvas)
