class_name VideoHelper
extends Object

const avi := "avi"
const m4v := "m4v"
const mkv := "mkv"
const mov := "mov"
const mp4 := "mp4"
const mpeg := "mpeg"
const mpg := "mpg"
const ogv := "ogv"
const webm := "webm"
const EXTENSIONS: PackedStringArray = [avi, m4v, mkv, mov, mp4, mpeg, mpg, ogv, webm]


static func is_video_path(path: String) -> bool:
	var clean_path := path.get_slice("?", 0).get_slice("#", 0)
	return EXTENSIONS.has(clean_path.get_extension().to_lower())


## Creates a theme-aware video card with a centered play symbol.
static func create_placeholder_texture(width: int = 160, height: int = 90) -> ImageTexture:
	var background := Colors.control_surface.to_html(false)
	var border := Colors.subtle_border.to_html(false)
	var icon := Colors.secondary_text.to_html(false)
	var svg_template := """
	<svg xmlns="http://www.w3.org/2000/svg" width="{}" height="{}" viewBox="0 0 160 90">
	<rect x="0.5" y="0.5" width="159" height="89" rx="8" fill="#{}" stroke="#{}"/>
	<circle cx="80" cy="45" r="22" fill="none" stroke="#{}" stroke-width="3"/>
	<path d="M74 33l18 12-18 12z" fill="#{}"/>
	</svg>"""
	var svg := StringUtils.format(svg_template, width, height, background, border, icon, icon)
	var image := Image.new()
	if image.load_svg_from_buffer(svg.to_utf8_buffer()) != OK:
		image = Image.create(width, height, false, Image.FORMAT_RGBA8)
		image.fill(Colors.control_surface)
	return ImageTexture.create_from_image(image)
