class_name DisplayScale
extends Object

## Display-layer scale helpers: user interface presets plus layout ratios for overlays.

# ----------------------------------------------------------------------------------------------------------------------
# User interface scale
# ----------------------------------------------------------------------------------------------------------------------

## Whole-app zoom stored in [Setting] and applied to [member Window.content_scale_factor].
## Distinct from [method compute_ui_scale] (automatic stretch) — do not mix the two when sizing UI.
##
## Presets match the agent appearance setting and Ctrl / ⌘ + mouse wheel shortcuts.

const UI_SCALE_SETTING_KEY := "ui_scale"
const LEGACY_UI_SCALE_SETTING_KEY := "agent_ui_scale"
const DEFAULT_UI_SCALE := 1.0
const UI_SCALE_PRESETS: Array[float] = [
	0.75, 0.90, 1.0, 1.05, 1.10, 1.15, 1.20, 1.25, 1.30, 1.35, 1.40, 1.45, 1.50, 1.65, 1.80, 2.0,
]


## Current preset multiplier (snapped to [constant UI_SCALE_PRESETS]).
static func get_ui_scale() -> float:
	var raw := clampf(read_stored_ui_scale(), UI_SCALE_PRESETS[0], UI_SCALE_PRESETS[-1])
	return UI_SCALE_PRESETS[find_ui_scale_index(raw)]


static func read_stored_ui_scale() -> float:
	if StringUtils.is_not_blank(Setting.get_string(UI_SCALE_SETTING_KEY, "")):
		return Setting.get_float(UI_SCALE_SETTING_KEY, DEFAULT_UI_SCALE)
	if StringUtils.is_not_blank(Setting.get_string(LEGACY_UI_SCALE_SETTING_KEY, "")):
		return Setting.get_float(LEGACY_UI_SCALE_SETTING_KEY, DEFAULT_UI_SCALE)
	return DEFAULT_UI_SCALE


## Applies [method get_ui_scale] to the root window (call once at startup and after each [method set_ui_scale]).
static func apply_ui_scale() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.root.content_scale_factor = get_ui_scale()
	pass


## Persists a preset, updates the root factor, and emits [signal GodotFramework.Events.ui_scale_changed].
static func set_ui_scale(scale: float) -> void:
	var clamped := clampf(scale, UI_SCALE_PRESETS[0], UI_SCALE_PRESETS[-1])
	var snapped := UI_SCALE_PRESETS[find_ui_scale_index(clamped)]
	var current := get_ui_scale()
	if is_equal_approx(current, snapped):
		return
	Setting.set_float(UI_SCALE_SETTING_KEY, snapped)
	if StringUtils.is_not_blank(Setting.get_string(LEGACY_UI_SCALE_SETTING_KEY, "")):
		Setting.set_string(LEGACY_UI_SCALE_SETTING_KEY, "")
	Setting.save()
	apply_ui_scale()
	gdf.events.ui_scale_changed.emit(snapped)
	pass


## Steps one entry in [constant UI_SCALE_PRESETS] (positive = larger UI).
static func step_ui_scale(direction: int) -> void:
	if direction == 0:
		return
	var index := find_ui_scale_index(get_ui_scale())
	index = clampi(index + direction, 0, UI_SCALE_PRESETS.size() - 1)
	set_ui_scale(UI_SCALE_PRESETS[index])
	pass


static func find_ui_scale_index(scale: float) -> int:
	for index in range(UI_SCALE_PRESETS.size()):
		if is_equal_approx(scale, UI_SCALE_PRESETS[index]):
			return index
	var nearest := 0
	var nearest_delta := absf(scale - UI_SCALE_PRESETS[0])
	for index in range(1, UI_SCALE_PRESETS.size()):
		var delta := absf(scale - UI_SCALE_PRESETS[index])
		if delta < nearest_delta:
			nearest_delta = delta
			nearest = index
	return nearest


# ----------------------------------------------------------------------------------------------------------------------
# Layout scale (stretch & screen band)
# ----------------------------------------------------------------------------------------------------------------------

## Ratios derived from the live window or monitor — not user presets.
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

## Design reference width (2K) for [method compute_screen_scale].
const REF_SCREEN_WIDTH := 2560


## Main-window pixels per viewport unit under project stretch (clamped 0.5–4.0).
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


## Usable screen width under [param anchor] vs [constant REF_SCREEN_WIDTH] (2K layout band).
static func compute_screen_scale(anchor: Vector2i) -> float:
	var screen := DisplayServer.get_screen_from_rect(Rect2(Vector2(anchor), Vector2.ONE))
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0:
		return 1.0
	return float(usable.size.x) / float(REF_SCREEN_WIDTH)
