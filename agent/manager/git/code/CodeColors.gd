class_name CodeColors
extends Object

## Syntax palette for repository source shown in CodeEdit. The values mirror Godot's default
## text-editor highlighting palette so embedded code follows the editor in dark and light modes.
## Roles without a direct CodeHighlighter equivalent use the closest GDScript-specific color.
## [method _static_init] connects [signal gdf.Events.theme_changed] to [method on_theme_changed].

## The dark palette also provides safe defaults before the class loads and [method on_theme_changed] runs.
const DARK_KEYWORD := Color(1.0, 0.44, 0.52)
const DARK_TYPE := Color(0.26, 1.0, 0.76)
const DARK_DECLARATION := Color(1.0, 0.55, 0.8)
const DARK_STRING := Color(1.0, 0.93, 0.63)
const DARK_COMMENT := Color(0.8, 0.8, 0.8, 0.5)
const DARK_NUMBER := Color(0.63, 1.0, 0.88)
const DARK_SYMBOL := Color(0.67, 0.79, 1.0)
const DARK_FUNCTION := Color(0.34, 0.7, 1.0)
const DARK_MEMBER := Color(0.736, 0.88, 1.0)
const DARK_TAG := Color(1.0, 0.7, 0.45)
const DARK_LINK := Color(1.0, 0.76, 0.65)
const DARK_FUNCTION_DEFINITION := Color(0.4, 0.9, 1.0)
const DARK_GLOBAL_FUNCTION := Color(0.64, 0.64, 0.96)
const DARK_ENGINE_TYPE := Color(0.56, 1.0, 0.86)
const DARK_NODE_REFERENCE := Color(0.39, 0.76, 0.35)

const LIGHT_KEYWORD := Color(0.9, 0.135, 0.51)
const LIGHT_TYPE := Color(0.0, 0.6, 0.2)
const LIGHT_DECLARATION := Color(0.743, 0.12, 0.8)
const LIGHT_STRING := Color(0.6, 0.42, 0.0)
const LIGHT_COMMENT := Color(0.08, 0.08, 0.08, 0.5)
const LIGHT_NUMBER := Color(0.0, 0.55, 0.28)
const LIGHT_SYMBOL := Color(0.0, 0.0, 0.61)
const LIGHT_FUNCTION := Color(0.0, 0.225, 0.9)
const LIGHT_MEMBER := Color(0.0, 0.4, 0.68)
const LIGHT_TAG := Color(0.8, 0.37, 0.0)
const LIGHT_LINK := Color(0.8, 0.56, 0.45)
const LIGHT_FUNCTION_DEFINITION := Color(0.0, 0.6, 0.6)
const LIGHT_GLOBAL_FUNCTION := Color(0.36, 0.18, 0.72)
const LIGHT_ENGINE_TYPE := Color(0.11, 0.55, 0.4)
const LIGHT_NODE_REFERENCE := Color(0.0, 0.5, 0.0)

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
static var link: Color = DARK_LINK
static var function_definition: Color = DARK_FUNCTION_DEFINITION
static var global_function: Color = DARK_GLOBAL_FUNCTION
static var engine_type: Color = DARK_ENGINE_TYPE
static var node_reference: Color = DARK_NODE_REFERENCE


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
	link = DARK_LINK
	function_definition = DARK_FUNCTION_DEFINITION
	global_function = DARK_GLOBAL_FUNCTION
	engine_type = DARK_ENGINE_TYPE
	node_reference = DARK_NODE_REFERENCE
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
	link = LIGHT_LINK
	function_definition = LIGHT_FUNCTION_DEFINITION
	global_function = LIGHT_GLOBAL_FUNCTION
	engine_type = LIGHT_ENGINE_TYPE
	node_reference = LIGHT_NODE_REFERENCE
	pass
