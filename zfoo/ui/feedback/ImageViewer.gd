## Image display control with fit-to-bounds, zoom, and drag-to-pan interactions.
class_name ImageViewer
extends ScrollContainer

const MIN_ZOOM: float = 0.1
const MAX_ZOOM: float = 8.0
const ZOOM_STEP: float = 1.15

var canvas: Control
var image_view: TextureRect
var zoom: float = 1.0
var fit_zoom: float = 1.0
var dragging: bool = false


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	gui_input.connect(on_viewer_input)
	resized.connect(refresh_fit)

	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)

	image_view = TextureRect.new()
	image_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(image_view)
	pass


func set_texture(texture: Texture2D) -> void:
	image_view.texture = texture
	refresh_fit()
	pass


func get_texture() -> Texture2D:
	return image_view.texture


## Recalculate fit whenever the control changes size; small images stay at 100%.
func refresh_fit() -> void:
	var texture := get_texture()
	if texture == null:
		return
	var image_size := texture.get_size()
	if image_size.x <= 0.0 or image_size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	fit_zoom = minf(1.0, minf(size.x / image_size.x, size.y / image_size.y))
	set_zoom(fit_zoom)
	pass


func set_zoom(value: float, focus_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if get_texture() == null:
		return
	var old_canvas_size := canvas.custom_minimum_size
	var focus := focus_position if focus_position.x >= 0.0 else size * 0.5
	var old_offset := Vector2(scroll_horizontal, scroll_vertical) + focus
	var relative := Vector2(0.5, 0.5)
	if old_canvas_size.x > 0.0 and old_canvas_size.y > 0.0:
		relative = old_offset / old_canvas_size
	zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	update_image_layout()
	var new_offset := relative * canvas.custom_minimum_size - focus
	scroll_horizontal = maxi(0, roundi(new_offset.x))
	scroll_vertical = maxi(0, roundi(new_offset.y))
	pass


func update_image_layout() -> void:
	var texture := get_texture()
	if texture == null:
		return
	var display_size := texture.get_size() * zoom
	var canvas_size := Vector2(maxf(display_size.x, size.x), maxf(display_size.y, size.y))
	canvas.custom_minimum_size = canvas_size
	image_view.position = (canvas_size - display_size) * 0.5
	image_view.size = display_size
	pass


func toggle_actual_size() -> void:
	set_zoom(fit_zoom if not is_equal_approx(zoom, fit_zoom) else 1.0)
	pass


func on_viewer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			set_zoom(zoom * ZOOM_STEP, mouse.position)
			accept_event()
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			set_zoom(zoom / ZOOM_STEP, mouse.position)
			accept_event()
		elif mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.double_click and mouse.pressed:
				toggle_actual_size()
				accept_event()
			else:
				dragging = mouse.pressed
	elif event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		scroll_horizontal -= roundi(motion.relative.x)
		scroll_vertical -= roundi(motion.relative.y)
		accept_event()
	pass
