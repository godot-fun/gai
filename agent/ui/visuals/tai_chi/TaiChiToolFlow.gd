class_name TaiChiToolFlow
extends RefCounted

## Represents tools as small seals travelling out from the center along the horizon.

var tools: Dictionary[String, Dictionary] = {}


func reset() -> void:
	tools.clear()
	pass


func begin(tool_call_id: String) -> void:
	tools[tool_call_id] = {"progress": 0.0, "done": false, "failed": false, "slot": tools.size()}
	pass


func finish(tool_call_id: String, failed: bool) -> void:
	if not tools.has(tool_call_id):
		return
	var item: Dictionary = tools[tool_call_id]
	item["done"] = true
	item["failed"] = failed
	pass


func advance(delta: float) -> bool:
	var changed := false
	for item: Dictionary in tools.values():
		var previous: float = item["progress"]
		item["progress"] = move_toward(previous, 1.0, delta * (1.4 if bool(item["done"]) else 0.65))
		changed = changed or previous != float(item["progress"])
	return changed


func draw(canvas: Control, center: Vector2, line_y: float, line_half_width: float) -> void:
	for item: Dictionary in tools.values():
		var slot: int = item["slot"]
		var direction := -1.0 if slot % 2 == 0 else 1.0
		var lane := float(slot / 2 + 1) / float(maxi(4, tools.size() / 2 + 2))
		var position := Vector2(center.x + direction * line_half_width * lane * float(item["progress"]), line_y)
		var color := Color(0.93, 0.42, 0.3) if bool(item["failed"]) else Color(1.0, 0.88, 0.52)
		canvas.draw_circle(position, 3.5 + 2.0 * (1.0 - float(item["progress"])), Color(color, 0.86))
		canvas.draw_arc(position, 8.0, 0.0, TAU * float(item["progress"]), 18, Color(color, 0.42), 1.2, true)
	pass
