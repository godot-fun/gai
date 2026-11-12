extends RefCounted

## Regression guard for the sidebar row highlight.
##
## The row used to ignore an exit signal that landed inside its own rect, assuming that meant the
## cursor was only moving between the row's own controls. The engine never sends that for those
## moves — the row stays in the mouse-over chain — so the check only fired when the engine dropped
## the whole chain because a hovered control went hidden (the title while a rename opens, the close
## button when a run starts). No second exit follows such a drop, so the row kept its hover
## background while the cursor already sat on another row: one stale highlight per click.


## The row covers the whole window, so the cursor is inside its rect whatever the platform reports.
func exit_inside_the_row_still_drops_the_hover_test() -> void:
	var row := await build_row()
	assert(row.get_global_rect().has_point(row.get_global_mouse_position()))

	row.on_mouse_entered()
	assert(row.hovered)
	# The drop described above: the exit arrives while the cursor is still on the row.
	row.on_mouse_exited()
	assert(not row.hovered)
	row.get_parent().queue_free()
	pass


func build_row() -> SessionRow:
	var tree := Engine.get_main_loop() as SceneTree
	var host := Control.new()
	host.size = tree.root.size
	tree.root.add_child.call_deferred(host)
	var row := SessionRow.new()
	row.build(1, "chat")
	host.add_child(row)
	row.size = host.size
	await settled()
	return row


static func settled() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	await tree.process_frame
	pass
