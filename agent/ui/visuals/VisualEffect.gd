@abstract
class_name VisualEffect
extends Control

## Effect contract used by [VisualControl]. One shared effect represents all active agent
## runs: concurrent events may intentionally drive the same animation in arrival order.
## Hooks retain session_id for event provenance, runtime validation, and transcript lookup;
## effects do not create a separate visual instance or state machine per session.
##
## Effects paint on a [CanvasLayer] above the chat. Most effects stay sparse overlays: draw
## shapes, glyphs, and glows, but never an accidental full-surface translucent wash. Purpose-built
## post-processing effects may cover the rect when their shader preserves and transforms the screen.
## Neon/ink canvas colors live on [VisualColor], not [ThemeColor].

var fade_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	pass


func fade_in_seconds() -> float:
	return 0.3


func fade_out_seconds() -> float:
	return 0.4


func set_visual_visible(show: bool, animated: bool) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	if show:
		visible = true
		modulate.a = 0.0 if animated else 1.0
		if animated:
			fade_tween = create_tween()
			fade_tween.tween_property(self, "modulate:a", 1.0, fade_in_seconds())
		return
	if not animated:
		visible = false
		modulate.a = 1.0
		return
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_out_seconds())
	fade_tween.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
	)
	pass


func draw_centered_text(position: Vector2, text: String, font: Font, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, position - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	pass


## Regular polygon in local draw space. [param rotation] is the first vertex angle in radians.
static func polygon_points(center: Vector2, radius: float, sides: int, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(sides):
		points.append(center + Vector2.from_angle(rotation + float(index) * TAU / float(sides)) * radius)
	return points


func on_agent_start(_session_id: int) -> void:
	pass


## Runs the effect's optional completion animation before [VisualControl] fades it out.
func on_agent_end(_session_id: int, _error_message: String) -> void:
	pass


func on_turn_start(_session_id: int) -> void:
	pass


func on_turn_end(_session_id: int) -> void:
	pass


func on_message_update(_session_id: int, _chunk: String, _stream_kind: String) -> void:
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, _agent_tool_result: AgentToolResult) -> void:
	pass


func on_chat_entry_add(_session_id: int, _entry: ChatEntry) -> void:
	pass
