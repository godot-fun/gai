## Editable text-file view backed by [CommonEditor].
class_name EditorTextView
extends EditorView

var text_editor: CommonEditor
var assigning_text: bool = false


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_editor = CommonEditor.new()
	text_editor.text_changed.connect(on_text_changed)
	add_child(text_editor)
	text_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pass


func open_document(document: EditorDocument) -> void:
	assigning_text = true
	text_editor.set_document(document.text, document.path)
	assigning_text = false
	pass


func sync_document(document: EditorDocument) -> void:
	document.text = text_editor.text
	pass


func focus_view() -> void:
	text_editor.focus_editor()
	pass


func on_text_changed() -> void:
	if not assigning_text:
		content_changed.emit()
	pass
