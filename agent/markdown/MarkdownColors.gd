class_name MarkdownColors
extends Object

## Markdown palette for `MarkdownParser`: code blocks, inline code chips, tables, quotes, links.
## Two hand-written sets — one per theme — instead of colors derived from `ThemeColor.theme_color`:
## every value is a literal you can read, tune and review in a screenshot, and a link always lands
## on a contrast that was picked by hand instead of on whatever the current accent implies.
## Usage: `MarkdownColors.code_block_bg` / `table_grid_color` / … ; `MarkdownParser` turns each
## one into a BBCode argument at conversion time.
## [method _static_init] connects [signal gdf.Events.theme_changed] to [method on_theme_changed].

## Runtime colors are initialized for the active appearance by [method _static_init].
static var code_block_bg: Color
static var table_grid_color: Color
static var table_header_bg: Color
static var inline_code_bg: Color
static var link_color: Color
static var blockquote_bar_color: Color


static func _static_init() -> void:
	gdf.events.theme_changed.connect(on_theme_changed)
	on_theme_changed()
	pass


## Select the hand-tuned set for the active dark/light appearance; no accent maths.
static func on_theme_changed() -> void:
	if ThemeColor.is_dark_theme():
		apply_dark_palette()
	else:
		apply_light_palette()
	pass


# ---------------------------------------------------------------------------
# Dark palette
# ---------------------------------------------------------------------------

## Code blocks use a dedicated cool blue-gray layer between the page and brighter inline/table
## fills. Table marks carry the accent brightness; quote body reads dimmer than primary text.
static func apply_dark_palette() -> void:
	code_block_bg = Color(0.13, 0.14, 0.16)
	table_grid_color = Color(0.35, 0.36, 0.41)
	table_header_bg = Color(1.0, 1.0, 1.0, 0.08)
	inline_code_bg = Color(0.45, 0.47, 0.52, 0.18)
	link_color = Color(0.35, 0.65, 0.95)
	blockquote_bar_color = link_color
	pass


# ---------------------------------------------------------------------------
# Light palette
# ---------------------------------------------------------------------------

## Same roles on a near-white surface: the fills drop to a whisper of gray (a saturated tint on
## white turns a code block into a color swatch) and the marks darken until they read against
## white — link 5.2:1, quote body 4.9:1.
static func apply_light_palette() -> void:
	code_block_bg = Color(0.45, 0.47, 0.52, 0.18)
	table_grid_color = Color(0.78, 0.79, 0.82)
	table_header_bg = Color(0.0, 0.0, 0.0, 0.05)
	inline_code_bg = Color(0.96, 0.965, 0.97)
	link_color = Color(0.15, 0.39, 0.92)
	blockquote_bar_color = link_color
	pass
