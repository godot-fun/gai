## Transient image preview with fit-to-window, zoom, and drag-to-pan interactions.
class_name ImagePreviewWindow
extends CommonWindow

const MIN_ZOOM: float = 0.1
const MAX_ZOOM: float = 8.0
const ZOOM_STEP: float = 1.15

var scroll: ScrollContainer
var canvas: Control
var image_view: TextureRect
var image_path: String
var zoom: float = 1.0
var fit_zoom: float = 1.0
var dragging: bool = false


func _init() -> void:
	super()
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


## Open a centered preview. The image loads asynchronously and the window remains usable while loading.
static func show_window(path: String, i18n_title: String = "Image Preview", width_percent: int = 80,
		height_percent: int = 85) -> ImagePreviewWindow:
	var window := ImagePreviewWindow.new()
	window.image_path = path
	var file_name := path.get_file()
	window.title = file_name if i18n_title.is_empty() else "%s - %s" % [file_name, I18n.t(i18n_title)]
	gdf.gdf_node.add_child(window)
	window.present_centered(width_percent, height_percent)
	window.load_image(path)
	return window


## Load project resources and ordinary OS files through the shared format-aware loader.
func load_image(path: String) -> void:
	image_path = path
	var texture := await ResourceHelper.async_load(path) as Texture2D
	if texture == null:
		Log.error("failed to preview image path:[{}]", path)
		Alert.alert(I18n.t("Unable to load image"), Colors.error)
		on_close_requested()
		return
	set_texture(texture)
	pass


func set_texture(texture: Texture2D) -> void:
	image_view.texture = texture
	image_view.tooltip_text = image_path
	refresh_fit()
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
