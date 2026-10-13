class_name DisplayScale
extends Object

## Display-layer scale helpers for native overlays and app-matched chrome.
##
## Two different ratios — do not mix them:
## - [method compute_ui_scale]: main-window pixels per viewport unit (match in-app UI under stretch).
## - [method compute_screen_scale]: usable screen width vs 2K design ([constant REF_SCREEN_WIDTH]).
##
## Embedded [Window] fonts (project stretch is [code]canvas_items[/code]):
## Every embedded subwindow — [Window], [AcceptDialog], [ConfirmationDialog], [FileDialog],
## [PopupMenu], [PopupPanel] — is its own Viewport. Auto oversampling stays at the Window's
## content scale (usually 1), while the parent stretches that Viewport as a texture, so glyphs
## look soft next to main-scene Labels. After [method Window.popup] / [method Window.popup_centered]
## (or inside shared stylers like [PopupMenuStyle]), set:
## [codeblock]
## window.oversampling_override = DisplayScale.compute_ui_scale()
## [/codeblock]
## Skip this for [member Window.force_native] windows ([DesktopToast], Sense overlays): they are
## real OS windows and already size fonts with [method compute_ui_scale] / [method compute_screen_scale].
##
## Typical use:
## [codeblock]
## var unit := DisplayScale.compute_ui_scale()
## var band := DisplayScale.compute_screen_scale(anchor)
## [/codeblock]

## Design reference width (2K) for [method compute_screen_scale].
const REF_SCREEN_WIDTH := 2560


## App UI scale: how many screen pixels one viewport unit takes on the main window.
static func compute_ui_scale() -> float:
	if gdf.gdf_node == null:
		return 1.0
	var viewport: Viewport = gdf.gdf_node.get_viewport()
	if viewport == null:
		return 1.0
	var unit: Vector2 = viewport.get_visible_rect().size
	if unit.x <= 0.0 or unit.y <= 0.0:
		return 1.0
	var pixels: Vector2 = Vector2(DisplayServer.window_get_size())
	return clampf(minf(pixels.x / unit.x, pixels.y / unit.y), 0.5, 4.0)


## Screen design scale under [param anchor]: usable width / [constant REF_SCREEN_WIDTH].
static func compute_screen_scale(anchor: Vector2i) -> float:
	var screen := DisplayServer.get_screen_from_rect(Rect2(Vector2(anchor), Vector2.ONE))
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0:
		return 1.0
	return float(usable.size.x) / float(REF_SCREEN_WIDTH)
