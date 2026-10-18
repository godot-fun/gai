class_name SessionRowDrag
extends RefCounted

## Row drag & drop — reorder inside a list, move between the pinned and normal sections.
##
## The host hands in its row map and the two lists. Rows are added to / erased from that same
## dictionary (never reassigned), so this controller always sees the live set.

var session_rows: Dictionary[int, SessionRow] = {}
var pinned_list: VBoxContainer
var unpinned_list: VBoxContainer


func setup(
	p_session_rows: Dictionary[int, SessionRow],
	p_pinned_list: VBoxContainer,
	p_unpinned_list: VBoxContainer
) -> void:
	session_rows = p_session_rows
	pinned_list = p_pinned_list
	unpinned_list = p_unpinned_list
	pass


func list_for_pinned(pinned: bool) -> VBoxContainer:
	return pinned_list if pinned else unpinned_list


## The drag payload is the session id of the dragged row; anything else is not ours.
func row_of_drag_data(data: Variant) -> SessionRow:
	if typeof(data) != TYPE_INT:
		return null
	return session_rows.get(data)


## Whole row (padding, title, close button) is a drag handle and a drop target.
## Bound arguments come last, so these three keep the engine's callback shape.
func bind_row(row: SessionRow) -> void:
	row.bind_drag_forwarding(get_row_drag_data.bind(row), can_drop_on_row.bind(row), drop_on_row.bind(row))
	pass


## A list and its header accept drops too — dropping on the background appends to that list.
func bind_list(host: Control, pinned: bool) -> void:
	host.set_drag_forwarding(
		func(_at_position: Vector2) -> Variant: return null,
		can_drop_on_list.bind(pinned),
		drop_on_list.bind(pinned)
	)
	pass


func get_row_drag_data(_at_position: Vector2, row: SessionRow) -> Variant:
	# While the row is being renamed the drag must not steal the click and move it away.
	if row == null or row.is_renaming():
		return null
	row.set_drag_preview(row.build_drag_preview())
	return row.session_id


## Query only — the reorder is applied in [method drop_on_row] when the mouse is released.
func can_drop_on_row(_at_position: Vector2, data: Variant, target: SessionRow) -> bool:
	return row_of_drag_data(data) != null and target != null


func drop_on_row(_at_position: Vector2, data: Variant, target: SessionRow) -> bool:
	var from_row := row_of_drag_data(data)
	if from_row == null or target == null:
		return false
	# The section is read from the list a row sits in, never from a copy of that state.
	var to_pinned := target.get_parent() == pinned_list
	apply_row_move(from_row, list_for_pinned(to_pinned), target.get_index(), to_pinned)
	return true


## Query only — the reorder is applied in [method drop_on_list] when the mouse is released.
func can_drop_on_list(_at_position: Vector2, data: Variant, _pinned: bool) -> bool:
	return row_of_drag_data(data) != null


## Dropping on the list background appends the row to the end of that list.
func drop_on_list(_at_position: Vector2, data: Variant, pinned: bool) -> bool:
	var from_row := row_of_drag_data(data)
	if from_row == null:
		return false
	var target_list := list_for_pinned(pinned)
	var to_index := target_list.get_child_count()
	if from_row.get_parent() == target_list and to_index > 0:
		to_index -= 1
	apply_row_move(from_row, target_list, to_index, pinned)
	return true


## Moves the node and mirrors the move into the session index (order and pinned section).
func apply_row_move(from_row: SessionRow, target_list: VBoxContainer, to_index: int, to_pinned: bool) -> void:
	var session_id := from_row.session_id
	var need_section_change := AgentSessionManager.is_pinned(session_id) != to_pinned
	if from_row.get_parent() != target_list:
		from_row.reparent(target_list)

	to_index = clampi(to_index, 0, maxi(0, target_list.get_child_count() - 1))
	var from_index := from_row.get_index()
	if not need_section_change and from_index == to_index:
		return

	if from_index != to_index:
		target_list.move_child(from_row, to_index)

	if need_section_change:
		AgentSessionManager.transfer_session_index(session_id, to_pinned, from_row.get_index())
	elif from_index != to_index:
		AgentSessionManager.move_index_in_list(session_id, from_row.get_index(), to_pinned)
	pass
