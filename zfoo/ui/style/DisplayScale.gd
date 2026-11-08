class_name DisplayScale
extends Object

## Display-layer scale helpers: user interface presets plus layout ratios for overlays.
##
## Do not implement user UI scaling by changing the root [member Window.content_scale_factor] or by
## scaling the root canvas. That can rasterize text at the original size and then stretch the result,
## making glyphs look blurry. Keep the root canvas at 1:1 and use [method apply_ui_scale] to rebuild
## typography, spacing, and control tokens so fonts are rasterized directly at their final pixel size.

# ----------------------------------------------------------------------------------------------------------------------
# User interface scale
# ----------------------------------------------------------------------------------------------------------------------

## Whole-app design scale stored in [Setting]. The root canvas stays at 1:1; this class recalculates
## typography, spacing, and control tokens so fonts are rasterized directly at their final size.
##
## Presets match the agent appearance setting and Ctrl / ⌘ + mouse wheel shortcuts.

const UI_SCALE_SETTING_KEY := "ui_scale"
const DEFAULT_UI_SCALE := 1.0
const UI_SCALE_PRESETS: Array[float] = [
	0.75, 0.90, 1.0, 1.05, 1.10, 1.15, 1.20, 1.25, 1.30, 1.35, 1.40, 1.45, 1.50, 1.65, 1.80, 2.0,
]


## Scales an integer and rounds it to the nearest whole pixel.
static func scale_int(base_value: int, scale: float) -> int:
	return roundi(float(base_value) * scale)


## Scales a floating-point value without rounding.
static func scale_float(base_value: float, scale: float) -> float:
	return base_value * scale


## Scales an integer and keeps the result at or above [param minimum].
static func scale_int_min(base_value: int, scale: float, minimum: int = 1) -> int:
	return maxi(minimum, scale_int(base_value, scale))


## Scales a floating-point value and keeps the result at or above [param minimum].
static func scale_float_min(base_value: float, scale: float, minimum: float = 0.0) -> float:
	return maxf(minimum, scale_float(base_value, scale))


## Current preset multiplier (snapped to [constant UI_SCALE_PRESETS]).
static func get_ui_scale() -> float:
	var raw := clampf(Setting.get_float(UI_SCALE_SETTING_KEY, DEFAULT_UI_SCALE), UI_SCALE_PRESETS[0], UI_SCALE_PRESETS[-1])
	return UI_SCALE_PRESETS[find_ui_scale_index(raw)]


## Recalculates every shared UI token (call once before building UI and after each scale change).
static func apply_ui_scale() -> void:
	var scale := get_ui_scale()
	Typography.apply_scale(scale)
	Margin.apply_scale(scale)
	ControlSize.apply_scale(scale)
	pass


## Persists a preset, updates the root factor, and emits [signal GodotFramework.Events.ui_scale_changed].
static func set_ui_scale(scale: float) -> void:
	var clamped := clampf(scale, UI_SCALE_PRESETS[0], UI_SCALE_PRESETS[-1])
	var preset_scale := UI_SCALE_PRESETS[find_ui_scale_index(clamped)]
	var current := get_ui_scale()
	if is_equal_approx(current, preset_scale):
		return
	Setting.set_float(UI_SCALE_SETTING_KEY, preset_scale)
	Setting.save()
	apply_ui_scale()
	gdf.events.ui_scale_changed.emit(preset_scale)
	# Existing controls have copied token values into theme overrides and StyleBoxes. Reapply those
	# after the live tokens change; newly constructed controls read the scaled values directly.
	gdf.events.theme_changed.emit()
	pass


## Moves one entry in [constant UI_SCALE_PRESETS] (positive = larger UI).
static func adjust_ui_scale(direction: int) -> void:
	if direction == 0:
		return
	var index := find_ui_scale_index(get_ui_scale())
	index = clampi(index + direction, 0, UI_SCALE_PRESETS.size() - 1)
	set_ui_scale(UI_SCALE_PRESETS[index])
	pass


## Applies Ctrl/Cmd + mouse-wheel UI zoom for a focused window. Ctrl/Cmd + Shift + wheel is
## intentionally left available to feature-specific navigation such as chat reply history.
static func handle_window_input(window: Window, event: InputEvent) -> void:
	if window == null or not window.is_inside_tree() or not window.has_focus():
		return
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.shift_pressed or (not mouse.ctrl_pressed and not mouse.meta_pressed):
		return
	if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
		adjust_ui_scale(1)
	elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		adjust_ui_scale(-1)
	else:
		return
	window.set_input_as_handled()
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
