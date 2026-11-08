class_name AgentLayout
extends Object

## Shared structural dimensions for the Code Agent interface.

## Top toolbar row height, applied by Agent.apply_layout().
const TOOLBAR_HEIGHT := 48
const SIDEBAR_DEFAULT_WIDTH := 320
const SIDEBAR_MIN_WIDTH := 260
const FILE_DIALOG_SIZE := Vector2i(900, 600)
const WINDOW_MIN_SIZE := Vector2i(720, 480)

static var toolbar_height: int = TOOLBAR_HEIGHT
static var sidebar_default_width: int = SIDEBAR_DEFAULT_WIDTH
static var sidebar_min_width: int = SIDEBAR_MIN_WIDTH
static var chat_content_left: int = sidebar_default_width + Margin.ma_5
static var file_dialog_size: Vector2i = FILE_DIALOG_SIZE
static var window_min_size: Vector2i = WINDOW_MIN_SIZE


static func refresh() -> void:
	var scale := DisplayScale.get_ui_scale()
	toolbar_height = DisplayScale.scale_int(TOOLBAR_HEIGHT, scale)
	sidebar_default_width = DisplayScale.scale_int(SIDEBAR_DEFAULT_WIDTH, scale)
	sidebar_min_width = DisplayScale.scale_int(SIDEBAR_MIN_WIDTH, scale)
	chat_content_left = sidebar_default_width + Margin.ma_5
	file_dialog_size = Vector2i(Vector2(FILE_DIALOG_SIZE) * scale)
	window_min_size = Vector2i(Vector2(WINDOW_MIN_SIZE) * scale)
	pass
