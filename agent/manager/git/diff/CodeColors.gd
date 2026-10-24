class_name CodeColors
extends Object

## Syntax palette for repository source shown in CodeEdit. Like MarkdownColors, these are two
## hand-tuned palettes rather than accent-derived colors: every token role keeps predictable
## contrast while the user changes the application accent.
## [method _static_init] connects [signal gdf.Events.theme_changed] to [method on_theme_changed].

## The dark palette also provides safe defaults before the class loads and [method on_theme_changed] runs.
const DARK_KEYWORD := Color("ff7ab2")
const DARK_TYPE := Color("82d2ce")
const DARK_DECLARATION := Color("c6a0f6")
const DARK_STRING := Color("a8cc8c")
const DARK_COMMENT := Color("7f8c98")
const DARK_NUMBER := Color("d5b778")
const DARK_SYMBOL := Color("aeb7c2")
const DARK_FUNCTION := Color("78b9f2")
const DARK_MEMBER := Color("f2c97d")
const DARK_TAG := Color("ff8f70")

const LIGHT_KEYWORD := Color("ad3da4")
const LIGHT_TYPE := Color("0b7f78")
const LIGHT_DECLARATION := Color("6f42c1")
const LIGHT_STRING := Color("467c18")
const LIGHT_COMMENT := Color("6c7781")
const LIGHT_NUMBER := Color("9a6700")
const LIGHT_SYMBOL := Color("4b5563")
const LIGHT_FUNCTION := Color("0969da")
const LIGHT_MEMBER := Color("953800")
const LIGHT_TAG := Color("cf222e")

static var keyword: Color = DARK_KEYWORD
static var type: Color = DARK_TYPE
static var declaration: Color = DARK_DECLARATION
static var string: Color = DARK_STRING
static var comment: Color = DARK_COMMENT
static var number: Color = DARK_NUMBER
static var symbol: Color = DARK_SYMBOL
static var function: Color = DARK_FUNCTION
static var member: Color = DARK_MEMBER
static var tag: Color = DARK_TAG


static func _static_init() -> void:
	gdf.events.theme_changed.connect(on_theme_changed)
	on_theme_changed()
	pass


## Select the hand-tuned set for the active dark/light appearance.
static func on_theme_changed() -> void:
	if ThemeColor.is_dark_theme():
		apply_dark_palette()
	else:
		apply_light_palette()
	pass


static func apply_dark_palette() -> void:
	keyword = DARK_KEYWORD
	type = DARK_TYPE
	declaration = DARK_DECLARATION
	string = DARK_STRING
	comment = DARK_COMMENT
	number = DARK_NUMBER
	symbol = DARK_SYMBOL
	function = DARK_FUNCTION
	member = DARK_MEMBER
	tag = DARK_TAG
	pass


static func apply_light_palette() -> void:
	keyword = LIGHT_KEYWORD
	type = LIGHT_TYPE
	declaration = LIGHT_DECLARATION
	string = LIGHT_STRING
	comment = LIGHT_COMMENT
	number = LIGHT_NUMBER
	symbol = LIGHT_SYMBOL
	function = LIGHT_FUNCTION
	member = LIGHT_MEMBER
	tag = LIGHT_TAG
	pass
