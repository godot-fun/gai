class_name MiddleScrollController
extends ColorRect

## Reusable browser-style middle-button auto-scroll for a vertical [ScrollContainer].
## Owns input, motion, boundary feedback, and the shader-rendered control visualization.

## Movement inside this radius stays idle.
const DEAD_ZONE: float = 10.0
## The uncapped quadratic curve keeps accelerating with cursor distance.
const LINEAR_ACCELERATION: float = 2.0
const QUADRATIC_ACCELERATION: float = 0.06
## Exponential smoothing prevents abrupt speed changes near the dead zone.
const VELOCITY_SMOOTHING: float = 14.0
const POINTER_SHADER := preload("res://agent/ui/chat/MiddleScrollController.gdshader")

var scroll: ScrollContainer
var anchor: Vector2 = Vector2.ZERO
var velocity: float = 0.0
var target_velocity: float = 0.0
var scroll_position: float = 0.0
var scrolling: bool = false
var shader_material: ShaderMaterial


func _init() -> void:
	name = "MiddleScrollController"
	z_index = 20
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	visible = false
	set_process(false)
	shader_material = ShaderMaterial.new()
	shader_material.shader = POINTER_SHADER
	material = shader_material
	pass


func setup(p_scroll: ScrollContainer) -> void:
	scroll = p_scroll
	scroll.get_window().window_input.connect(on_window_input)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	apply_theme()
	pass


func apply_theme() -> void:
	shader_material.set_shader_parameter("accent_color", ThemeColor.accent_theme_color())
	pass


## Stops an active interaction, for example when the owning view switches content.
func cancel() -> void:
	end_scroll()
	pass


func on_window_input(event: InputEvent) -> void:
	if not is_instance_valid(scroll) or not scroll.is_inside_tree():
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_MIDDLE:
			return
		if mouse.pressed:
			try_begin_scroll()
		else:
			var was_scrolling := scrolling
			end_scroll()
			if was_scrolling:
				scroll.get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and scrolling:
		# Motion is sampled in _process; consume the event to suppress hover interactions.
		scroll.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if scrolling and key.pressed and key.keycode == KEY_ESCAPE:
			end_scroll()
			scroll.get_viewport().set_input_as_handled()
	pass


func try_begin_scroll() -> void:
	if has_visible_embedded_window() or not scroll.get_window().has_focus():
		return
	var local_mouse := scroll.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, scroll.size).has_point(local_mouse):
		return
	var vbar := scroll.get_v_scroll_bar()
	if vbar == null or vbar.max_value <= vbar.page:
		return
	anchor = scroll.get_global_mouse_position()
	velocity = 0.0
	target_velocity = 0.0
	scroll_position = vbar.value
	scrolling = true
	set_process(true)
	update_visual(anchor, false, 0.0, 0.0)
	AgentEvents.events.middle_scroll_started.emit()
	scroll.get_viewport().set_input_as_handled()
	pass


func _process(delta: float) -> void:
	if not scrolling:
		return
	if (not is_instance_valid(scroll)
		or not scroll.is_inside_tree()
		or not scroll.get_window().has_focus()
		or has_visible_embedded_window()
		or not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)):
		end_scroll()
		return
	var vbar := scroll.get_v_scroll_bar()
	if vbar == null:
		end_scroll()
		return
	update_state(scroll.get_global_mouse_position(), vbar)
	var blend := 1.0 - exp(-VELOCITY_SMOOTHING * delta)
	velocity = lerpf(velocity, target_velocity, blend)
	if absf(velocity) < 0.1 and is_zero_approx(target_velocity):
		velocity = 0.0
		return
	var max_scroll := maxf(vbar.min_value, vbar.max_value - vbar.page)
	scroll_position = clampf(scroll_position + velocity * delta, vbar.min_value, max_scroll)
	vbar.value = scroll_position
	pass


func update_state(mouse_position: Vector2, vbar: VScrollBar) -> void:
	var offset := mouse_position - anchor
	target_velocity = compute_velocity(offset.y)
	var outside_dead_zone := offset.length() > DEAD_ZONE
	var speed_factor := 1.0 - exp(-absf(target_velocity) / 1800.0)
	var max_scroll := maxf(vbar.min_value, vbar.max_value - vbar.page)
	var hits_top := target_velocity < -0.1 and vbar.value <= vbar.min_value + 0.5
	var hits_bottom := target_velocity > 0.1 and vbar.value >= max_scroll - 0.5
	var boundary_factor := 1.0 if hits_top or hits_bottom else 0.0
	update_visual(mouse_position, outside_dead_zone, speed_factor, boundary_factor)
	pass


## Fits the shader control around the effect instead of shading the entire scroll viewport.
func update_visual(mouse_position: Vector2, show_pointer: bool, speed_factor: float, boundary_factor: float) -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var inverse_parent_transform := parent_control.get_global_transform_with_canvas().affine_inverse()
	var anchor_parent := inverse_parent_transform * anchor
	var cursor_parent := inverse_parent_transform * mouse_position
	var bounds := Rect2(anchor_parent, cursor_parent - anchor_parent).abs().grow(Margin.ma_8)
	position = bounds.position
	size = bounds.size
	shader_material.set_shader_parameter("canvas_size", size)
	shader_material.set_shader_parameter("anchor_position", anchor_parent - bounds.position)
	shader_material.set_shader_parameter("cursor_position", cursor_parent - bounds.position)
	shader_material.set_shader_parameter("pointer_visible", 1.0 if show_pointer else 0.0)
	shader_material.set_shader_parameter("speed_factor", speed_factor)
	shader_material.set_shader_parameter("boundary_factor", boundary_factor)
	visible = true
	pass


## Uses an uncapped quadratic curve so farther cursor movement is always faster.
static func compute_velocity(offset: float) -> float:
	var effective_distance := maxf(absf(offset) - DEAD_ZONE, 0.0)
	var speed := effective_distance * LINEAR_ACCELERATION + effective_distance * effective_distance * QUADRATIC_ACCELERATION
	return signf(offset) * speed


func end_scroll() -> void:
	if not scrolling:
		return
	scrolling = false
	velocity = 0.0
	target_velocity = 0.0
	visible = false
	set_process(false)
	AgentEvents.events.middle_scroll_ended.emit(is_at_bottom())
	pass


func is_at_bottom() -> bool:
	if not is_instance_valid(scroll):
		return true
	var vbar := scroll.get_v_scroll_bar()
	if vbar == null:
		return true
	return vbar.value >= vbar.max_value - vbar.page - 1.0


func has_visible_embedded_window() -> bool:
	for window: Window in scroll.get_tree().root.get_embedded_subwindows():
		if window.visible:
			return true
	return false
