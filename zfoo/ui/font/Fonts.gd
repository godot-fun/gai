class_name Fonts
extends Object

const EXTENSIONS: PackedStringArray = ["ttf", "otf", "woff", "woff2"]

## Noto Sans SC (SIL Open Font License 1.1).

const LIGHT_PATH := "res://zfoo/ui/font/NotoSansSC-Light.woff2"
const REGULAR_PATH := "res://zfoo/ui/font/NotoSansSC-Regular.woff2"
const MEDIUM_PATH := "res://zfoo/ui/font/NotoSansSC-Medium.woff2"
const SEMIBOLD_PATH := "res://zfoo/ui/font/NotoSansSC-SemiBold.woff2"
const BOLD_PATH := "res://zfoo/ui/font/NotoSansSC-Bold.woff2"
const CODE_PATH := "res://zfoo/ui/font/JetBrainsMono_Regular.woff2"

static var light_font: FontFile
static var regular_font: FontFile
static var medium_font: FontFile
static var semibold_font: FontFile
static var bold_font: FontFile
static var code_font: FontVariation


## Applies the bundled regular font to controls and standalone windows without a local Theme.
static func _static_init() -> void:
	ThemeDB.fallback_font = regular()
	pass


static func light() -> Font:
	if light_font == null:
		light_font = load(LIGHT_PATH) as FontFile
	return light_font


static func regular() -> Font:
	if regular_font == null:
		regular_font = load(REGULAR_PATH) as FontFile
	return regular_font


static func medium() -> Font:
	if medium_font == null:
		medium_font = load(MEDIUM_PATH) as FontFile
	return medium_font


static func semibold() -> Font:
	if semibold_font == null:
		semibold_font = load(SEMIBOLD_PATH) as FontFile
	return semibold_font


static func bold() -> Font:
	if bold_font == null:
		bold_font = load(BOLD_PATH) as FontFile
	return bold_font


## The same bundled JetBrains Mono Regular source font used by Godot's script editor.
static func code() -> Font:
	if code_font == null:
		code_font = FontVariation.new()
		code_font.base_font = load(CODE_PATH) as FontFile
		var text_server := TextServerManager.get_primary_interface()
		code_font.opentype_features = {text_server.name_to_tag("calt"): 0}
	return code_font
