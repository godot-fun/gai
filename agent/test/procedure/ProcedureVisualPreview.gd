extends Control

## Standalone PROCEDURE animation preview. Space / Enter replays the fixed token sample.

const PROCEDURE_SCRIPT := preload("res://agent/ui/visuals/procedure/ProcedureController.gd")
const SAMPLE_PIECES: Array[String] = ["每次", "我", "向你", "提问", "，", "你的", "脑子", "里", "发生", "了", "什么", "？"]
const SAMPLE_IDS: Array[int] = [97571, 14594, 84209, 93355, 10867, 62431, 73642, 31876, 55729, 91004, 48113, 20497]

var procedure: ProcedureController
var replaying: bool = false


func _ready() -> void:
	build_preview_ui()
	replay.call_deferred()
	pass


func build_preview_ui() -> void:
	var background := ColorRect.new()
	background.color = ColorBase.deep_surface
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	procedure = PROCEDURE_SCRIPT.new()
	procedure.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(procedure)

	var hint := Label.new()
	hint.text = "PROCEDURE · Space / Enter 重播"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", Fonts.regular())
	hint.add_theme_font_size_override("font_size", Typography.label_medium_size)
	hint.add_theme_color_override("font_color", ColorBase.secondary_text)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -48.0
	hint.offset_bottom = -20.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	pass


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		replay()
		get_viewport().set_input_as_handled()
	pass


func replay() -> void:
	if replaying:
		return
	replaying = true
	var tokens: Array[LlamaHelper.Token] = []
	for index in SAMPLE_PIECES.size():
		tokens.append(LlamaHelper.Token.new(SAMPLE_IDS[index], SAMPLE_PIECES[index]))
	await procedure.play_preview(tokens)
	replaying = false
	pass
