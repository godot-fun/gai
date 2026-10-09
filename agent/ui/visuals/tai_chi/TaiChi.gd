class_name TaiChi
extends VisualEffect

## A quiet, center-out visual inspired by the opening gesture of a Chinese ink scroll.
## Each lifecycle concern lives in its own flow so later sequences stay isolated.

const OPENING_FLOW_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChiOpeningFlow.gd")
const DUALITY_FLOW_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChiDualityFlow.gd")
const THINKING_FLOW_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChiThinkingFlow.gd")
const TOOL_FLOW_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChiToolFlow.gd")
const COMPLETION_FLOW_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChiCompletionFlow.gd")
const COMPLETION_SECONDS := 1.25

var opening := OPENING_FLOW_SCRIPT.new()
var duality := DUALITY_FLOW_SCRIPT.new()
var thinking := THINKING_FLOW_SCRIPT.new()
var tool_flow := TOOL_FLOW_SCRIPT.new()
var completion := COMPLETION_FLOW_SCRIPT.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.TAI_CHI


func fade_in_seconds() -> float:
	return 0.18


func fade_out_seconds() -> float:
	return 0.55


func reset_visual() -> void:
	opening.reset()
	duality.reset()
	thinking.reset()
	tool_flow.reset()
	completion.reset()
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	queue_redraw()
	pass


func on_agent_end(error_message: String) -> void:
	completion.begin(StringUtils.is_not_blank(error_message))
	if is_inside_tree():
		await get_tree().create_timer(COMPLETION_SECONDS).timeout
	pass


func on_turn_start() -> void:
	thinking.awaken(0.42)
	pass


func on_message_update(chunk: String, _stream_kind: String) -> void:
	if not chunk.is_empty():
		thinking.awaken(minf(0.22, float(chunk.length()) / 180.0))
	pass


func on_tool_execution_start(tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	tool_flow.begin(tool_call_id)
	thinking.awaken(0.3)
	pass


func on_tool_execution_end(tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	tool_flow.finish(tool_call_id, result.is_error)
	pass


func on_theme_changed() -> void:
	queue_redraw()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	var changed := opening.advance(delta)
	if opening.line_progress() >= 1.0 and not duality.active:
		duality.begin()
		changed = true
	changed = duality.advance(delta) or changed
	changed = thinking.advance(delta) or changed
	changed = tool_flow.advance(delta) or changed
	changed = completion.advance(delta) or changed
	if changed:
		queue_redraw()
	pass


func _draw() -> void:
	if size.x < 180.0 or size.y < 180.0:
		return
	var center := size * 0.5
	if not duality.active:
		opening.draw(self, center, size.x)
	else:
		var opening_line_y := center.y + minf(132.0, size.y * 0.17)
		opening.draw_title(self, Vector2(center.x, opening_line_y - minf(170.0, size.y * 0.22)), duality.title_opacity())
		duality.draw(self, center, size.x)
	pass
