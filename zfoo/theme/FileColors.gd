class_name FileColors
extends Object

## Semantic colors for resource and file categories. The palette uses restrained jewel tones so
## resource types remain distinct without borrowing red or orange warning colors.
const DARK_AUDIO := Color(0.54, 0.42, 0.76)
const DARK_IMAGE := Color(0.25, 0.58, 0.47)
const DARK_VIDEO := Color(0.22, 0.50, 0.66)
const DARK_TEXT := Color(0.40, 0.49, 0.59)
const DARK_FOLDER := Color(0.66, 0.52, 0.25)

const LIGHT_AUDIO := Color(0.40, 0.27, 0.61)
const LIGHT_IMAGE := Color(0.15, 0.42, 0.34)
const LIGHT_VIDEO := Color(0.16, 0.37, 0.50)
const LIGHT_TEXT := Color(0.27, 0.36, 0.44)
const LIGHT_FOLDER := Color(0.49, 0.38, 0.15)

static var audio_color: Color = DARK_AUDIO
static var image_color: Color = DARK_IMAGE
static var video_color: Color = DARK_VIDEO
static var text_color: Color = DARK_TEXT
static var folder_color: Color = DARK_FOLDER


static func _static_init() -> void:
	refresh()
	pass


## Select resource colors with suitable contrast for the current dark or light theme.
static func refresh() -> void:
	var dark := ThemeColor.is_dark_theme()
	audio_color = DARK_AUDIO if dark else LIGHT_AUDIO
	image_color = DARK_IMAGE if dark else LIGHT_IMAGE
	video_color = DARK_VIDEO if dark else LIGHT_VIDEO
	text_color = DARK_TEXT if dark else LIGHT_TEXT
	folder_color = DARK_FOLDER if dark else LIGHT_FOLDER
	pass
