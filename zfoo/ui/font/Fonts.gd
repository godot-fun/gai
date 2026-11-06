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

static var light_font: Font
static var regular_font: Font
static var medium_font: Font
static var semibold_font: Font
static var bold_font: Font
static var code_font: FontVariation


## Applies the bundled regular font to controls and standalone windows without a local Theme.
static func _static_init() -> void:
	ThemeDB.fallback_font = regular()
	pass


static func light() -> Font:
	if light_font == null:
		light_font = create_font(LIGHT_PATH, 300)
	return light_font


static func regular() -> Font:
	if regular_font == null:
		regular_font = create_font(REGULAR_PATH, 400)
	return regular_font


static func medium() -> Font:
	if medium_font == null:
		medium_font = create_font(MEDIUM_PATH, 500)
	return medium_font


static func semibold() -> Font:
	if semibold_font == null:
		semibold_font = create_font(SEMIBOLD_PATH, 600)
	return semibold_font


static func bold() -> Font:
	if bold_font == null:
		bold_font = create_font(BOLD_PATH, 700)
	return bold_font


static func create_font(path: String, weight: int) -> Font:
	var bundled := load(path) as FontFile
	if not OSUtils.is_windows():
		return bundled
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	system_font.font_weight = weight
	system_font.hinting = TextServer.HINTING_LIGHT
	system_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	system_font.fallbacks = [bundled]
	return system_font


## The same bundled JetBrains Mono Regular source font used by Godot's script editor.
static func code() -> Font:
	if code_font == null:
		var base := load(CODE_PATH) as FontFile
		base.force_autohinter = true
		base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		base.keep_rounding_remainders = true
		base.fallbacks = [regular()]
		code_font = FontVariation.new()
		code_font.base_font = base
		code_font.set_spacing(TextServer.SPACING_TOP, -1)
		code_font.set_spacing(TextServer.SPACING_BOTTOM, -1)
		var text_server := TextServerManager.get_primary_interface()
		code_font.opentype_features = {text_server.name_to_tag("calt"): 0}
	return code_font
