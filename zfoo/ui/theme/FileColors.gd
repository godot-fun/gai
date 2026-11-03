class_name FileColors
extends Object

## Semantic colors for resource and file categories. The palette uses restrained jewel tones so
## resource types remain distinct without borrowing red or orange warning colors.
const DARK_AUDIO := Color(0.54, 0.42, 0.76)
const DARK_IMAGE := Color(0.25, 0.58, 0.47)
const DARK_VIDEO := Color(0.22, 0.50, 0.66)
const DARK_CONFIG := Color(0.22, 0.50, 0.66)
const DARK_GENERIC := Color(0.40, 0.49, 0.59)
const DARK_TEXT := Color(0.40, 0.49, 0.59)
const DARK_FOLDER := Color(0.66, 0.52, 0.25)

const LIGHT_AUDIO := Color(0.40, 0.27, 0.61)
const LIGHT_IMAGE := Color(0.15, 0.42, 0.34)
const LIGHT_VIDEO := Color(0.16, 0.37, 0.50)
const LIGHT_CONFIG := Color(0.16, 0.37, 0.50)
const LIGHT_GENERIC := Color(0.27, 0.36, 0.44)
const LIGHT_TEXT := Color(0.27, 0.36, 0.44)
const LIGHT_FOLDER := Color(0.49, 0.38, 0.15)

## Classifies local link destinations for `[label](path)` in the chat composer and in rendered markdown.
## Audio / image / video extensions come from [ResourceHelper], [ImageHelper], and [VideoHelper]; [member CONFIG_EXTENSIONS]
## and [member TEXT_DOCUMENT_EXTENSIONS] cover the rest. Installers, binaries, and shell scripts are not config — they
## fall through to [constant Category.GENERIC]. [method category_for_path] and [method color_for_path] are shared by
## [MarkdownHighlighter] (CodeEdit) and [MarkdownParser] (BBCode prefix).
const CONFIG_EXTENSIONS: PackedStringArray = [
	"cfg", "cnf", "conf", "config", "env", "gdextension", "godot", "import", "ini", "json", "json5", "jsonc",
	"lock", "plist", "properties", "toml", "tres", "tscn", "xml", "yaml", "yml",
]
const TEXT_DOCUMENT_EXTENSIONS: PackedStringArray = [
	"adoc", "asciidoc", "bash", "c", "cpp", "cs", "css", "csv", "dart", "doc", "docx", "epub", "gd", "go", "h",
	"hpp", "html", "htm", "java", "js", "jsx", "kt", "log", "lua", "markdown", "md", "mdown", "mdx", "mobi", "odt",
	"org", "pdf", "php", "ps1", "py", "rb", "rs", "rst", "rtf", "sass", "scss", "sh", "sql", "swift", "tex", "ts",
	"tsx", "tsv", "txt", "vue", "zsh",
]

## One [Category] per [code]*_color[/code] static below ([MarkdownParser.get_link_prefix] picks emoji per case).
enum Category { GENERIC, FOLDER, AUDIO, IMAGE, VIDEO, CONFIG, TEXT }

static var generic_color: Color = DARK_GENERIC
static var folder_color: Color = DARK_FOLDER
static var audio_color: Color = DARK_AUDIO
static var image_color: Color = DARK_IMAGE
static var video_color: Color = DARK_VIDEO
static var config_color: Color = DARK_CONFIG
static var text_color: Color = DARK_TEXT


static func _static_init() -> void:
	refresh()
	pass


## Select resource colors with suitable contrast for the current dark or light theme.
static func refresh() -> void:
	var dark := ThemeColor.is_dark_theme()
	generic_color = DARK_GENERIC if dark else LIGHT_GENERIC
	folder_color = DARK_FOLDER if dark else LIGHT_FOLDER
	audio_color = DARK_AUDIO if dark else LIGHT_AUDIO
	image_color = DARK_IMAGE if dark else LIGHT_IMAGE
	video_color = DARK_VIDEO if dark else LIGHT_VIDEO
	config_color = DARK_CONFIG if dark else LIGHT_CONFIG
	text_color = DARK_TEXT if dark else LIGHT_TEXT
	pass


static func category_for_path(path: String) -> Category:
	var clean_path := path.get_slice("?", 0).get_slice("#", 0).strip_edges()
	if clean_path.is_empty():
		return Category.GENERIC
	if clean_path.ends_with("/") or clean_path.ends_with("\\"):
		return Category.FOLDER
	if DirAccess.dir_exists_absolute(clean_path):
		return Category.FOLDER
	var extension := clean_path.get_extension().to_lower()
	if ResourceHelper.AUDIO_EXTENSIONS.has(extension):
		return Category.AUDIO
	if ImageHelper.EXTENSIONS.has(extension):
		return Category.IMAGE
	if VideoHelper.EXTENSIONS.has(extension):
		return Category.VIDEO
	if CONFIG_EXTENSIONS.has(extension):
		return Category.CONFIG
	if TEXT_DOCUMENT_EXTENSIONS.has(extension):
		return Category.TEXT
	if Fonts.EXTENSIONS.has(extension):
		return Category.TEXT
	return Category.GENERIC
	pass


static func color_for_category(category: Category) -> Color:
	match category:
		Category.GENERIC:
			return generic_color
		Category.FOLDER:
			return folder_color
		Category.AUDIO:
			return audio_color
		Category.IMAGE:
			return image_color
		Category.VIDEO:
			return video_color
		Category.CONFIG:
			return config_color
		Category.TEXT:
			return text_color
	return text_color
	pass


static func color_for_path(path: String) -> Color:
	return color_for_category(category_for_path(path))
	pass
