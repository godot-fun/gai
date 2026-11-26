## Tails `{user_data}/logs/godot.log` via PopupWindow.
class_name LogWindow
extends Object


## Show the last `line_count` lines, opened at the last line — the newest entry — since a log is read
## from the bottom. Width/height are percent of the screen (1–100).
## Example: `LogWindow.show_log_window()`
static func show_log_window(line_count: int = 128, width_percent: int = 70, height_percent: int = 80) -> void:
	var window := PopupWindow.show_window("System Log", LoggerHelper.tail_log(maxi(line_count, 1)), width_percent, height_percent)
	# The popup keeps laying out over the next frames, and those layout passes clamp an earlier scroll
	# back to the top: scroll to the newest line again after each of them. A closed popup drops it.
	var tree := window.get_tree()
	for frame: int in 3:
		await tree.process_frame
		if !is_instance_valid(window):
			return
		window.text_edit.scroll_vertical = window.text_edit.get_line_count()
	pass
