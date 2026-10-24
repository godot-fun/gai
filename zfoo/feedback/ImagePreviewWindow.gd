## Transient image preview with fit-to-window, zoom, and drag-to-pan interactions.
class_name ImagePreviewWindow
extends CommonWindow

const MIN_ZOOM: float = 0.1
const MAX_ZOOM: float = 8.0
const ZOOM_STEP: float = 1.15
const MAX_WIDTH_PERCENT: float = 80.0
const MAX_HEIGHT_PERCENT: float = 85.0
const MIN_WINDOW_SIZE: Vector2i = Vector2i(ControlSize.image_xl, ControlSize.image_lg)
const GROUP_NAME: StringName = &"image_preview_window"

var scroll: ScrollContainer
var canvas: Control
var image_view: TextureRect
var zoom: float = 1.0
var fit_zoom: float = 1.0
var dragging: bool = false


func _init() -> void:
	super()
	add_to_group(GROUP_NAME)
	min_size = MIN_WINDOW_SIZE
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.gui_input.connect(on_preview_input)
	scroll.resized.connect(refresh_fit)
	container.add_child(scroll)

	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(canvas)

	image_view = TextureRect.new()
	image_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(image_view)
	apply_theme()
	pass


func set_texture(texture: Texture2D) -> void:
	image_view.texture = texture
	refresh_fit()
	pass


## Size the window to the image aspect ratio within the configured maximum screen bounds.
func present_image() -> void:
	if image_view.texture == null:
		return
	var viewport_size := gdf.gdf_node.get_tree().root.get_visible_rect().size
	var max_window_size := Vector2(
		viewport_size.x * MAX_WIDTH_PERCENT / 100.0,
		viewport_size.y * MAX_HEIGHT_PERCENT / 100.0,
	)
	var image_size := image_view.texture.get_size()
	var image_scale := minf(1.0, minf(max_window_size.x / image_size.x, max_window_size.y / image_size.y))
	var content_size := image_size * image_scale
	var window_size := Vector2(maxf(content_size.x, MIN_WINDOW_SIZE.x), maxf(content_size.y, MIN_WINDOW_SIZE.y))
	size = Vector2i(roundi(window_size.x), roundi(window_size.y))
	popup_centered()
	oversampling_override = DisplayScale.compute_ui_scale()
	pass


## Recalculate fit whenever the window changes size; images smaller than the viewport stay at 100%.
func refresh_fit() -> void:
	if image_view == null or image_view.texture == null:
		return
	var image_size := image_view.texture.get_size()
	if image_size.x <= 0.0 or image_size.y <= 0.0 or scroll.size.x <= 0.0 or scroll.size.y <= 0.0:
		return
	fit_zoom = minf(1.0, minf(scroll.size.x / image_size.x, scroll.size.y / image_size.y))
	set_zoom(fit_zoom)
	pass


func set_zoom(value: float, focus_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if image_view.texture == null:
		return
	var old_canvas_size := canvas.custom_minimum_size
	var focus := focus_position if focus_position.x >= 0.0 else scroll.size * 0.5
	var old_offset := Vector2(scroll.scroll_horizontal, scroll.scroll_vertical) + focus
	var relative := Vector2(0.5, 0.5)
	if old_canvas_size.x > 0.0 and old_canvas_size.y > 0.0:
		relative = old_offset / old_canvas_size
	zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	update_image_layout()
	var new_offset := relative * canvas.custom_minimum_size - focus
	scroll.scroll_horizontal = maxi(0, roundi(new_offset.x))
	scroll.scroll_vertical = maxi(0, roundi(new_offset.y))
	pass


func update_image_layout() -> void:
	if image_view.texture == null:
		return
	var display_size := image_view.texture.get_size() * zoom
	var canvas_size := Vector2(maxf(display_size.x, scroll.size.x), maxf(display_size.y, scroll.size.y))
	canvas.custom_minimum_size = canvas_size
	image_view.position = (canvas_size - display_size) * 0.5
	image_view.size = display_size
	pass


func toggle_actual_size() -> void:
	set_zoom(fit_zoom if not is_equal_approx(zoom, fit_zoom) else 1.0)
	pass


func on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			set_zoom(zoom * ZOOM_STEP, mouse.position)
			scroll.accept_event()
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			set_zoom(zoom / ZOOM_STEP, mouse.position)
			scroll.accept_event()
		elif mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.double_click and mouse.pressed:
				toggle_actual_size()
				scroll.accept_event()
			else:
				dragging = mouse.pressed
	elif event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		scroll.scroll_horizontal -= roundi(motion.relative.x)
		scroll.scroll_vertical -= roundi(motion.relative.y)
		scroll.accept_event()
	pass


func apply_theme() -> void:
	super()
	if container != null:
		var background := StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, 0)
		container.add_theme_stylebox_override("panel", background)
	pass


####################################################################################################
# Static methods

## Whether an image preview window is currently open.
static func is_open() -> bool:
	return gdf.gdf_node != null and gdf.gdf_node.is_inside_tree() and not gdf.gdf_node.get_tree().get_nodes_in_group(GROUP_NAME).is_empty()


## Load an image from a path, then open it through [method show_image].
static func show_window(path: String, i18n_title: String = "Image Preview") -> ImagePreviewWindow:
	var texture := await ResourceHelper.async_load(path) as Texture2D
	if texture == null:
		Log.error("failed to preview image path:[{}]", path)
		Alert.alert(I18n.t("Unable to load image"), Colors.error)
		return null
	var title := StringUtils.format("{} - {}", path.get_file(), I18n.t(i18n_title))
	return show_image(texture, title)


## Open a centered preview using an image resource that is already loaded.
static func show_image(texture: Texture2D, i18n_title: String = "Image Preview") -> ImagePreviewWindow:
	var window := create_window(i18n_title)
	window.set_texture(texture)
	window.present_image()
	return window


static func create_window(i18n_title: String) -> ImagePreviewWindow:
	var window := ImagePreviewWindow.new()
	window.title = I18n.t(i18n_title)
	gdf.gdf_node.add_child(window)
	return window
