const FOLDER_ICON := "res://agent/asset/image/ui/folder.svg"


## [method IconStyle.tinted] rasterizes the colorless Material glyph with the requested color.
func IconStyle_tinted_applies_color_test() -> void:
	var texture := IconStyle.tinted(FOLDER_ICON, Color.RED, ControlSize.icon_md)
	var image := texture.get_image()
	assert(image.get_size() == Vector2i(ControlSize.icon_md, ControlSize.icon_md))
	var strongest := strongest_pixel(image)
	assert(strongest.a > 0.5)
	assert(strongest.r > strongest.g and strongest.r > strongest.b)
	pass


## [method IconStyle.tinted] caches per glyph, size, and color, so a recolored accent re-rasterizes.
func IconStyle_tinted_cache_follows_color_test() -> void:
	var first := IconStyle.tinted(FOLDER_ICON, Color.RED, ControlSize.icon_sm)
	assert(IconStyle.tinted(FOLDER_ICON, Color.RED, ControlSize.icon_sm) == first)
	var recolored := IconStyle.tinted(FOLDER_ICON, Color.BLUE, ControlSize.icon_sm)
	assert(recolored != first)
	assert(recolored.get_image().get_size() == Vector2i(ControlSize.icon_sm, ControlSize.icon_sm))
	pass


## A zero size keeps the glyph's own pixels; a positive size normalizes onto a square canvas.
func IconStyle_tinted_size_option_test() -> void:
	var raw := IconStyle.tinted(FOLDER_ICON, Color.RED)
	assert(Vector2i(raw.get_size()) == raw.get_image().get_size())
	var squared := IconStyle.tinted(FOLDER_ICON, Color.RED, ControlSize.icon_sm)
	assert(squared.get_image().get_size() == Vector2i(ControlSize.icon_sm, ControlSize.icon_sm))
	pass


static func strongest_pixel(image: Image) -> Color:
	var strongest := Color(0, 0, 0, 0)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a > strongest.a:
				strongest = pixel
	return strongest
