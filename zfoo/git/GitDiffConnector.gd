class_name GitDiffConnector
extends Control

## Narrow center lane that visually connects corresponding old/new diff blocks.

signal revert_requested(hunk_index: int)

const BLOCK_ALPHA := 0.18
const ACTIVE_ALPHA := 0.34
const MAX_FILLED_OFFSET_LINES := 3.0
const CURVE_SEGMENTS := 12

var left_edit: CodeEdit
var right_edit: CodeEdit
class RevertButton:
	var hunk_index: int
	var rect: Rect2

	func _init(p_hunk_index: int, p_rect: Rect2) -> void:
		hunk_index = p_hunk_index
		rect = p_rect
		pass


var hunks: Array[GitDiffParser.DiffHunk] = []
var active_hunk := -1
var revert_enabled := false
var revert_buttons: Array[RevertButton] = []
var hovered_button := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	tooltip_text = "Revert this change"
	clip_contents = true
	custom_minimum_size.x = ControlSize.lg
	resized.connect(queue_redraw)
	pass


func set_editors(left: CodeEdit, right: CodeEdit) -> void:
	left_edit = left
	right_edit = right
	pass


func set_hunks(value: Array[GitDiffParser.DiffHunk], active: int) -> void:
	hunks = value
	active_hunk = active
	queue_redraw()
	pass


func set_revert_enabled(value: bool) -> void:
	revert_enabled = value
	queue_redraw()
	pass


func _draw() -> void:
	revert_buttons.clear()
	if left_edit == null or right_edit == null:
		return
	for index in hunks.size():
		var hunk := hunks[index]
		var old_rect := block_rect(left_edit, hunk.old_start, hunk.old_count)
		var new_rect := block_rect(right_edit, hunk.new_start, hunk.new_count)
		if old_rect.end < 0.0 and new_rect.end < 0.0 or old_rect.start > size.y and new_rect.start > size.y:
			continue
		var alpha := ACTIVE_ALPHA if index == active_hunk else BLOCK_ALPHA
		var color := Color(ThemeColor.accent_theme_color(), alpha)
		var old_center: float = (old_rect.start + old_rect.end) * 0.5
		var new_center: float = (new_rect.start + new_rect.end) * 0.5
		var line_height := float(left_edit.get_line_height())
		if absf(old_center - new_center) <= line_height * MAX_FILLED_OFFSET_LINES:
			draw_filled_connector(old_rect, new_rect, color)
		else:
			draw_compact_connector(old_rect, new_rect, color, index == active_hunk)
		if revert_enabled:
			draw_revert_button(index, old_rect, new_rect)
	pass


func draw_revert_button(index: int, old_rect: Dictionary, _new_rect: Dictionary) -> void:
	var button_size := float(ControlSize.xs)
	var line_height := float(left_edit.get_line_height())
	# Revert acts from left to right, so its stable anchor is the first row of the old block. Do not
	# move it to an unrelated right-side row when that anchor has scrolled outside the viewport.
	var center_y: float = old_rect.start + minf((old_rect.end - old_rect.start) * 0.5, line_height * 0.5)
	if center_y - button_size * 0.5 < 0.0 or center_y + button_size * 0.5 > size.y:
		return
	var rect := Rect2(Vector2(ControlSize.border_xs, center_y - button_size * 0.5), Vector2(button_size, button_size))
	revert_buttons.append(RevertButton.new(index, rect))
	var hovered := hovered_button == index
	var center := rect.get_center()
	var radius := button_size * 0.5 - float(ControlSize.border_xs)
	var background := ThemeColor.selected_surface if hovered else ThemeColor.card_surface
	var border := ThemeColor.accent_theme_color() if hovered else Color(ThemeColor.title_color, 0.32)
	draw_circle(center + Vector2(0.0, ControlSize.border_xs), radius, Color(Colors.deep_surface, 0.22), true, -1.0, true)
	draw_circle(center, radius, background, true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, 24, border, ControlSize.border_xs, true)
	var half_arrow := float(Margin.ma_1) * 0.75
	var arrow := PackedVector2Array([
		center + Vector2(-half_arrow * 0.65, -half_arrow), center + Vector2(half_arrow * 0.65, 0.0),
		center + Vector2(-half_arrow * 0.65, half_arrow),
	])
	draw_polyline(arrow, ThemeColor.title_color, 1.5, true)
	pass


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next_hover := button_at(event.position)
		if next_hover != hovered_button:
			hovered_button = next_hover
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_button >= 0 else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index := button_at(event.position)
		if index >= 0:
			revert_requested.emit(index)
			accept_event()
	pass


func button_at(position: Vector2) -> int:
	for button: RevertButton in revert_buttons:
		if button.rect.has_point(position):
			return button.hunk_index
	return -1


func draw_filled_connector(old_rect: Dictionary, new_rect: Dictionary, color: Color) -> void:
	var right := maxf(size.x - float(ControlSize.border_xs), 0.0)
	var points := PackedVector2Array([
		Vector2(0.0, old_rect.start), Vector2(right, new_rect.start),
		Vector2(right, new_rect.end), Vector2(0.0, old_rect.end),
	])
	draw_colored_polygon(points, color)
	var edge_color := Color(color, minf(color.a + 0.18, 1.0))
	draw_polyline(PackedVector2Array([points[0], points[1]]), edge_color, ControlSize.border_xs)
	draw_polyline(PackedVector2Array([points[3], points[2]]), edge_color, ControlSize.border_xs)
	pass


## Distant blocks use a thin S-curve instead of a giant filled triangle that dominates the editor.
func draw_compact_connector(old_rect: Dictionary, new_rect: Dictionary, color: Color, active: bool) -> void:
	var old_center: float = (old_rect.start + old_rect.end) * 0.5
	var new_center: float = (new_rect.start + new_rect.end) * 0.5
	var points := PackedVector2Array()
	var right := maxf(size.x - float(ControlSize.border_xs), 0.0)
	for segment in CURVE_SEGMENTS + 1:
		var progress := float(segment) / float(CURVE_SEGMENTS)
		var eased := progress * progress * (3.0 - 2.0 * progress)
		points.append(Vector2(right * progress, lerpf(old_center, new_center, eased)))
	var stroke := Color(color, minf(color.a + 0.28, 0.72))
	draw_polyline(points, stroke, ControlSize.border_sm if active else ControlSize.border_xs, true)
	draw_line(Vector2(0.0, old_rect.start), Vector2(0.0, old_rect.end), stroke, ControlSize.border_sm)
	draw_line(Vector2(right, new_rect.start), Vector2(right, new_rect.end), stroke, ControlSize.border_sm)
	pass


func block_rect(edit: CodeEdit, one_based_start: int, line_count: int) -> Dictionary:
	var line_height := float(edit.get_line_height())
	var top := (float(one_based_start - 1) - edit.scroll_vertical) * line_height
	var height := maxf(float(line_count) * line_height, line_height * 0.32)
	return {"start": top, "end": top + height}
